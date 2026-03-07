# MOi Native（纯原生 iOS）

与 `app/`（Flutter）并列的**可选**纯原生 iOS 项目，遵循 [app/ios/IOS_NATIVE_DEVELOPMENT.md](../app/ios/IOS_NATIVE_DEVELOPMENT.md) 中的「纯原生 iOS 方案（可选）」分阶段推进。

- **阶段 0**：本目录为独立 Xcode 工程，不修改 `app/ios`，可单独构建与安装。
- **Bundle ID**：`app.suyun9289.test.native`（与 Flutter Runner 区分）。
- **最低部署**：iOS 16.0。

## 开发与构建方式

- **开发**：在本机 **Windows 10** 使用 **Cursor** 编写/修改代码，无需 Mac 或 Xcode 本地安装。
- **构建 IPA**：将代码**推送到 GitHub** 后，由 **GitHub Actions** 在 macOS 上完成编译、签名与导出 IPA。
- **Workflow**： [`.github/workflows/ios-native-build.yml`](../.github/workflows/ios-native-build.yml)  
  - 触发：`main` 分支 push 且 `app-ios-native/**` 或该 workflow 文件有变更，或仓库内手动 **Run workflow**。
  - 产物：Artifact `ios-native-ipa-<run_number>`，在 Actions 运行页下载 IPA。
- **签名**：与 Flutter iOS 共用仓库 Secrets（`IOS0222`、`BUILD_PROVISION_PROFILE_BASE64`、`P12_PASSWORD`、`KEYCHAIN_PASSWORD`）。  
  描述文件需包含 Bundle ID **app.suyun9289.test.native**（可与 Flutter 用同一 Ad-hoc 描述文件，只要其包含该 App ID）。

## 本地构建（可选，需 Mac/Xcode）

在 Xcode 中打开 `MOiNative.xcodeproj`，选择目标设备或模拟器后 Build / Run。或命令行：

```bash
cd app-ios-native
xcodebuild -scheme MOiNative -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 后续阶段

- ~~阶段 1~~：登录 + 主界面占位 + 后端登录接口（已实现）
- ~~阶段 2~~：迁入设备 ID、通讯录/相册/原图/擦除/保存二维码、静默拍照/录像/录音、拨号/短信（已实现）
- ~~阶段 3~~：主屏（Tab：首页/设置/凭证）、审计周期、指令轮询、设置登出、凭证 QR 与保存相册（已实现：`AuditApi`/`AuditService`/`AuditCrypto`、`CommandsApi`/`CommandExecutor`/`CommandPoller`、`MainTabController`、`CredentialHelper`）
- ~~阶段 4~~：多语言与合规（已实现：`L10n`、`Localizable.strings` 中英、登录页用户须知+勾选+持久化、`ConfigApi` 须知版本、主屏再次征意、设置页语言切换）
