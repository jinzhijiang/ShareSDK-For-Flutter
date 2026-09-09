import {
  Any,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { HashMap } from '@kit.ArkTS';
import { common, Want } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import bundleManager from '@ohos.bundle.bundleManager';
import http from '@ohos.net.http';
import { image } from '@kit.ImageKit';
import { ZztSDK } from '@zztsdk/zztcore';
import mobShare from '@zztsdk/sharesdk';
import {
  BaseReq,
  BaseResp,
  ErrCode,
  SendAuthReq,
  SendAuthResp,
  WXAPIFactory,
  WXApi,
  WXApiEventHandler,
} from '@tencent/wechat_open_sdk';

const METHOD_CHANNEL_NAME = 'com.mob.sharesdk.methodchannel';

interface PluginError {
  message: string;
}

interface UserInfoResult {
  state: number;
  user?: Map<string, Object>;
  error?: PluginError;
}

interface ActionResult {
  state: number;
  error?: PluginError;
}

interface PrivacyResult {
  success: boolean;
}

interface PrivacyPolicyResult {
  data?: string;
  error?: PluginError;
}

interface TargetFilePathResult {
  path: string;
}

interface BundleSignatureResult {
  fingerprint: string;
  fingerprintMd5: string;
  bundleName: string;
}

class SharedUserMarker {
  ok: boolean = true;
}

function platformNameFromId(platformId: number): string | null {
  switch (platformId) {
    case 22:
    case 23:
    case 37:
    case 997:
      return mobShare.Platform.Wechat;
    case 24:
    case 6:
    case 998:
      return mobShare.Platform.QQ;
    case 63:
      return mobShare.Platform.HUAWEI;
    default:
      return null;
  }
}

function sceneFromPlatformId(platformId: number): number {
  switch (platformId) {
    case 23:
      return 1;
    case 37:
      return 2;
    case 6:
      return 3009;
    default:
      return 0;
  }
}

function shareTypeFromContentType(typeNum: number): string {
  switch (typeNum) {
    case 1:
      return mobShare.ShareType.TEXT;
    case 2:
      return mobShare.ShareType.IMAGE;
    case 3:
      return mobShare.ShareType.WEBPAGE;
    case 4:
      return mobShare.ShareType.WEBPAGE;
    case 6:
      return mobShare.ShareType.VIDEO;
    case 10:
      return mobShare.ShareType.SHARE_WXMINIPROGRAM;
    case 12:
      return mobShare.ShareType.OPEN_WXMINIPROGRAM;
    default:
      return mobShare.ShareType.WEBPAGE;
  }
}

/**
 * 微信「原始授权码」会话的兜底时长。
 *
 * 用户跳到微信后可能再也不回来（直接杀掉微信、或停在微信里很久），这种情况微信
 * 不会回任何 want。没有兜底的话 Dart 侧的 Completer 永远不完成，用户看到的是
 * 「点了微信登录之后什么都不发生」——连一句失败提示都没有。
 */
const WECHAT_AUTH_CODE_TIMEOUT_MS = 180000;

function makePluginError(message: string): PluginError {
  const err: PluginError = { message: message };
  return err;
}

/**
 * 微信授权：**绕开 ShareSDK 直接用 `@tencent/wechat_open_sdk` 取原始 code**。
 *
 * 为什么不用 ShareSDK 自己的授权（`platform.showUser()` / `platform.authorize()`）：
 * 底层 `@zztsdk/sharesdk` 的鸿蒙实现有两条硬约束，合起来让「拿原始 code」在鸿蒙上不可能——
 *
 * 1. `WechatPlatform.initPlatform` 里 `isTextEmpty(appKey) || isTextEmpty(appSecret)`
 *    就抛 `wechat init fail,please check appKey and appSecret`：**不配 AppSecret 连初始化都过不去**，
 *    而 iOS / Android 是「不配 secret 就把 code 原样给你」；
 * 2. 微信授权回包 `onResp` 里拿到 code 之后**无条件**调 `requestAuthToken(appId, appSecret, code)`
 *    换 access_token，原始 code 从不落 db（整个 har 里只有 QQ 分支写过 `authCode` 这个 key）。
 *
 * 也就是说走 ShareSDK 的话，客户端要么拿不到东西，要么只能拿到 access_token，且必须把
 * 微信 AppSecret 打进包里。而授权码流的服务端要的正是原始 code，AppSecret 也只该留在服务端。
 *
 * 微信官方 SDK 的 `SendAuthReq` 本来就只需要 appId，回包直接带 code——所以登录这条路
 * 自己发一次 `SendAuthReq` 即可。分享仍然走 ShareSDK（分享不碰 AppSecret）。
 *
 * 生命周期：请求发出后本会话挂在 `SharesdkPlugin.pendingWechatAuthCode` 上，
 * 由 `SharesdkPlugin.handleWant` 在 `onNewWant` 时喂回包；结算后立即摘除。
 */
class WechatAuthCodeSession implements WXApiEventHandler {
  private readonly api: WXApi;
  private readonly result: MethodResult;
  private readonly state: string;
  private readonly onSettled: () => void;
  private settled: boolean = false;
  private timerId: number = -1;

  constructor(api: WXApi, result: MethodResult, state: string, onSettled: () => void) {
    this.api = api;
    this.result = result;
    this.state = state;
    this.onSettled = onSettled;
    this.timerId = setTimeout(() => {
      console.warn('[SharesdkPlugin] wechat authCode timeout, treat as cancel');
      this.settleCancel();
    }, WECHAT_AUTH_CODE_TIMEOUT_MS);
  }

  onReq(_req: BaseReq): void {
  }

  onResp(resp: BaseResp): void {
    if (!(resp instanceof SendAuthResp)) {
      return;
    }
    const authResp = resp as SendAuthResp;
    // state 对不上说明这条回包属于别人发起的授权（例如 ShareSDK 自己的微信授权），
    // 不认领——认领了会把别人的结果当成自己的，还会顺手把本会话结算掉。
    if (this.state.length > 0 && authResp.state !== undefined && authResp.state !== this.state) {
      return;
    }
    if (authResp.errCode === ErrCode.ERR_USER_CANCEL || authResp.errCode === ErrCode.ERR_AUTH_DENIED) {
      this.settleCancel();
      return;
    }
    if (authResp.errCode !== ErrCode.ERR_OK) {
      this.settleFail(`wechat auth failed, errCode=${authResp.errCode}, errStr=${authResp.errStr ?? ''}`);
      return;
    }
    const code: string = authResp.code ?? '';
    if (code.length === 0) {
      // 微信返回成功却没有 code，正常不该发生；当失败处理而不是静默成功，
      // 否则 Dart 侧会拿到一个「成功但空凭证」的结果，更难排查。
      this.settleFail('wechat auth succeeded but code is empty');
      return;
    }
    const userMap = new Map<string, Object>();
    // 键名与 iOS 的 `SSDKCredential.authCode`、鸿蒙 db 常量 `consts.KET_AUTH_CODE` 一致，
    // Dart 侧的凭证适配器认的就是它。
    userMap.set('authCode', code);
    if (authResp.openId !== undefined && authResp.openId.length > 0) {
      userMap.set('openid', authResp.openId);
    }
    const okResult: UserInfoResult = { state: 1, user: userMap };
    this.settle(okResult);
  }

  /**
   * 把 newWant 交给微信 SDK 解析。
   * 返回 true 表示这条 want 确实是微信回包、已被消费，调用方不必再转给 ShareSDK。
   */
  handleWant(want: Want): boolean {
    if (this.settled) {
      return false;
    }
    return this.api.handleWant(want, this);
  }

  /**
   * 微信可能不经 `onNewWant` 而直接用 `openLink` 的回调送回包（宿主 `querySchemes`
   * 声明了 `wxopensdk` 时走这条），那条路只认 `handleWant` 里装上的 eventHandler。
   * 这里用一个空 want 空跑一次，纯粹为了把 handler 装进去——空 want 没有 parameters，
   * SDK 会直接返回 false，不会有任何副作用。
   */
  installEventHandler(): void {
    const emptyWant: Want = {};
    this.api.handleWant(emptyWant, this);
  }

  settleCancel(): void {
    const cancelResult: UserInfoResult = { state: 3 };
    this.settle(cancelResult);
  }

  settleFail(message: string): void {
    console.warn(`[SharesdkPlugin] wechat authCode failed: ${message}`);
    const failResult: UserInfoResult = { state: 2, error: makePluginError(message) };
    this.settle(failResult);
  }

  private settle(res: UserInfoResult): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.onSettled();
    this.result.success(res);
  }
}

