import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// iOS 精简版占位：音视频/会议功能下阶段开放
class VoiceVideoPlaceholderScreen extends StatelessWidget {
  const VoiceVideoPlaceholderScreen({super.key});

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
