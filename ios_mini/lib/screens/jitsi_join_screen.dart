import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// iOS Mini 版占位：不依赖 Jitsi，仅提示“暂不支持音视频”
class JitsiJoinScreen extends StatelessWidget {
  const JitsiJoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceVideo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.voiceVideoIosDisabled,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
