import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 用户须知页：展示须知与免责声明（规约：设置页可再次查阅）
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.userTerms)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.termsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.termsContent,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
