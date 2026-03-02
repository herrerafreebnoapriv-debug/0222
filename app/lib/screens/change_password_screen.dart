import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 修改密码页：原密码、新密码、确认新密码（规约：6～18 位常规字符）
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final oldPwd = _oldController.text;
    final newPwd = _newController.text;
    final confirm = _confirmController.text;
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.passwordPlaceholder);
      return;
    }
    if (newPwd != confirm) {
      setState(() => _errorText = AppLocalizations.of(context)!.passwordMismatch);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final ok = await _api.changePassword(oldPwd, newPwd);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.changePasswordSuccess)),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _loading = false;
          _errorText = AppLocalizations.of(context)!.changePasswordFail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _oldController,
                decoration: InputDecoration(
                  labelText: l10n.oldPassword,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newController,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                decoration: InputDecoration(
                  labelText: l10n.confirmNewPassword,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                onSubmitted: (_) => _onSubmit(),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _onSubmit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
