# ios_mini — MOP iOS Mini 用户端

本目录为 **仅面向 iOS 的精简 Flutter 工程**，与主工程 `app` 分离，从依赖层面**不包含 Jitsi**，用于产出无 Jitsi 的 iOS IPA，避免主工程在 iOS 上因 Jitsi 框架加载导致的启动崩溃。

## 与 app 的区别

| 项目       | app（主工程）     | ios_mini              |
|------------|-------------------|------------------------|
| 平台       | Android / iOS 等  | 仅 iOS                 |
| Jitsi      | 依赖 jitsi_meet_flutter_sdk | **无**，不依赖、不链接 |
| 用途       | 全功能、含音视频  | 仅 IM 等，音视频为占位 |
| 构建产物   | 各平台包          | 仅 iOS IPA（Mini 版）  |

## 本地构建

```bash
cd ios_mini
flutter pub get
flutter build ios --release --no-codesign
# 或签名后：flutter build ipa
```

## CI

由 `.github/workflows/ios-mini-build.yml` 在 push 到 `main` 且变更 `ios_mini/**` 时自动构建，产物为 Artifact `ios-mini-ipa-{run_number}`。

## 代码同步

`lib/`、`assets/`、`ios/` 自 `app` 拷贝后，仅对 `lib/screens/jitsi_join_screen.dart` 做了占位替换（无 Jitsi 依赖）。若主工程业务有更新，需酌情从 `app` 同步到 `ios_mini`（除 Jitsi 相关外）。
