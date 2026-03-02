import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 我的凭证页：展示当前用户 mop 二维码，右上角「生成邀请」（规约 ARCHITECTURE 9、PROTOCOL 2.3）
class MyCredentialScreen extends StatefulWidget {
  const MyCredentialScreen({super.key});

  @override
  State<MyCredentialScreen> createState() => _MyCredentialScreenState();
}

class _MyCredentialScreenState extends State<MyCredentialScreen> {
  final _api = ApiClient();
  String? _uid;
  String? _host;
  String? _token;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCredential();
  }

  Future<void> _loadCredential() async {
    final uid = await _api.getUid();
    final host = await _api.getHost();
    final token = await _api.getAccessToken();
    if (!mounted) return;
    setState(() {
      _uid = uid;
      _host = host;
      _token = token;
      _loading = false;
      _error = (uid != null && token != null) ? null : '请先登录';
    });
  }

  static String _encodeMopPayload(String host, String uid, String token) {
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final plain = '$host|$uid|$token|$t';
    return 'mop://${base64Encode(utf8.encode(plain))}';
  }

  Future<void> _onGenerateInvite() async {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    final result = await _api.inviteGenerate();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (result.isSuccess) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _InviteSheet(
          inviteCode: result.inviteCode!,
          inviteUrl: result.inviteUrl!,
          api: result.api!,
          onCopy: (msg) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
        ),
      );
    } else {
      if (result.statusCode == 401) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.enrollFail}: ${result.code ?? result.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myCredential)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _uid == null || _host == null || _token == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myCredential)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? ''),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }
    final payload = _encodeMopPayload(_host!, _uid!, _token!);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCredential),
        actions: [
          TextButton.icon(
            onPressed: _onGenerateInvite,
            icon: const Icon(Icons.person_add),
            label: Text(l10n.generateInvite),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.credentialTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({
    required this.inviteCode,
    required this.inviteUrl,
    required this.api,
    required this.onCopy,
  });

  final String inviteCode;
  final String inviteUrl;
  final String api;
  final void Function(String msg) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.generateInvite, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SelectableText(inviteCode, style: const TextStyle(fontFamily: 'monospace')),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  onCopy(l10n.copied);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.inviteUrl, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(inviteUrl, style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteUrl));
                  onCopy(l10n.copied);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: inviteUrl,
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
