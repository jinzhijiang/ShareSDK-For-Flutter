

# ShareSDK-For-Flutter

本仓库 fork 自 [MobClub/ShareSDK-For-Flutter](https://github.com/MobClub/ShareSDK-For-Flutter)，
在官方 Android / iOS 实现的基础上**增加了鸿蒙 HarmonyOS NEXT 支持**，方便在鸿蒙化的 Flutter 工程中直接引用。

## 与上游的差异

- 新增 `sharesdk_plugin/ohos/`：ArkTS 实现的鸿蒙插件模块，支持微信、QQ、华为帐号的授权 / 分享 / 用户信息 / 小程序等能力
- 新增 `SharesdkPlugin.getBundleSignatureFingerprint()`：获取鸿蒙应用签名 fingerprint 及 MD5（配置 QQ 互联需要）
- `uploadPrivacyPermissionStatus` 支持传入 `appKey` / `appSecret`
- Android：移除已下线的 `jcenter()` 与 AGP 3.6 buildscript，改用 `namespace` / `compileSdk 34`
- iOS：`podspec` 默认仅保留 WeChat / QQ / SMS，其余平台依赖已注释，按需自行放开

## 使用

```yaml
dependencies:
  sharesdk_plugin:
    git:
      url: https://github.com/jinzhijiang/ShareSDK-For-Flutter.git
      path: sharesdk_plugin
```

鸿蒙工程的完整接入步骤（`oh-package.json5` / `build-profile.json5` 注册、EntryAbility 初始化、权限与
`querySchemes` 配置）见 [sharesdk_plugin/README.md](sharesdk_plugin/README.md#鸿蒙-harmonyos-next)。

上游官方插件（不含鸿蒙）：[pub.dev/packages/sharesdk_plugin](https://pub.dartlang.org/packages/sharesdk_plugin)
