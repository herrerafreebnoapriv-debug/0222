import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/utils/permission_helper.dart';

/// 登录页：用户须知 + 勾选「已阅读并同意」+ 手机号或用户名 + 密码（规约：勾选后登录按钮可用）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _termsAccepted = false;
  bool _loading = false;
  String? _errorText;
  bool _apiUnavailable = false;
  Timer? _retryTimer;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _checkApiAvailability();
  }

  Future<void> _checkApiAvailability() async {
    final unavailable = await _api.isApiUnavailable();
    if (mounted) {
      setState(() => _apiUnavailable = unavailable);
      if (unavailable) _startRetryTimer();
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final recovered = await _api.probeForRecovery();
      if (mounted && recovered) {
        _retryTimer?.cancel();
        setState(() => _apiUnavailable = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.connectionRestored)),
        );
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final identity = _identityController.text.trim();
    final password = _passwordController.text;
    if (identity.isEmpty || password.isEmpty) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final result = await _api.login(identity, password);
      if (!mounted) return;
      if (result.isSuccess) {
        if (_termsAccepted) await _api.setTermsAcceptedVersion(1);
        if (!mounted) return;
        // 规约：登录成功后再进行权限申请，通过后再进入主界面（主界面内触发资料采集）
        final ok = await ensurePermissionsForMain(context);
        if (!mounted || !ok) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        final unavailable = await _api.isApiUnavailable();
        if (mounted) {
          setState(() {
            _loading = false;
            _errorText = result.code == 'invalid_response'
                ? AppLocalizations.of(context)!.invalidApiResponse
                : (result.code ?? '${result.statusCode}');
            _apiUnavailable = unavailable;
          });
          if (unavailable) _startRetryTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        final unavailable = await _api.isApiUnavailable();
        setState(() {
          _loading = false;
          _errorText = e.toString();
          _apiUnavailable = unavailable;
        });
        if (unavailable) _startRetryTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_apiUnavailable) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.apiUnavailableHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pushNamed('/activate'),
                        child: Text(l10n.openCameraToScan),
                      ),
                      Text(
                        l10n.retryIn30s,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(l10n.termsTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l10n.termsContent, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                title: Text(l10n.termsAgree),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _identityController,
                decoration: InputDecoration(
                  labelText: l10n.identityPlaceholder,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: l10n.passwordPlaceholder,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.loginFail}: $_errorText',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_termsAccepted && !_loading) ? _onLogin : null,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.login),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/enroll'),
                child: Text(l10n.goEnroll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
