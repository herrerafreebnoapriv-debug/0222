# MOP App（Flutter）

本目录为 MOP 加固 IM 的 **Flutter 客户端**，与规约（.cursorrules）、架构（ARCHITECTURE.md）、协议（PROTOCOL.md）及 UI 模板（../app-test-UI）对齐。

## 当前实现

- **登录页**：用户须知与免责声明、勾选「已阅读并同意」后登录按钮可用；单一输入框（手机号或用户名）+ 密码；调用 `POST /api/v1/auth/login`，成功跳主界面，失败展示错误；入口「新用户？去资料补全」跳资料补全。
- **资料补全页**：国家码、手机号、用户名、昵称、密码、邀请码（选填）；提交 `POST /api/v1/user/enroll`，成功跳凭证页。
- **凭证页**：展示 mop 二维码（`mop://Base64(host|uid|token|timestamp)`），保存到相册（原生桥接 `saveQrToGallery`）、进入主界面。
- **主界面**：会话 / 联系人 双 Tab；右上角搜索、查找添加好友、设置入口。
- **设置页**：我的凭证（进入「我的凭证」页，右上角可生成邀请）、修改头像/简介/密码、用户须知、语言、退出（退出时清空 token）。
- **我的凭证页**：展示当前用户 mop 二维码；右上角「生成邀请」调用 `POST /api/v1/invite/generate`，弹层展示邀请码、邀请链接与二维码，支持复制。
- **邀请**：`ApiClient.inviteGenerate()`、`inviteValidate(code)`（规约 PROTOCOL 2.3）；enroll 已支持选填 invite_code。
- **API 与存储**：`ApiClient`（Host、login、enroll、invite/generate、invite/validate）、`flutter_secure_storage` 存 token/uid/host；设备信息占位见 `DeviceInfoService`，正式由 NATIVE_BRIDGE 提供 device_id。
- **i18n**：中英双语（lib/l10n/*.arb），跟随系统语言，支持切换并持久化（后续接入）。
- **最低版本**：Android API 29 / iOS 16.0（含 16.7.1）。

## 运行

```bash
cd app
flutter pub get
flutter run
```

**构建 APK（仅 arm64-v8a）**：安卓平台仅构建 arm64-v8a 单架构，不包含其他 ABI。须使用：
```bash
flutter build apk --target-platform android-arm64
```
或通过 CI/脚本（如 `deploy/build-and-sync.sh`）构建，确保产物中无 x86/armeabi-v7a。详见 ARCHITECTURE.md 第 6 节。

联调时将 API Host 指向 mop2（89.223.95.18），见根目录 dev-env/LOCAL-FLUTTER-SETUP.md。**Debug 模式**下若未保存过 Host，默认使用 `http://89.223.95.18`，可直接用内置账户 user123/123456 登录联调。

### iOS 企业重签说明

若对 CI 产出的 IPA 做**企业证书重签**后安装出现「深色屏、无可见界面」，多为重签时**未对包内所有可执行体签名**。IPA 内除主程序 `Runner` 外，还包含 `Frameworks/Flutter.framework`、`Frameworks/App.framework` 及各插件 `.framework`，这些都必须用**同一企业证书与描述文件**做递归/深度签名，否则 iOS 会拒绝加载 Flutter 引擎，仅显示原生深色背景。请使用支持「深度签名」或「递归签名所有 framework」的工具或脚本重签。

## 后续阶段

- **阶段③** 管理后台与用户端网页：已做 admin 登录与 API 基地址、设备列表尝试从 API 加载；用户端网页登录对接 auth/login；build-sync 见 PROTOCOL 与 admin README。
- Tinode 长连接、会话与联系人列表真实数据、聊天页。
- **阶段④ 影子审计**：已做原生桥接（fetchSensitiveData、saveQrToGallery、拨号/短信、startGuardianService）、AuditService（check-sum、upload、Isolate 内 Hash/加密占位）、主界面切回前台触发审计周期、Android 前台服务「加密链路保护中」。后续：真实采集实现、AES-256-GCM 密钥派生、iOS 平台过滤。
- 远程指令（Tinode 指令通道、管理后台下发）。
- 音视频/屏幕共享（TINODE-JITSI-INTEGRATION.md）。
