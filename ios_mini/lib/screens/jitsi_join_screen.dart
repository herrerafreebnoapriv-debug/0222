import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// ios_mini 占位：不依赖 Jitsi，仅展示“iOS 暂不支持音视频”提示
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
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