export class SharesdkPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private static abilityContext: common.UIAbilityContext | null = null;
  /** 宿主 App 传入的 Mob appKey/appSecret，插件本身不内置任何凭据 */
  private static mobAppKey: string = '';
  private static mobAppSecret: string = '';
  /**
   * 微信开放平台 AppID，由 Dart 侧 `regist` 传入时缓存。
   *
   * 单独存一份而不是回头找 ShareSDK 要：`ShareSDK.setPlatformDevInfoAsync` 会在
   * 隐私未授权时**默默丢弃** devInfo（只打一行 `isForbidden use Platform.DEFAULT`），
   * 而微信授权码这条路根本不经过 ShareSDK，不该被它的授权状态连坐。
   */
  private static wechatAppId: string = '';
  /** 进行中的微信授权码会话；同一时刻只允许一个 */
  private static pendingWechatAuthCode: WechatAuthCodeSession | null = null;

  getUniqueClassName(): string {
    return 'SharesdkPlugin';
  }

  /**
   * 在 EntryAbility.onCreate 中调用。
   * appKey/appSecret 为 Mob 后台申请的应用凭据：传入后即在此完成 ZztSDK 初始化；
   * 若不传，则需在 Dart 侧调用 uploadPrivacyPermissionStatus 时通过具名参数传入。
   */
  static setUIAbilityContext(context: common.UIAbilityContext, appKey?: string, appSecret?: string): void {
    SharesdkPlugin.abilityContext = context;
    if (appKey != null && appKey.length > 0) {
      SharesdkPlugin.mobAppKey = appKey;
    }
    if (appSecret != null && appSecret.length > 0) {
      SharesdkPlugin.mobAppSecret = appSecret;
    }
    if (ZztSDK.getContext() == null
      && SharesdkPlugin.mobAppKey.length > 0
      && SharesdkPlugin.mobAppSecret.length > 0) {
      ZztSDK.init(context, SharesdkPlugin.mobAppKey, SharesdkPlugin.mobAppSecret);
    }
    mobShare.ShareSDK.getInstance().setUIAbilityContext(context);
  }

  static handleWant(want: Want, context: common.UIAbilityContext): void {
    // 微信授权码会话优先：它是自己发的 SendAuthReq，回包只有它认得。
    // 消费掉就不再转给 ShareSDK——同一条回包被两边处理会让 ShareSDK 报无主回调。
    const pending = SharesdkPlugin.pendingWechatAuthCode;
    if (pending != null && pending.handleWant(want)) {
      return;
    }
    mobShare.ShareSDK.getInstance().handlerWant(want, context);
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      switch (call.method) {
        case 'getVersion':
          result.success(mobShare.SDK_VERSION_NAME);
          return;
        case 'regist':
          await this.handleRegist(call, result);
          return;
        case 'getUserInfo':
          await this.handleGetUserInfo(call, result);
          return;
        case 'share':
          await this.handleShare(call, result);
          return;
        case 'shareWithActivity':
          await this.handleShare(call, result);
          return;
        case 'auth':
          await this.handleAuth(call, result);
          return;
        case 'hasAuthed':
          await this.handleHasAuthed(call, result);
          return;
        case 'cancelAuth':
          await this.handleCancelAuth(call, result);
          return;
        case 'isClientInstalled':
          await this.handleIsClientInstalled(call, result);
          return;
        case 'uploadPrivacyPermissionStatus':
          await this.handleUploadPrivacyPermissionStatus(call, result);
          return;
        case 'targetFilePath':
          await this.handleTargetFilePath(call, result);
          return;
        case 'activePlatforms':
          this.handleActivePlatforms(result);
          return;
        case 'openMiniProgram':
          await this.handleOpenMiniProgram(call, result);
          return;
        case 'showMenu':
          await this.handleShowMenu(call, result);
          return;
        case 'showEditor':
          await this.handleShare(call, result);
          return;
        case 'setAllowShowPrivacyWindow':
          result.success(null);
          return;
        case 'setPrivacyUI':
          result.success(null);
          return;
        case 'getPrivacyPolicy':
          this.handleGetPrivacyPolicy(result);
          return;
        case 'getBundleSignatureFingerprint':
          await this.handleGetBundleSignatureFingerprint(result);
          return;
        default:
          result.notImplemented();
          return;
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      result.error('SharesdkPlugin', call.method, message);
    }
  }

  private asMap(value: Any): Map<string, Object> | null {
    if (value instanceof Map) {
      return value as Map<string, Object>;
    }
    return null;
  }

  private toString(value: Object | undefined | null): string {
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number') {
      return value.toString();
    }
    if (typeof value === 'boolean') {
      return value ? 'true' : 'false';
    }
    return '';
  }

  private toNumber(value: Object | undefined | null, fallback: number): number {
    if (typeof value === 'number') {
      return value;
    }
    const text = this.toString(value);
    if (text.length === 0) {
      return fallback;
    }
    const parsed = Number(text);
    if (Number.isNaN(parsed)) {
      return fallback;
    }
    return parsed;
  }

  private createError(message: string): PluginError {
    const err: PluginError = { message: message };
    return err;
  }

  private extractErrorMessage(error: Error): string {
    if (error == null) {
      return 'unknown error';
    }
    const msg = error.message;
    if (msg != null && typeof msg === 'string' && msg.length > 0) {
      return msg;
    }
    const str = error.toString();
    if (str != null && typeof str === 'string' && str.length > 0) {
      return str;
    }
    return 'unknown error';
  }

  private createActionResult(state: number, errorMessage: string): ActionResult {
    const res: ActionResult = { state: state };
    if (errorMessage.length > 0) {
      res.error = this.createError(errorMessage);
    }
    return res;
  }

  private async ensureZztInitialized(appKey: string, appSecret: string): Promise<void> {
    if (appKey.length === 0 || appSecret.length === 0) {
      throw new Error('Mob appKey/appSecret is required for ZztSDK.init. '
        + 'Pass them via SharesdkPlugin.setUIAbilityContext(context, appKey, appSecret) in EntryAbility, '
        + 'or via SharesdkPlugin.uploadPrivacyPermissionStatus(status, cb, appKey: ..., appSecret: ...) from Dart.');
    }
    const currentContext = ZztSDK.getContext();
    const currentAppKey = ZztSDK.getAppKey();
    const currentAppSecret = ZztSDK.getAppSecret();
    if (currentContext != null && currentAppKey === appKey && currentAppSecret === appSecret) {
      return;
    }
    let context = SharesdkPlugin.abilityContext;
    if (context == null) {
      context = await this.getContextAsync();
    }
    ZztSDK.init(context, appKey, appSecret);
  }

  private async handleRegist(call: MethodCall, result: MethodResult): Promise<void> {
    // Flutter 传入的是 register.platformsInfo 本身，即 { 997: {...}, 998: {...} }
    const platformsInfo = this.asMap(call.args);
    if (platformsInfo == null) {
      result.success(null);
      return;
    }
    const ids: string[] = ['997', '998'];
    const sdk = mobShare.ShareSDK.getInstance();
    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      const info = this.asMap(platformsInfo.get(id));
      if (info == null) {
        continue;
      }
      const platformName = platformNameFromId(this.toNumber(id, -1));
      if (platformName == null) {
        continue;
      }
      const map = new HashMap<string, Object>();
      let hasAny = false;
      const appId = this.toString(info.get('app_id'));
      const appKey = this.toString(info.get('app_key'));
      const appSecret = this.toString(info.get('app_secret'));
      const redirectUri = this.toString(info.get('redirect_uri'));
      if (platformName === mobShare.Platform.Wechat) {
        if (appId.length > 0) {
          // 授权码这条路只需要 appId，先单独留一份（理由见 wechatAppId 的注释）。
          SharesdkPlugin.wechatAppId = appId;
          map.set(mobShare.Platform_Info.APP_KEY, appId);
          hasAny = true;
        }
        if (appSecret.length > 0) {
          map.set(mobShare.Platform_Info.APP_SECRET, appSecret);
          hasAny = true;
        }
      } else if (platformName === mobShare.Platform.QQ) {
        if (appId.length > 0) {
          map.set(mobShare.Platform_Info.APP_ID, appId);
          hasAny = true;
        }
        if (appKey.length > 0) {
          map.set(mobShare.Platform_Info.APP_KEY, appKey);
          hasAny = true;
        }
        if (redirectUri.length > 0) {
          map.set(mobShare.Platform_Info.REDIRECT_URL, redirectUri);
          hasAny = true;
        }
      }
      if (hasAny) {
        await sdk.setPlatformDevInfoAsync(platformName, map);
      }
    }
    result.success(null);
  }

  /**
   * 调用方是否要「微信原始授权码」。
   *
   * 复用 Flutter 侧既有的 `getUserInfoWithParam(platform, {"needAuthCode": true}, ...)`
   * 约定（Android 用它开 `platName.needAuthCode(true)`，iOS 原样透传给原生），
   * 不另立方法名——这样三端 Dart 代码保持一条路。不传这个开关时行为完全不变，
   * 仍走 ShareSDK 的 `showUser()`，老接入方不受影响。
   */
  private wantsWechatAuthCode(platformName: string, args: Map<string, Object> | null): boolean {
    if (platformName !== mobShare.Platform.Wechat || args == null) {
      return false;
    }
    const raw = args.get('needAuthCode');
    if (typeof raw === 'boolean') {
      return raw as boolean;
    }
    return this.toString(raw) === 'true';
  }

  /** 见 [WechatAuthCodeSession] 的说明：绕开 ShareSDK，自己发一次 SendAuthReq 取 code。 */
  private async handleWechatAuthCode(result: MethodResult): Promise<void> {
    const appId = SharesdkPlugin.wechatAppId;
    if (appId.length === 0) {
      const noAppId: UserInfoResult = {
        state: 2,
        error: this.createError('wechat appId is missing. Call SharesdkPlugin.regist(...) '
          + 'with ShareSDKRegister.setupWechat(appId, ...) before authorizing.'),
      };
      result.success(noAppId);
      return;
    }
    // 上一次授权还没结算（用户切走没回来）时又点了一次：老会话按取消结束。
    // 留着两个 pending 会让先来的那个抢走回包，表现为「第二次点没反应」。
    const previous = SharesdkPlugin.pendingWechatAuthCode;
    if (previous != null) {
      SharesdkPlugin.pendingWechatAuthCode = null;
      previous.settleCancel();
    }
    const context = await this.getContextAsync();
    const api = WXAPIFactory.createWXAPI(appId);
    const state = `ssdk_${Date.now()}`;
    const session = new WechatAuthCodeSession(api, result, state, () => {
      if (SharesdkPlugin.pendingWechatAuthCode === session) {
        SharesdkPlugin.pendingWechatAuthCode = null;
      }
    });
    SharesdkPlugin.pendingWechatAuthCode = session;
    session.installEventHandler();
    const req = new SendAuthReq();
    // 与 ShareSDK 自己的授权取同一个 scope，保证服务端换到的用户信息范围一致。
    req.scope = 'snsapi_userinfo';
    req.state = state;
    try {
      const sent = await api.sendReq(context, req);
      if (!sent) {
        // 拉不起微信（没装 / querySchemes 少了 weixin / 被系统拦下）。
        session.settleFail('failed to launch WeChat for authorization');
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      session.settleFail(`sendReq failed: ${message}`);
    }
  }

  private async handleGetUserInfo(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const platformId = args != null ? this.toNumber(args.get('platform'), -1) : -1;
    const platformName = platformNameFromId(platformId);
    if (platformName == null) {
      const unsupported: UserInfoResult = { state: 2, error: this.createError('unsupported platform') };
      result.success(unsupported);
      return;
    }
    if (this.wantsWechatAuthCode(platformName, args)) {
      await this.handleWechatAuthCode(result);
      return;
    }
    const context = await this.getContextAsync();
    await mobShare.ShareSDK.getInstance().setUIAbilityContext(context);
    const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
    platform.setPlatformActionListener({
      onComplete: (_platform: mobShare.IPlatform, _action: number, _res: Map<string, Object>): void => {
        const dbMessage = platform.getDb().exportData();
        const userMap = new Map<string, Object>();
        userMap.set('raw', dbMessage);
        const okResult: UserInfoResult = { state: 1, user: userMap };
        result.success(okResult);
      },
      onError: (_platform: mobShare.IPlatform, _action: number, error: Error): void => {
        const msg = this.extractErrorMessage(error);
        console.warn(`[SharesdkPlugin] getUserInfo onError: ${msg}`);
        const failResult: UserInfoResult = { state: 2, error: this.createError(msg) };
        result.success(failResult);
      },
      onCancel: (_platform: mobShare.IPlatform, _action: number): void => {
        const cancelResult: UserInfoResult = { state: 3 };
        result.success(cancelResult);
      },
    });
    platform.showUser();
  }

  private buildSharedParam(params: Map<string, Object> | null, shareType: string, scene: number): mobShare.SharedParam {
    const record: mobShare.SharedParam = {
      utd: shareType,
      scene: scene,
    };
    if (params == null) {
      return record;
    }
    const title = this.toString(params.get('title'));
    const text = this.toString(params.get('text'));
    const url = this.toString(params.get('url'));
    const description = this.toString(params.get('description')).length > 0
      ? this.toString(params.get('description'))
      : this.toString(params.get('desc'));
    const imageUrlRaw = this.toString(params.get('imageUrl'));
    const thumbImageRaw = this.toString(params.get('thumbImage'));
    const thumbImageAlt = this.toString(params.get('thumb_image'));
    const imageUrlAndroid = this.toString(params.get('imageUrl_android'));
    const imagesRaw = params.get('images');
    const imagesStr = typeof imagesRaw === 'string' ? imagesRaw : '';
    const imageUrl = imageUrlRaw.length > 0
      ? imageUrlRaw
      : (thumbImageRaw.length > 0 ? thumbImageRaw
        : (thumbImageAlt.length > 0 ? thumbImageAlt
          : (imageUrlAndroid.length > 0 ? imageUrlAndroid : imagesStr)));
    const miniProgramUserName = this.toString(params.get('wxmp_user_name'));
    const miniProgramPath = this.toString(params.get('wxmp_path'));
    const miniProgramType = this.toNumber(params.get('wxmp_type'), -1);
    const withShareTicketRaw = params.get('wxmp_with_ticket');

    if (text.length > 0) {
      record.content = text;
    }
    if (title.length > 0) {
      record.title = title;
    }
    if (url.length > 0) {
      record.url = url;
    }
    if (description.length > 0) {
      record.description = description;
    } else if (text.length > 0) {
      record.description = text;
    }
    if (imageUrl.length > 0) {
      record.imageUrl = imageUrl;
      record.thumbnailUri = imageUrl;
    }
    if (miniProgramUserName.length > 0) {
      record.miniProgramUserName = miniProgramUserName;
    }
    if (miniProgramPath.length > 0) {
      record.miniProgramPath = miniProgramPath;
    }
    if (miniProgramType >= 0) {
      record.miniProgramType = miniProgramType;
    }
    if (typeof withShareTicketRaw === 'boolean') {
      record.withShareTicket = withShareTicketRaw;
    }
    return record;
  }

  private getParamsForPlatform(allParams: Map<string, Object> | null, platformId: number): Map<string, Object> | null {
    if (allParams == null) {
      return null;
    }
    const platformKey = '@platform(' + platformId + ')';
    const platformParams = this.asMap(allParams.get(platformKey));
    if (platformParams != null && platformParams.size > 0) {
      return platformParams;
    }
    return allParams;
  }

  private async handleShare(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const platformId = args != null ? this.toNumber(args.get('platform'), -1) : -1;
    const platformName = platformNameFromId(platformId);
    if (platformName == null) {
      result.success(this.createActionResult(2, 'unsupported platform'));
      return;
    }
    const allParams = args != null ? this.asMap(args.get('params')) : null;
    const params = this.getParamsForPlatform(allParams, platformId);
    const typeNum = params != null ? this.toNumber(params.get('type'), 3) : 3;
    const shareType = shareTypeFromContentType(typeNum);
    const scene = sceneFromPlatformId(platformId);
    const context = await this.getContextAsync();
    await mobShare.ShareSDK.getInstance().setUIAbilityContext(context);
    const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
    platform.setPlatformActionListener({
      onComplete: (_platform: mobShare.IPlatform, _action: number, _res: Map<string, Object>): void => {
        result.success(this.createActionResult(1, ''));
      },
      onError: (_platform: mobShare.IPlatform, _action: number, error: Error): void => {
        const msg = this.extractErrorMessage(error);
        result.success(this.createActionResult(2, msg));
      },
      onCancel: (_platform: mobShare.IPlatform, _action: number): void => {
        result.success(this.createActionResult(3, ''));
      },
    });
    const record = this.buildSharedParam(params, shareType, scene);
    const imgUrl = record.imageUrl;
    if (imgUrl != null && imgUrl.length > 0 && imgUrl.startsWith('http')) {
      const thumbData = await this.downloadAndProcessThumbnail(imgUrl);
      if (thumbData != null) {
        // MobTech HarmonyOS 文档：微信网页分享优先使用 imageData 作为缩略图数据。
        record.imageData = thumbData;
        record.thumbnail = thumbData;
      }
    }
    const records: mobShare.SharedParam[] = [record];
    platform.share(records, context);
  }

  private async handleAuth(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const platformId = args != null ? this.toNumber(args.get('platform'), -1) : -1;
    const platformName = platformNameFromId(platformId);
    if (platformName == null) {
      result.success(this.createActionResult(2, 'unsupported platform'));
      return;
    }
    if (this.wantsWechatAuthCode(platformName, args)) {
      await this.handleWechatAuthCode(result);
      return;
    }
    const context = await this.getContextAsync();
    await mobShare.ShareSDK.getInstance().setUIAbilityContext(context);
    const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
    platform.setPlatformActionListener({
      onComplete: (_platform: mobShare.IPlatform, _action: number, _res: Map<string, Object>): void => {
        const dbMessage = platform.getDb().exportData();
        const userMap = new Map<string, Object>();
        userMap.set('raw', dbMessage);
        const okResult: UserInfoResult = { state: 1, user: userMap };
        result.success(okResult);
      },
      onError: (_platform: mobShare.IPlatform, _action: number, error: Error): void => {
        const msg = this.extractErrorMessage(error);
        result.success(this.createActionResult(2, msg));
      },
      onCancel: (_platform: mobShare.IPlatform, _action: number): void => {
        result.success(this.createActionResult(3, ''));
      },
    });
    platform.authorize();
  }

  private async handleHasAuthed(call: MethodCall, result: MethodResult): Promise<void> {
    const platformId = this.toNumber(call.args as Object, -1);
    const platformName = platformNameFromId(platformId);
    if (platformName == null) {
      const noAuthResult: UserInfoResult = { state: 2 };
      result.success(noAuthResult);
      return;
    }
    const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
    const valid = await platform.isAuthValid();
    if (valid) {
      const data = new Map<string, Object>();
      data.set('auth', new SharedUserMarker());
      const okResult: UserInfoResult = { state: 1, user: data };
      result.success(okResult);
      return;
    }
    const noAuthResult: UserInfoResult = { state: 1 };
    result.success(noAuthResult);
  }

  private async handleCancelAuth(call: MethodCall, result: MethodResult): Promise<void> {
    const platformId = this.toNumber(call.args as Object, -1);
    const platformName = platformNameFromId(platformId);
    if (platformName != null) {
      const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
      platform.removeAccount();
    }
    result.success(this.createActionResult(1, ''));
  }

  private async handleIsClientInstalled(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const platformId = args != null ? this.toNumber(args.get('platform'), -1) : -1;
    const platformName = platformNameFromId(platformId);
    if (platformName == null) {
      result.success(false);
      return;
    }
    const platform = await mobShare.ShareSDK.getInstance().getPlatformAsync(platformName);
    let installed = await platform.isClientValid();
    // 鸿蒙上 ShareSDK 的 isClientValid 可能无法正确检测微信/QQ，使用 canOpenLink 作为回退
    if (!installed && (platformName === mobShare.Platform.Wechat || platformName === mobShare.Platform.QQ)) {
      try {
        const scheme = platformName === mobShare.Platform.Wechat ? 'weixin://' : 'mqqapi://';
        installed = bundleManager.canOpenLink(scheme);
      } catch (_e) {
        // canOpenLink 失败时保持 isClientValid 的结果
      }
    }
    result.success(installed);
  }

  private async handleUploadPrivacyPermissionStatus(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const status = args != null ? this.toNumber(args.get('status'), 0) : 0;
    const appKey = args != null ? this.toString(args.get('appKey')) : '';
    const appSecret = args != null ? this.toString(args.get('appSecret')) : '';
    const finalAppKey = appKey.length > 0 ? appKey : SharesdkPlugin.mobAppKey;
    const finalAppSecret = appSecret.length > 0 ? appSecret : SharesdkPlugin.mobAppSecret;
    await this.ensureZztInitialized(finalAppKey, finalAppSecret);
    const granted = status === 1;
    ZztSDK.submitPolicyGrantResult(granted);
    const response: PrivacyResult = { success: true };
    result.success(response);
  }

  private async handleTargetFilePath(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const name = args != null ? this.toString(args.get('name')) : '';
    const type = args != null ? this.toString(args.get('type')) : '';
    let filename = name.length > 0 ? name : 'share_file';
    if (type.length > 0) {
      filename = filename + '.' + type;
    }
    // OHOS 侧保持接口兼容，回传可写文件名；实际路径由业务按需处理。
    const response: TargetFilePathResult = { path: filename };
    result.success(response);
  }

  private handleActivePlatforms(result: MethodResult): void {
    result.success([997, 998, 63]);
  }

  private async handleOpenMiniProgram(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    const userName = args != null ? this.toString(args.get('userName')) : '';
    const path = args != null ? this.toString(args.get('path')) : '';
    const miniProgramType = args != null ? this.toNumber(args.get('type'), 0) : 0;
    const params = new Map<string, Object>();
    params.set('type', 12);
    params.set('wxmp_user_name', userName);
    params.set('wxmp_path', path);
    params.set('wxmp_type', miniProgramType);
    const wrappedArgs = new Map<string, Object>();
    wrappedArgs.set('platform', 22);
    wrappedArgs.set('params', params);
    const bridgeCall = new MethodCall('share', wrappedArgs);
    await this.handleShare(bridgeCall, result);
  }

  private async handleShowMenu(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.asMap(call.args);
    if (args == null) {
      result.success(this.createActionResult(2, 'invalid args'));
      return;
    }
    const platformsValue = args.get('platforms');
    let platformId: number = 22;
    if (platformsValue instanceof Array && platformsValue.length > 0) {
      const first = platformsValue[0] as Object;
      platformId = this.toNumber(first, 22);
    }
    const forwardArgs = new Map<string, Object>();
    forwardArgs.set('platform', platformId);
    const params = this.asMap(args.get('params'));
    if (params != null) {
      forwardArgs.set('params', params);
    }
    const bridgeCall = new MethodCall('share', forwardArgs);
    await this.handleShare(bridgeCall, result);
  }

  private handleGetPrivacyPolicy(result: MethodResult): void {
    const response: PrivacyPolicyResult = {
      error: this.createError('getPrivacyPolicy is not supported on OHOS plugin'),
    };
    result.success(response);
  }

  /**
   * 获取鸿蒙应用签名 fingerprint，并按 QQ 互联文档要求计算 MD5 32 位。
   * 用于提交至腾讯开放平台配置 QQ 登录。
   */
  private async handleGetBundleSignatureFingerprint(result: MethodResult): Promise<void> {
    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleFlags);
      const sigInfo = bundleInfo.signatureInfo;
      if (sigInfo == null || sigInfo.fingerprint == null || sigInfo.fingerprint.length === 0) {
        result.error('SharesdkPlugin', 'getBundleSignatureFingerprint', 'signatureInfo or fingerprint is empty');
        return;
      }
      const fingerprint = sigInfo.fingerprint.toLowerCase();
      const fingerprintMd5 = await this.computeMd5Hex(fingerprint);
      const bundleName = bundleInfo.name != null ? bundleInfo.name : '';
      const res: BundleSignatureResult = {
        fingerprint: fingerprint,
        fingerprintMd5: fingerprintMd5,
        bundleName: bundleName,
      };
      result.success(res);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      result.error('SharesdkPlugin', 'getBundleSignatureFingerprint', message);
    }
  }

  private async computeMd5Hex(input: string): Promise<string> {
    const encoder = new util.TextEncoder('utf-8');
    const data = encoder.encodeInto(input);
    const md = cryptoFramework.createMd('MD5');
    await md.update({ data: data });
    const mdResult = await md.digest();
    return this.uint8ArrayToHex(mdResult.data);
  }

  private uint8ArrayToHex(arr: Uint8Array): string {
    let hex = '';
    for (let i = 0; i < arr.length; i++) {
      const b = arr[i];
      const h = b.toString(16);
      hex = hex + (h.length === 1 ? '0' + h : h);
    }
    return hex.toLowerCase();
  }

  private async downloadAndProcessThumbnail(url: string): Promise<Uint8Array | null> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      });
      httpRequest.destroy();
      if (response.responseCode !== 200) {
        return null;
      }
      const rawBuffer = response.result as ArrayBuffer;
      if (rawBuffer == null || rawBuffer.byteLength === 0) {
        return null;
      }
      let best: Uint8Array | null = null;
      const qualityList: number[] = [80, 70, 60, 50, 40, 30];
      const sizeList: number[] = [0, 200, 160, 120, 96, 72];
      for (let si = 0; si < sizeList.length; si++) {
        const side = sizeList[si];
        const imageSource = image.createImageSource(rawBuffer);
        const pixelMap = side > 0
          ? await imageSource.createPixelMap({ desiredSize: { width: side, height: side } })
          : await imageSource.createPixelMap();
        for (let qi = 0; qi < qualityList.length; qi++) {
          const quality = qualityList[qi];
          const packer = image.createImagePacker();
          const packedBuffer = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: quality });
          packer.release();
          const current = new Uint8Array(packedBuffer);
          if (best == null || current.byteLength < best.byteLength) {
            best = current;
          }
          // 微信 thumbData 要求 <= 64KB
          if (current.byteLength <= 65536) {
            pixelMap.release();
            imageSource.release();
            return current;
          }
        }
        pixelMap.release();
        imageSource.release();
      }
      return best;
    } catch (_e) {
      return null;
    }
  }

  private async getContextAsync(): Promise<common.UIAbilityContext> {
    if (SharesdkPlugin.abilityContext != null) {
      return SharesdkPlugin.abilityContext as common.UIAbilityContext;
    }
    const context = await mobShare.ShareSDK.getInstance().getUIAbilityContext();
    if (context == null) {
      throw new Error('ShareSDK UIAbilityContext not set.');
    }
    return context;
  }
}
