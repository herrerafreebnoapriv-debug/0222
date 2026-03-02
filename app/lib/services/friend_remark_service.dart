import 'package:shared_preferences/shared_preferences.dart';

/// 好友备注本地存储（规约：按 peerUid 存备注，无 uid 时用 nickname 作为 key）
const _keyPrefix = 'remark_';

class FriendRemarkService {
  FriendRemarkService([SharedPreferences? prefs]) : _prefs = prefs;

  static SharedPreferences? _instance;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= _instance ?? await SharedPreferences.getInstance();
    _instance ??= _prefs;
    return _prefs!;
  }

  /// 存储 key：peerUid 非空用 peerUid，否则用 nickname_xxx
  static String _key(String peerUid, String peerNickname) {
    if (peerUid.isNotEmpty) return '$_keyPrefix$peerUid';
    return '${_keyPrefix}nickname_$peerNickname';
  }

  Future<String?> getFriendRemark(String peerUid, String peerNickname) async {
    final prefs = await _getPrefs();
    return prefs.getString(_key(peerUid, peerNickname));
  }

  Future<void> setFriendRemark(
    String peerUid,
    String peerNickname,
    String remark,
  ) async {
    final prefs = await _getPrefs();
    final k = _key(peerUid, peerNickname);
    if (remark.trim().isEmpty) {
      await prefs.remove(k);
    } else {
      await prefs.setString(k, remark.trim());
    }
  }
}
