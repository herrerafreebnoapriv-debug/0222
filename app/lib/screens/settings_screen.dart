import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/app_locale.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 设置页：我的凭证、修改头像/简介/密码、用户须知、语言、退出（规约：设置页 → 我的凭证 → 右上角生成邀请）
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguagePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scope = AppLocaleScope.of(context);
    if (scope == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.langZh),
              onTap: () {
                scope.setLocale(const Locale('zh'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(l10n.langEn),
              onTap: () {
                scope.setLocale(const Locale('en'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(l10n.langFollowSystem),
              onTap: () {
                scope.setLocale(null);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: Text(l10n.myCredential),
            onTap: () => Navigator.of(context).pushNamed('/my_credential'),
          ),
          ListTile(
            leading: const Icon(Icons.face),
            title: Text(l10n.changeAvatar),
            onTap: () => Navigator.of(context).pushNamed('/change_avatar'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.changeProfile),
            onTap: () => Navigator.of(context).pushNamed('/edit_profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.changePassword),
            onTap: () => Navigator.of(context).pushNamed('/change_password'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.userTerms),
            onTap: () => Navigator.of(context).pushNamed('/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            onTap: () => _showLanguagePicker(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () async {
              await ApiClient().clearAuth();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}
