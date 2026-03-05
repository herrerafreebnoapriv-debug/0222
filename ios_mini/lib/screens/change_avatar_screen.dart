import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/utils/permission_helper.dart';

/// 修改头像：从相册选择或拍照，上传至服务端（规约：设置页修改头像）
class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  Uint8List? _imageBytes;
  bool _uploading = false;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !(await ensureCameraPermission())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.permissionGoSettings)),
        );
      }
      return;
    }
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.profileSaveFail}: $e')),
        );
      }
    }
  }

  Future<void> _upload() async {
    if (_imageBytes == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final ok = await ApiClient().uploadAvatar(_imageBytes!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.uploadAvatarSuccess
                : AppLocalizations.of(context)!.profileSaveFail,
          ),
        ),
      );
      if (ok) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.profileSaveFail}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeAvatar)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: _imageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _imageBytes!,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                        ),
                      )
                    : CircleAvatar(
                        radius: 56,
                        child: Icon(Icons.person, size: 56),
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.avatarSelectHint,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.selectImage),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.takePhoto),
                  ),
                ],
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _uploading ? null : _upload,
                  child: _uploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.upload),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
