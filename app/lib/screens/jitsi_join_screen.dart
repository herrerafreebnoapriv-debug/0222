import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 音视频入会页：使用当前账户昵称入会，无二次输入姓名（规约 TINODE-JITSI-INTEGRATION 第 5 节）
/// 房间名可由 Tinode 信令下发，当前为占位（与对方 peer 相关或测试房间）
class JitsiJoinScreen extends StatefulWidget {
  const JitsiJoinScreen({super.key});

  @override
  State<JitsiJoinScreen> createState() => _JitsiJoinScreenState();
}

class _JitsiJoinScreenState extends State<JitsiJoinScreen> {
  static const String _defaultServerUrl = 'https://jit.sdkdns.top';
  String _displayName = '';
  String _roomName = 'mop_test_room';
  bool _loading = true;
  bool _joining = false;
  bool _roomFromArgs = false;
  late final TextEditingController _roomController;

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: _roomName);
    _loadDisplayName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_roomFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final uid = args['peerUid']?.toString() ?? '';
        if (uid.isNotEmpty) {
          _roomFromArgs = true;
          _roomName = 'mop_$uid';
          _roomController.text = _roomName;
        }
      }
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    try {
      final profile = await ApiClient().getProfile();
      final nickname = profile['nickname'] as String? ?? '';
      if (mounted) {
        setState(() {
          _displayName = nickname.trim().isNotEmpty ? nickname.trim() : 'User';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayName = 'User';
          _loading = false;
        });
      }
    }
  }

  void _joinMeeting() {
    if (_joining) return;
    setState(() => _joining = true);
    final room = _roomController.text.trim().isEmpty ? 'mop_test_room' : _roomController.text.trim();
    final options = JitsiMeetConferenceOptions(
      serverURL: _defaultServerUrl,
      room: room,
      userInfo: JitsiMeetUserInfo(displayName: _displayName),
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
      },
    );
    final listener = JitsiMeetEventListener(
      conferenceTerminated: (url, error) {
        if (mounted) setState(() => _joining = false);
      },
      readyToClose: () {
        if (mounted) {
          setState(() => _joining = false);
          Navigator.of(context).pop();
        }
      },
    );
    JitsiMeet().join(options, listener);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.voiceVideo)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceVideo)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l10n.voiceVideo}（昵称入会：$_displayName）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: '房间名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _joining ? null : _joinMeeting,
                child: _joining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('加入会议'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
