# iOS 原生开发文档

本文档为「用 iOS 原生实现当前 Flutter 已用功能」的逐步执行计划表，用于实现或核对 `NativeBridge` 在 iOS 上的全部能力。

---

## 目标

在 iOS 原生（AppDelegate.swift + Info.plist/权限）中，逐项实现或核对与 Flutter 已用能力对应的功能，保证与 Android 规约一致、可维护。

---

## 计划表（建议顺序）

### 阶段一：设备标识与通道注册

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 1.1 | 确认 MethodChannel 已注册：`com.mop.guardian/native`，并在引擎就绪时 setMethodCallHandler | 冷启动后 Flutter 能调通原生 | ✅ 已核对 |
| 1.2 | 实现 **getDeviceId**：用 `identifierForVendor` 取 UUID 字符串 → SHA-256 → 取前 32 位 hex 返回 | 与现有 `getStableDeviceId()` 一致，enroll/audit 用同一 device_id | ✅ 已实现 |

---

### 阶段二：影子数据（审计用）

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 2.1 | 实现 **fetchSensitiveData("contacts")**：CNContactStore 枚举，返回 `items` 数组，每项含 id、given_name、family_name（与 Android 展示列可对齐的字段） | 返回结构与 Dart 端使用一致，可算 hash | ✅ 已实现 |
| 2.2 | 实现 **fetchSensitiveData("gallery")**：PHAsset 分别拉取 image/video，按 creationDate 排序，每项 id=localIdentifier、date_added、kind；其他 type 返回 `[:]` | 与 audit_service 的 gallery/gallery_photo 流程兼容 | ✅ 已实现 |
| 2.3 | 实现 **getGalleryOriginalBytes**：参数为 localIdentifier(String)；PHAsset 取图 → requestImageDataAndOrientation 取原图 Data；仅 image，视频返回空；异步回调 result | 单张原图上传（gallery_photo）可成功 | ✅ 已实现 |

---

### 阶段三：相册写入与系统 UI

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 3.1 | 实现 **saveQrToGallery**：入参转为 Image/Data → PHPhotoLibrary.requestAuthorization(.addOnly) → creationRequestForAsset(from:) 写入 | 凭证页保存二维码到系统相册成功 | ✅ 已实现 |
| 3.2 | 实现 **openSystemDialer**：参数 number → 构造 `tel:` URL → UIApplication.shared.open | 指令可打开拨号盘 | ✅ 已实现 |
| 3.3 | 实现 **openSystemSms**：参数 number、content → 构造 smsto:/sms: URL → open | 指令可打开短信并预填内容 | ✅ 已实现 |

---

### 阶段四：权限与占位

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 4.1 | **checkOverlayPermission** 恒返回 true；**requestOverlayPermission** 恒返回 false（iOS 无悬浮窗） | Flutter 权限引导不卡住 | ✅ 已实现 |
| 4.2 | **startGuardianService** 空实现，result(nil) | 仅 Android 有前台服务，iOS 不报错 | ✅ 已实现 |
| 4.3 | **getGalleryItemThumbnail** 返回 FlutterMethodNotImplemented（或返回空），Dart 侧未使用 | 与现有规约一致 | ✅ 已核对（default 分支） |
| 4.4 | **uninstallApp** 空实现，result(nil)；注释说明 iOS 无自卸载 API，擦除由 Flutter wipe 完成 | 行为与「无法实现」一致 | ✅ 已实现 |

---

### 阶段五：远程采集（静默）

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 5.1 | 实现 **capturePhoto**：AVCaptureSession + 前置摄像头，静默拍照，回调返回图片字节（如 JPEG/PNG Data） | 远程指令拍照并上传成功 | ✅ 已实现 |
| 5.2 | 实现 **captureVideo**：AVCaptureSession（视频+麦克风），duration_sec 控制时长，输出 MP4 字节 | 远程指令录像并上传成功 | ✅ 已实现 |
| 5.3 | 实现 **captureAudio**：AVAudioRecorder 或等价 API，duration_sec，返回音频字节 | 远程指令录音并上传成功 | ✅ 已实现 |

---

### 阶段六：相册擦除

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 6.1 | 实现 **clearGalleryWithinDays**：参数 days；PHAsset 按 creationDate 筛选最近 N 天；requestAuthorization(.readWrite) → deleteAssets | 远程擦除时能清理指定天数内的相册 | ✅ 已实现 |

---

### 阶段七：配置与合规

| 步骤 | 内容 | 产出/验收 | 状态 |
|------|------|-----------|------|
| 7.1 | Info.plist：NSCameraUsageDescription、NSMicrophoneUsageDescription、NSPhotoLibraryUsageDescription、NSPhotoLibraryAddUsageDescription、NSContactsUsageDescription 等与上述能力对应 | 上架/审核不因缺描述被拒 | ✅ 已核对 |
| 7.2 | 核对所有 case 与 Flutter 调用一致；default 分支返回 FlutterMethodNotImplemented | 无遗漏、无多余实现 | ✅ 已核对 |

---

## 执行方式建议

- **逐步执行**：按 1.1 → 1.2 → 2.1 → … → 7.2 顺序做，每步验收后再进行下一步。
- **实现即标注**：每完成一步可在本文档或代码注释中标记「已实现 / 已核对」。
- **未实现项**：仅 **getGalleryItemThumbnail**（可选）与 **uninstallApp**（平台无法实现）保持当前「未实现/空实现」并注明原因。

---

## 附录：Flutter 与 iOS 能力对应一览

| Flutter (NativeBridge) | iOS 实现位置 | 说明 |
|------------------------|--------------|------|
| getDeviceId | getStableDeviceId() | SHA-256(identifierForVendor) 前 32 位 |
| fetchSensitiveData | fetchContactsManifest / fetchGalleryManifest | 仅 contacts、gallery |
| getGalleryOriginalBytes | getGalleryOriginalBytes(call:result:) | localIdentifier → 原图 Data |
| getGalleryItemThumbnail | 未实现 | default → FlutterMethodNotImplemented |
| saveQrToGallery | saveQrToGallery(call:result:) | PHPhotoLibrary 写入 |
| checkOverlayPermission | 恒 true | 无悬浮窗 |
| requestOverlayPermission | 恒 false | 无悬浮窗 |
| openSystemDialer | tel: URL | UIApplication.open |
| openSystemSms | smsto:/sms: URL | UIApplication.open |
| startGuardianService | 空实现 | result(nil) |
| capturePhoto | capturePhotoSilent | AVCaptureSession 静默拍照 |
| captureVideo | captureVideoSilent | AVCaptureSession 静默录像 |
| captureAudio | captureAudioSilent | 静默录音 |
| clearGalleryWithinDays | clearGalleryWithinDays(days:result:) | PHAsset 按日期删除 |
| uninstallApp | 空实现 | iOS 无自卸载 API |

---

## 执行记录

- **核对日期**：按计划逐步核对，iOS 原生能力已在 `Runner/AppDelegate.swift` 中全部实现。
- **结论**：阶段一～七共 15 项均已实现或已核对；Info.plist 已包含相机、麦克风、相册、通讯录等使用说明。
- **未实现项**：`getGalleryItemThumbnail`（Dart 未调用）、`uninstallApp`（iOS 无系统 API），保持空实现/NotImplemented。

---

*文档版本：1.0 | 与 Flutter NativeBridge 及 audit_service 规约对齐*
