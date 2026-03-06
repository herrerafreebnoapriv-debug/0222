# ios_mini — iOS 精简版用户端

本目录为**仅面向 iOS 的精简 Flutter 工程**，与主工程 `app` 功能一致，但**不包含任何第三方音视频会议 SDK**，从依赖层面避免 iOS 启动崩溃。

## 与 app 的区别

- **app**：主工程，含音视频会议依赖，用于 Android / 全平台构建。
- **ios_mini**：无音视频会议相关依赖，仅用于打 **iOS 包**，IPA 体积更小、无会议框架。

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
