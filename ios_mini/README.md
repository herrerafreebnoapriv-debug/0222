# ios_mini — iOS 精简版用户端

本目录为**仅面向 iOS 的精简 Flutter 工程**，与主工程 `app` 功能一致，但**不依赖 Jitsi**，从依赖层面彻底避免 iOS 启动崩溃。

## 与 app 的区别

- **app**：主工程，含 `jitsi_meet_flutter_sdk`，用于 Android / 全平台构建。
- **ios_mini**：无 `jitsi_meet_flutter_sdk`，仅用于打 **iOS 包**，IPA 内不包含 JitsiMeetSDK、WebRTC、GiphyUISDK 等。

## 构建

在项目根目录下：

```bash
cd ios_mini
flutter pub get
flutter build ios --release --no-codesign
# 或带签名：按需配置证书后 archive / export
```

## CI

单独 workflow：`.github/workflows/ios-mini-build.yml`，推送或手动触发后产出 iOS Mini 版 IPA 产物。
