import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// iOS Mini：无 Jitsi 依赖，音视频入口为占位页，提示下阶段开放
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 24),
              Text(
                l10n.voiceVideoIosDisabled,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
