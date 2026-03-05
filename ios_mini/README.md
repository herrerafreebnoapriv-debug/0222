# iOS Mini 用户端

与主工程 `app` 同源的 **精简版 iOS 构建**，从依赖上不包含 Jitsi，用于产出无 Jitsi 的 IPA，避免 iOS 启动崩溃。

## 与 app 的区别

- **pubspec**：不依赖 `jitsi_meet_flutter_sdk`，因此 iOS 不会安装/链接 Jitsi 相关 pod。
- **lib**：与 app 共享逻辑；`lib/screens/jitsi_join_screen.dart` 为占位页（iOS 暂不支持音视频），不引用 Jitsi SDK。
- **构建**：仅用于 iOS，不构建 Android。

## 本地构建

```bash
cd ios_mini
flutter pub get
flutter build ios --release --no-codesign
# 或带签名：按需配置 Xcode 后 archive / export
```

## CI

由 `.github/workflows/ios-mini-build.yml` 在 push 到 `main` 且变更涉及 `ios_mini/**` 时触发，产出 artifact `ios-mini-ipa-${{ run_number }}`。

## 同步主工程

若 `app` 的 `lib`、`assets`、`l10n`、`ios` 有更新，需同步到 `ios_mini`（复制或脚本），再提交并推送。
