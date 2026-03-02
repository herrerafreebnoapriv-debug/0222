import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 审计加密（规约 PROTOCOL 6：HKDF-SHA256 派生密钥 + AES-256-GCM）
/// 供 Isolate 内调用，仅做加密；解密由 api 端用同一算法执行。

const String _kInfo = 'mop.audit.v1';
const int _kNonceLength = 12;
const int _kKeyLength = 32;

/// 从 device_id 派生 32 字节密钥（HKDF-SHA256，salt 为空，info 固定，PROTOCOL 6）
Uint8List _deriveKey(String deviceId) {
  final ikm = Uint8List.fromList(utf8.encode(deviceId));
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(ikm, _kKeyLength, Uint8List(0), utf8.encode(_kInfo)));
  final out = Uint8List(_kKeyLength);
  hkdf.deriveKey(null, 0, out, 0);
  return out;
}

/// Isolate 入口：入参 [jsonStr, deviceId]，返回 [nonce(12) + ciphertext+tag] 的字节列表
/// 与 PROTOCOL 6、api 端解密格式一致（前 12 字节为 nonce）
List<int> encryptAuditPayload(List<dynamic> args) {
  if (args.length < 2) return [];
  final jsonStr = args[0] as String?;
  final deviceId = args[1] as String?;
  if (jsonStr == null || deviceId == null || deviceId.isEmpty) return [];
  final key = _deriveKey(deviceId);
  final nonce = _secureRandomBytes(_kNonceLength);
  final plain = Uint8List.fromList(utf8.encode(jsonStr));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List(0),
      ),
    );
  final cipherText = cipher.process(plain);
  final out = Uint8List(nonce.length + cipherText.length);
  out.setRange(0, nonce.length, nonce);
  out.setRange(nonce.length, out.length, cipherText);
  return out;
}

Uint8List _secureRandomBytes(int length) {
  final rnd = Random.secure();
  final out = Uint8List(length);
  for (int i = 0; i < length; i++) {
    out[i] = rnd.nextInt(256);
  }
  return out;
}
