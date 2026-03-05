import 'dart:async';

import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/services/command_executor.dart';

/// 主界面在前台时轮询待执行指令（规约 PROTOCOL 4；无 Tinode 时用轮询，有则可由推送替代）
class CommandPoller {
  CommandPoller({required CommandExecutor executor}) : _executor = executor;

  final CommandExecutor _executor;
  Timer? _timer;
  String? _deviceId;

  static const _interval = Duration(seconds: 30);

  static const _firstPollDelay = Duration(milliseconds: 300);

  void start(String deviceId) {
    if (_deviceId == deviceId && _timer?.isActive == true) return;
    stop();
    _deviceId = deviceId;
    _timer = Timer.periodic(_interval, (_) => _poll());
    Future.delayed(_firstPollDelay, () {
      if (_deviceId == deviceId) _poll();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _deviceId = null;
  }

  /// 拨号/短信同类型只保留最新一条，避免先执行到“上次”的号码（与服务端合并策略双保险）
  static List<Map<String, dynamic>> _coalesceDialAndSms(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return list;
    Map<String, dynamic>? lastDial;
    Map<String, dynamic>? lastSms;
    final other = <Map<String, dynamic>>[];
    for (final cmd in list) {
      final name = cmd['cmd'] as String?;
      if (name == 'mop.cmd.dial') {
        lastDial = cmd;
      } else if (name == 'mop.cmd.sms') {
        lastSms = cmd;
      } else {
        other.add(cmd);
      }
    }
    final out = <Map<String, dynamic>>[...other];
    if (lastDial != null) out.add(lastDial);
    if (lastSms != null) out.add(lastSms);
    return out;
  }

  Future<void> _poll() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    try {
      final list = await ApiClient().fetchPendingCommands(deviceId);
      final coalesced = CommandPoller._coalesceDialAndSms(list);
      for (final cmd in coalesced) {
        await _executor.execute(cmd);
      }
    } catch (_) {}
  }
}
