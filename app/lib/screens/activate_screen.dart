import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/utils/permission_helper.dart';

/// 扫码激活页：API 失效时通过扫描 mop 凭证或粘贴链接恢复（规约 PROTOCOL 1、7）
/// 解析 mop://base64(host|uid|token|timestamp)，写入 Host 与凭证并重置失败计数
class ActivateScreen extends StatefulWidget {
  const ActivateScreen({super.key});

  @override
  State<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends State<ActivateScreen> {
  final _linkController = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  /// 解析 mop:// 链接，返回 (host, uid, token) 或 null
  static ({String host, String uid, String token})? parseMopLink(String input) {
    final s = input.trim();
    if (!s.startsWith('mop://') && !s.startsWith('mop:')) return null;
    final base64 = s.replaceFirst(RegExp(r'^mop:/*'), '');
    if (base64.isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Decode(base64));
      final parts = decoded.split('|');
      if (parts.length >= 3) {
        final host = parts[0].trim();
        final uid = parts[1].trim();
        final token = parts[2].trim();
        if (host.isNotEmpty && uid.isNotEmpty && token.isNotEmpty) {
          String normalized = host;
          if (!normalized.startsWith('http')) normalized = 'https://$normalized';
          return (host: normalized, uid: uid, token: token);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onActivate() async {
    final parsed = parseMopLink(_linkController.text);
    if (parsed == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.invalidQr);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await _api.setHost(parsed.host);
      await _api.saveLoginResult(parsed.token, parsed.uid, parsed.host);
      await _api.resetFailCountAfterActivation();
      if (!mounted) return;
      final ok = await ensurePermissionsForMain(context);
      if (!mounted || !ok) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _linkController.text = text;
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.activateByScanTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.apiUnavailableHint,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: l10n.pasteMopLinkHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                maxLines: 2,
                onChanged: (_) => setState(() => _errorText = null),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _onActivate,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.activateButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
