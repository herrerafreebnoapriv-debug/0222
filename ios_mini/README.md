# MOP iOS Mini

与主工程 `app` 功能一致的 **iOS 专用** 用户端，从依赖上**不包含 Jitsi**，避免 Jitsi 框架在 iOS 上的启动崩溃。

## 与 app 的区别

- **pubspec**：无 `jitsi_meet_flutter_sdk` 依赖。
- **音视频入口**：`/jitsi_join` 路由仍存在，但页面为占位，提示“音视频/会议功能下阶段在 iOS 开放”。
- **构建产物**：仅产出 iOS IPA，无 Android 构建。

## 本地构建

```bash
cd ios_mini
flutter pub get
flutter build ios --release --no-codesign --build-name=1.0.0 --build-number=1
# 签名与归档见 .github/workflows/ios-mini-build.yml
```

## CI

推送或手动触发 `.github/workflows/ios-mini-build.yml`，产物为 `ios-mini-ipa-<run_number>`。
