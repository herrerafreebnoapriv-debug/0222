# ios_mini — iOS 精简版用户端

**仅面向 iOS** 的 Flutter 工程，与主工程 `app` 业务一致，但不包含任何第三方音视频会议 SDK，用于单独产出 iOS IPA，避免因会议框架导致的启动问题并减小包体。

---

## 1. 与主工程 app 的关系

| 项目    | 平台       | 音视频/会议 SDK | 用途           |
|---------|------------|------------------|----------------|
| **app** | Android 等 | 含               | 主工程全功能包 |
| **ios_mini** | 仅 iOS | 无               | iOS 专用精简包 |

二者共享规约（MOP 加固、用户须知、i18n、影子审计等），ios_mini 不包含 Jitsi 等会议依赖；音视频入口为占位页，提示“下阶段开放”。

---

## 2. 技术栈与依赖

- **Flutter**，Dart 3.11+
- **多语言**：`flutter_localizations` + `lib/l10n`（arb），中英，默认跟随系统，可设置页切换并持久化。
- **无**：WebRTC、Jitsi、WebView 会议等；仅基础库：`http`、`qr_flutter`、`flutter_secure_storage`、`permission_handler`、`geolocator`/`geocoding`、`image_picker` 等。见 `pubspec.yaml`。

---

## 3. 目录与模块结构

```
ios_mini/
├── lib/
│   ├── main.dart                 # 入口、路由、启动门、语言持久化
│   ├── core/                     # API、主题、语言 Scope、设备信息、原生桥接
│   ├── l10n/                     # app_zh.arb / app_en.arb 及生成代码
│   ├── screens/                  # 各页
│   ├── services/                 # 审计、指令、好友备注、消息存储等
│   └── utils/                    # 权限引导、国家码等
├── assets/images/                # 应用图标、可选在线授课背景图
├── ios/                          # Runner、签名脚本等
├── pubspec.yaml
├── l10n.yaml                     # 多语言生成配置（template: app_zh.arb）
└── README.md                     # 本文档
```

**路由要点**：`/` 启动门 → `/login` 或 `/main`；登录、激活、资料补全、凭证、主界面（会话/联系人/在线授课）、聊天、设置、音视频占位等。音视频入口为 `VoiceVideoPlaceholderScreen`（`/voice_video_join`）。

---

## 4. 功能与规约符合

- **登录/注册**：账密登录；用户须知 + 勾选「已阅读并同意」后登录可用；同意状态持久化。
- **权限**：进入主界面前需授予 **相册、通讯录**（iOS 仅此二者，无悬浮窗、无短信/通话记录引导）。
- **i18n**：中英，设置页可切换语言并写本地存储。
- **原生桥接**：Channel `com.mop.guardian/native`，iOS 上悬浮窗相关为空实现；设备 ID、相册、拨号/短信等见 `core/native_bridge.dart`。

---

## 5. 构建与运行

```bash
cd ios_mini
flutter pub get
flutter gen-l10n   # 若修改了 arb，需生成
flutter run        # 调试
# Release（无签名）
flutter build ios --release --no-codesign
# 带签名：Xcode 打开 ios/Runner.xcworkspace，配置证书后 Archive / Export
```

版本号与 build 号在 `pubspec.yaml` 的 `version`（如 `1.0.6+7`）中维护。

---

## 6. 配置与资源

- **版本**：`pubspec.yaml` → `version: x.y.z+build`。
- **图标**：`flutter_launcher_icons` 仅配置 iOS，图源 `assets/images/app_icon.png`。
- **资源**：`assets/images/`；可选 `online_teaching_bg.png` 作为在线授课 Tab 背景，缺失则使用默认渐变。
- **多语言**：`lib/l10n/app_zh.arb`、`app_en.arb`，生成到 `lib/l10n/app_localizations*.dart`。

---

## 7. CI

单独流水线：`.github/workflows/ios-mini-build.yml`，推送或手动触发后产出 iOS Mini 版 IPA。

---

## 8. 其他说明

- 本文档与项目规约（如 `.cursorrules`、ARCHITECTURE.md）一致；注释与文案使用简体中文。
- 单文件建议控制在约 300～400 行内，超出可拆子组件或抽逻辑。
