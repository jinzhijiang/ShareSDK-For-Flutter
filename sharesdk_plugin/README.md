
# ShareSDK For Flutter
### 这是一个基于ShareSDK功能的扩展的Flutter插件。使用此插件能够帮助您在使用Flutter开发应用时,快速地实现社会化功能,例如第三方授权登录,获取用户信息以及社交平台的分享等功能。

**原生SDK支持的最低版本:**

- [Android](https://github.com/MobClub/ShareSDK-for-Android) - V3.4.0
- [iOS](https://github.com/MobClub/ShareSDK-for-iOS) - V4.3.2

**简介：** http://www.mob.com/product/sharesdk

**插件主页：** https://pub.dartlang.org/packages/sharesdk_plugin

**官网文档：** http://wiki.mob.com/快速集成/

**Demo例子：** https://github.com/MobClub/ShareSDK-For-Flutter/sharesdk_plugin

## 开始集成

参考[官方插件集成文档](https://pub.dartlang.org/packages/sharesdk#-installing-tab-)

自定义需要导入的分享平台:
### iOS 
 你需要重新编辑 *sharesdk.podspec* 文件设置 dependency，具体支持的平台可以参阅`pod search mob_sharesdk` 或者参考[官网文档](https://www.mob.com/wiki/detailed?wiki=4&id=14)

```
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
s.name             = 'sharesdk'
s.version          = '0.0.1'
s.summary          = 'flutter plugin for sharesdk.'
s.description      = 'ShareSDK is the most comprehensive Social SDK in the world,which share easily with 40+ platforms.'
s.homepage         = 'http://www.mob.com'
s.license          = { :file => '../LICENSE' }
s.author           = { 'Mob' => 'mobproducts@163.com' }
s.source           = { :path => '.' }
s.source_files = 'Classes/**/*'
s.public_header_files = 'Classes/**/*.h'
s.dependency 'Flutter'
s.dependency 'mob_sharesdk'
#  s.dependency 'mob_sharesdk/ShareSDKUI'
#  s.dependency 'mob_sharesdk/ShareSDKPlatforms/QQ'
#  s.dependency 'mob_sharesdk/ShareSDKPlatforms/SinaWeibo'
#  s.dependency 'mob_sharesdk/ShareSDKPlatforms/WeChat'
#  s.dependency 'mob_sharesdk/ShareSDKPlatforms/Facebook'
#  s.dependency 'mob_sharesdk/ShareSDKPlatforms/Twitter'

s.ios.deployment_target = '8.0'
end
```

然后你需要根据[官方文档](https://www.mob.com/wiki/detailed?wiki=484&id=14)在Xcode工程的info.plist里面配置Appkey 和 AppSecret, 以及各平台的白名单和urlScheme。

### Android
你需要重新编辑build.gradle, mobsdk.gradle文件来选择你需要使用的平台，具体支持的平台可以参阅[官网技术文档](https://www.mob.com/wiki/detailed?wiki=485&id=14)

#### build.gradle

```
buildscript {
    repositories {
                    google()
                    jcenter()
                    maven {
                    url "http://mvn.mob.com/android"
                    }
                 }

    dependencies {
                    classpath 'com.android.tools.build:gradle:3.1.2'
                    classpath 'com.mob.sdk:MobSDK:+'
                 }
}
```

#### mobsdk.gradle

```
MobSDK {
    appKey "moba6b6c6d6"
    appSecret "b89d2427a3bc7ad1aea1e1e8c1d36bf3"

        ShareSDK {

            // platform configuration information
            devInfo {
                        QQ {
                        id 7
                        sortId 7
                        appId "100371282"
                        appKey "aed9b0303e3ed1e27bae87c33761161d"
                        shareByAppClient true
                        bypassApproval false
                        enable true
                        }

                        SinaWeibo {
                        id 1
                        sortId 1
                        appKey "568898243"
                        appSecret "38a4f8204cc784f81f9f0daaf31e02e3"
                        callbackUri "http://www.sharesdk.cn"
                        shareByAppClient true
                        enable true
                        }

                        Wechat {
                        id 4
                        sortId 4
                        appId "wx4868b35061f87885"
                        appSecret "64020361b8ec4c99936c0e3999a9f249"
                        userName "gh_afb25ac019c9"
                        path "pages/index/index.html?id=1"
                        withShareTicket true
                        miniprogramType 0
                        bypassApproval false
                        enable true
                        }

                        Facebook {
                        id 8
                        sortId 8
                        appKey "1412473428822331"
                        appSecret "a42f4f3f867dc947b9ed6020c2e93558"
                        callbackUri "https://mob.com"
                        shareByAppClient true
                        enable true
                        }

                        Twitter {
                        id 9
                        sortId 9
                        appKey "viOnkeLpHBKs6KXV7MPpeGyzE"
                        appSecret "NJEglQUy2rqZ9Io9FcAU9p17omFqbORknUpRrCDOK46aAbIiey"
                        callbackUri "http://mob.com"
                        shareByAppClient true
                        enable true
                        }
                    }
                }
}
```

### 鸿蒙 HarmonyOS NEXT

本分支额外提供了鸿蒙实现（`ohos/` 目录，ArkTS 编写，底层依赖 ohpm 上的 `@zztsdk/sharesdk` 与 `@zztsdk/zztcore`）。
需要使用支持鸿蒙的 Flutter SDK（[openharmony-sig/flutter_flutter](https://gitcode.com/openharmony-sig/flutter_flutter)）。

#### 支持范围

| 能力 | 鸿蒙支持情况 |
| --- | --- |
| 平台 | 微信（`wechatSession` 22 / `wechatTimeline` 23 / `weChatFavorites` 37 / `wechatSeries` 997）、QQ（`qq` 24 / `qZone` 6 / `qqSeries` 998）、华为帐号（`HWAccount` 63） |
| 接口 | `getVersion`、`regist`、`auth`、`getUserInfo`、`hasAuthed`、`cancelAuth`、`share`、`shareWithActivity`、`showEditor`、`showMenu`、`openMiniProgram`、`isClientInstalled`、`activePlatforms`、`uploadPrivacyPermissionStatus`、`targetFilePath` |
| 空实现 | `setAllowShowPrivacyWindow`、`setPrivacyUI`（鸿蒙侧无隐私弹窗 UI，直接返回成功） |
| 未支持 | `getPrivacyPolicy`（返回 error）；其余未在上表列出的平台调用会返回 `state = 2` 并带 `unsupported platform` |
| 额外接口 | `getBundleSignatureFingerprint()`，见下文 |

#### 一、引入插件

```yaml
dependencies:
  sharesdk_plugin:
    git:
      url: https://github.com/jinzhijiang/ShareSDK-For-Flutter.git
      path: sharesdk_plugin
```

也可以直接把 `sharesdk_plugin` 放到工程的 `packages/` 下用 `path:` 引用。

#### 二、配置鸿蒙工程

以下三处需要手工添加（鸿蒙 Flutter 工具链目前只会自动生成 `GeneratedPluginRegistrant.ets`，不会自动注册模块）。
下面的路径以「插件放在工程 `packages/sharesdk_plugin` 下」为例，用 git 依赖时改成 pub-cache 中的实际路径即可。

**1. `ohos/oh-package.json5`**

```json5
{
  "dependencies": {
    "sharesdk_plugin": "file:../packages/sharesdk_plugin/ohos"
  },
  // 必须：插件里 @ohos/flutter_ohos 声明的是相对自身目录的默认路径，
  // 这里用 overrides 指向工程内真实的 flutter.har，overrides 会覆盖插件的声明（即使插件里那个路径不存在）
  "overrides": {
    "@ohos/flutter_ohos": "file:./har/flutter.har"
  }
}
```

**2. `ohos/entry/oh-package.json5`**

```json5
{
  "dependencies": {
    "sharesdk_plugin": "file:../../packages/sharesdk_plugin/ohos"
  }
}
```

**3. `ohos/build-profile.json5`** 的 `modules` 数组中追加：

```json5
{
  "name": "sharesdk_plugin",
  "srcPath": "../packages/sharesdk_plugin/ohos",
  "targets": [
    { "name": "default", "applyToProducts": ["default"] }
  ]
}
```

#### 三、EntryAbility 中初始化

插件本身不内置任何 Mob 凭据，appKey / appSecret 由宿主 App 传入：

```typescript
import { SharesdkPlugin } from 'sharesdk_plugin';

export default class EntryAbility extends FlutterAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    SharesdkPlugin.setUIAbilityContext(this.context, '你的MobAppKey', '你的MobAppSecret');
    SharesdkPlugin.handleWant(want, this.context);
    super.onCreate(want, launchParam);
  }

  // 第三方 App 授权/分享后会以 newWant 回到本 Ability，必须转交给插件处理回调
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    SharesdkPlugin.handleWant(want, this.context);
    super.onNewWant(want, launchParam);
  }
}
```

若不方便在 EntryAbility 传凭据，也可以在 Dart 侧调用
`SharesdkPlugin.uploadPrivacyPermissionStatus(1, cb, appKey: ..., appSecret: ...)` 时传入，插件会在那时完成初始化。
两处都不传会抛出提示信息明确的异常。

#### 四、`ohos/entry/src/main/module.json5`

```json5
{
  "module": {
    // isClientInstalled 需要用 canOpenLink 探测微信/QQ 是否安装
    "querySchemes": ["weixin", "mqqapi", "qqopenapi", "https"],
    // 网页分享缩略图需要联网下载并压缩
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

#### 五、Dart 侧用法

与 Android / iOS 完全一致，平台参数信息用字符串 key 的 map 下发：

```dart
SharesdkRegister register = SharesdkRegister();
register.setupWechat('微信AppID', '微信AppSecret', ''); // 第三参为 iOS UniversalLink，鸿蒙忽略
register.setupQQ('QQAppID', 'QQAppKey');
SharesdkPlugin.regist(register);

// Release 包在调用 isClientInstalled / 分享前需先提交隐私授权
await SharesdkPlugin.uploadPrivacyPermissionStatus(1, (bool success) {},
    appKey: '你的MobAppKey', appSecret: '你的MobAppSecret');
```

#### 六、获取鸿蒙签名指纹（配置 QQ 互联用）

腾讯开放平台配置鸿蒙应用需要填写签名指纹的 MD5，可用插件内置方法取得：

```dart
final info = await SharesdkPlugin.getBundleSignatureFingerprint();
// { 'fingerprint': '...', 'fingerprintMd5': '...', 'bundleName': '...' }
```

#### 已知差异

- 鸿蒙侧 `getUserInfo` / `auth` 成功时，用户信息放在 `user['raw']` 中（ShareSDK 的 `db.exportData()` 原始内容），与 Android / iOS 的字段结构不同，业务侧需自行解析。
- 微信网页分享的缩略图会由插件下载并压缩到 64KB 以内（微信 `thumbData` 限制），因此需要 `ohos.permission.INTERNET`。
- `targetFilePath` 只回传文件名，实际落盘路径由业务方自行处理。

## 接口方法说明
接口详情：[API接口调用](https://www.mob.com/wiki/detailed?wiki=31&id=14)

## 技术支持
如有问题请联系技术支持:

```
服务电话:   400-685-2216
QQ:        4006852216
节假日值班电话:
    iOS：185-1664-1951
Android: 185-1664-1950
电子邮箱:   support@mob.com
市场合作:   021-54623100
```