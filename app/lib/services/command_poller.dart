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

  Future<void> _poll() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    try {
      final list = await ApiClient().fetchPendingCommands(deviceId);
      for (final cmd in list) {
        await _executor.execute(cmd);
      }
    } catch (_) {}
  }
}
