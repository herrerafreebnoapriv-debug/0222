# ios_mini — iOS 用户端精简版（无 Jitsi）

本目录为**仅用于 iOS 构建**的 Flutter 工程，与主工程 `app` 功能一致，但**不依赖** `jitsi_meet_flutter_sdk`，从依赖层面彻底避免 Jitsi 相关 framework 打入 IPA，解决 iOS 启动闪退问题。

## 与 app 的区别

| 项目     | app（主工程）     | ios_mini（本工程）   |
|----------|--------------------|----------------------|
| 平台     | Android / iOS 等   | 仅 iOS               |
| Jitsi    | 依赖并集成         | 不依赖，无 Jitsi pod |
| 音视频   | Android 可进 Jitsi | iOS 仅提示“暂不支持” |

## 构建方式

```bash
cd ios_mini
flutter pub get
flutter build ios --release --no-codesign
# 或使用 xcodebuild archive / 导出 IPA
```

CI 使用 `.github/workflows/ios-mini-build.yml` 单独构建并产出 iOS 精简版 IPA。

## 维护说明

- `lib/` 与主工程 `app/lib` 保持功能同步，仅 `screens/jitsi_join_screen.dart` 为占位页（不调用 Jitsi）。
- 依赖以 `pubspec.yaml` 为准，与 app 一致但**不含** `jitsi_meet_flutter_sdk`。
