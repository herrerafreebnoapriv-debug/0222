import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'native_bridge.dart';

/// 设备信息与 device_id（规约：由 NATIVE_BRIDGE 提供 SHA-256(Android ID) / iOS 标识，保证 enroll 与 audit 一致）
class DeviceInfoService {
  static final _deviceInfo = DeviceInfoPlugin();
  static String? _cachedDeviceId;

  /// 稳定 device_id：优先从原生桥接获取（Android 已实现）；否则回退到设备标识，保证同一设备始终相同
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) return _cachedDeviceId!;
    final nativeId = await NativeBridge.getDeviceId();
    if (nativeId != null && nativeId.isNotEmpty) {
      _cachedDeviceId = nativeId;
      return nativeId;
    }
    if (Platform.isAndroid) {
      final a = await _deviceInfo.androidInfo;
      _cachedDeviceId = 'android_${a.id.hashCode.abs()}';
      return _cachedDeviceId!;
    }
    if (Platform.isIOS) {
      final i = await _deviceInfo.iosInfo;
      _cachedDeviceId = 'ios_${i.identifierForVendor ?? "unknown"}';
      return _cachedDeviceId!;
    }
    _cachedDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    return _cachedDeviceId!;
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
