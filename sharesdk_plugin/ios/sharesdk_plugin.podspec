#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'sharesdk_plugin'
  s.version          = '1.1.8'
  s.summary          = 'Flutter plugin for ShareSDK.'
  s.description      = <<-DESC
  ShareSDK is the most comprehensive Social SDK in the world,which share easily with 40+ platforms.
                       DESC
  s.homepage         = 'http://www.mob.com/mobService/sharesdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Mob' => 'mobproduct@mob.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'mob_sharesdk'
  s.dependency 'mob_sharesdk/ShareSDKExtension'
  s.dependency 'mob_sharesdk/ShareSDKUI'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/XHS'
  # 平台 SDK 默认不引入 iOS 包：
  #   1) 笔笔记账 iOS 版隐藏了第三方登录与微信/QQ 分享，分享走系统面板（share_plus），
  #      这两个静态库进包只是死代码，还要额外声明 URL Scheme 与隐私用途；
  #   2) libWeChatSDK.a 的 arm64 是**真机**切片（armv7 i386 x86_64 arm64），
  #      没有 arm64-simulator，链到模拟器上会报
  #      "Building for 'iOS-simulator', but linking in object file built for 'iOS'"，
  #      Xcode 26 又去掉了 Rosetta 模拟器，导致 iOS 模拟器整个用不了。
  # 需要微信/QQ 通道的项目把下面两行放开即可（Android / 鸿蒙不受本文件影响）。
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/QQ'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/SinaWeibo'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/WeChat'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Facebook'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Twitter'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Oasis'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Line'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/SnapChat'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/WatermelonVideo'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/KuaiShou'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Douyin'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/TikTok'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Line'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Instagram'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Messenger'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/WhatsApp'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/GooglePlus'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/LinkedIn'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/VKontakte'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Telegram'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Reddit'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Pocket'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Flickr'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Dropbox'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Pinterest'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Reddit'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Instapaper'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/DingTalk'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/YouDaoNote'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/MingDao'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Evernote'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/Yixin'
  s.dependency 'mob_sharesdk/ShareSDKPlatforms/SMS'
  # s.dependency 'mob_sharesdk/ShareSDKPlatforms/WeWork'

  s.static_framework = true

  s.ios.deployment_target = '8.0'
end

