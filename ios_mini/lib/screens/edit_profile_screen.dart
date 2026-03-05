import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 个人简介页：编辑并保存简介（规约：简介以对方用户资料为准，此处为当前用户编辑）
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bioController = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.getProfile();
      if (mounted) {
        final bio = data['bio'] as String? ?? data['intro'] as String? ?? '';
        _bioController.text = bio;
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted) setState(() => _initialized = true);
    }
  }

  Future<void> _onSave() async {
    setState(() => _loading = true);
    try {
      final ok = await _api.updateProfile(bio: _bioController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.profileSaved
                : AppLocalizations.of(context)!.profileSaveFail,
          ),
        ),
      );
      if (ok) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileSaveFail)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeProfile)),
      body: _initialized
          ? SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: l10n.profileBioHint,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _onSave,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
