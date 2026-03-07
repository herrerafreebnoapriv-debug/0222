import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/device_info_service.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/screens/credential_screen.dart';
import 'package:mop_app/utils/country_codes.dart';
import 'package:mop_app/utils/permission_helper.dart';

/// 资料补全页：国家/地区下拉、手机号（同行）、用户名、昵称、密码、可选邀请码；提交 enroll（规约 2.1）
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCountryCode = '+86';
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  final _api = ApiClient();

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.length < 6 || v.length > 18) return null; // 规约 6～18 位，具体文案可 l10n
    return null;
  }

  Future<void> _submit() async {
    _errorText = null;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final deviceId = await DeviceInfoService.getDeviceId();
      final deviceInfo = await DeviceInfoService.getDeviceInfoMap();
      final payload = EnrollPayload(
        countryCode: _selectedCountryCode,
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        password: _passwordController.text,
        deviceId: deviceId,
        deviceInfo: deviceInfo,
        inviteCode: _inviteController.text.trim().isEmpty
            ? null
            : _inviteController.text.trim(),
      );
      final result = await _api.enroll(payload);
      if (!mounted) return;
      if (result.isSuccess) {
        // 注册成功 → 先权限申请 → 再进入凭证页
        final ok = await ensurePermissionsForMain(context);
        if (!mounted || !ok) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        Navigator.of(context).pushReplacementNamed(
          '/credential',
          arguments: CredentialScreenArgs(
            uid: result.uid!,
            host: result.host!,
            accessToken: result.accessToken!,
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _errorText = result.code ?? '${result.statusCode}';
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
      appBar: AppBar(title: Text(l10n.enrollTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: kCountryCodes.any((c) => c.code == _selectedCountryCode)
                            ? _selectedCountryCode
                            : kCountryCodes.first.code,
                        decoration: InputDecoration(
                          labelText: l10n.countryCode,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.fromLTRB(12, 16, 32, 16),
                        ),
                        items: kCountryCodes.map((c) {
                          final isZh = Localizations.localeOf(context).languageCode == 'zh';
                          return DropdownMenuItem<String>(
                            value: c.code,
                            child: Text(
                              '${c.displayName(isZh)} ${c.code}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCountryCode = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: l10n.phone,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? ' ' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    hintText: l10n.usernameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? ' ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: l10n.nickname,
                    hintText: l10n.nicknameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? ' ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordPlaceholder,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inviteController,
                  decoration: InputDecoration(
                    labelText: l10n.inviteCode,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.enrollFail}: $_errorText',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.submitEnroll),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

