import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 设备信息与 device_id 占位（规约：正式由 NATIVE_BRIDGE 提供 SHA-256(Android ID) / iOS 标识）
class DeviceInfoService {
  static final _deviceInfo = DeviceInfoPlugin();

  /// 占位 device_id，正式实现由原生桥接返回
  static Future<String> getDeviceId() async {
    // TODO: 通过 NATIVE_BRIDGE fetchSensitiveData 或专用方法获取
    if (kDebugMode) {
      if (Platform.isAndroid) {
        final a = await _deviceInfo.androidInfo;
        return 'placeholder_android_${a.id.hashCode.abs()}';
      }
      if (Platform.isIOS) {
        final i = await _deviceInfo.iosInfo;
        return 'placeholder_ios_${i.identifierForVendor ?? "unknown"}';
      }
    }
    return 'placeholder_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// device_info 用于 enroll（model, os, app_version）
  static Future<Map<String, String>> getDeviceInfoMap() async {
    String model = 'unknown';
    String os = 'unknown';
    if (Platform.isAndroid) {
      final a = await _deviceInfo.androidInfo;
      model = a.model;
      os = 'Android ${a.version.release}';
    } else if (Platform.isIOS) {
      final i = await _deviceInfo.iosInfo;
      model = i.model;
      os = 'iOS ${i.systemVersion}';
    }
    String appVersion = '1.0.0';
    try {
      final p = await PackageInfo.fromPlatform();
      appVersion = '${p.version}.${p.buildNumber}';
    } catch (_) {}
    return {'model': model, 'os': os, 'app_version': appVersion};
  }
}
