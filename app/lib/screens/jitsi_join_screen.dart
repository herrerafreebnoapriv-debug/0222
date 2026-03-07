import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 音视频入会页占位：当前阶段不接入会议 SDK，仅展示昵称与预期房间名供联调参考
class JitsiJoinScreen extends StatefulWidget {
  const JitsiJoinScreen({super.key});

  @override
  State<JitsiJoinScreen> createState() => _JitsiJoinScreenState();
}

class _JitsiJoinScreenState extends State<JitsiJoinScreen> {
  String _displayName = '';
  String _roomName = 'mop_test_room';
  bool _loading = true;
  bool _roomFromArgs = false;

  @override
  void initState() {
    super.initState();
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
        }
      }
    }
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
              const Icon(Icons.videocam_off_outlined, size: 64),
              const SizedBox(height: 24),
              Text(
                l10n.voiceVideo,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SelectableText(
                _displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              SelectableText(
                _roomName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.voiceVideoIosDisabled,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
