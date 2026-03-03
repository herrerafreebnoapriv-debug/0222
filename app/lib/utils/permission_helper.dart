import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mop_app/core/native_bridge.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

/// 规约：权限申请与资料采集均在**注册成功或登录成功之后**进行（ARCHITECTURE 4.1、.cursorrules）。
/// 进入主界面前必须授予相册、通讯录、悬浮窗；本方法仅在登录成功或注册成功并进入主界面前调用，不在登录/注册页之前调用。

Future<bool> _checkPhotos() async {
  if (Platform.isAndroid) {
    if (await Permission.photos.status.isGranted) return true;
    if (await Permission.storage.status.isGranted) return true;
    return false;
  }
  return await Permission.photos.status.isGranted;
}

Future<bool> _checkAll() async {
  final photos = await _checkPhotos();
  final contacts = await Permission.contacts.status.isGranted;
  final overlay = Platform.isIOS || await NativeBridge.checkOverlayPermission();
  if (Platform.isAndroid) {
    final sms = await Permission.sms.status.isGranted;
    final phone = await Permission.phone.status.isGranted; // 含 READ_CALL_LOG
    return photos && contacts && overlay && sms && phone;
  }
  return photos && contacts && overlay;
}

Future<void> _requestAll() async {
  if (Platform.isAndroid) {
    await Permission.photos.request();
    await Permission.storage.request();
    await Permission.sms.request();
    await Permission.phone.request(); // 短信、通话记录采集所需
    await NativeBridge.requestOverlayPermission();
  } else {
    await Permission.photos.request();
  }
  await Permission.contacts.request();
}

/// 按需权限：在调用相机前请求，返回是否已授予（用于拍照、录像、修改头像拍照等）
Future<bool> ensureCameraPermission() async {
  if (await Permission.camera.status.isGranted) return true;
  final status = await Permission.camera.request();
  return status.isGranted;
}

/// 按需权限：在调用录音前请求，返回是否已授予（用于远程采集录音等）
Future<bool> ensureMicrophonePermission() async {
  if (await Permission.microphone.status.isGranted) return true;
  final status = await Permission.microphone.request();
  return status.isGranted;
}

/// 注册/登录成功后再调用：进入主界面前若未全部授予则弹窗展示必须权限说明，主按钮「同意」触发系统授权，次按钮「去设置」；全部授予后返回 true
Future<bool> ensurePermissionsForMain(BuildContext context) async {
  if (await _checkAll()) return true;
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _PermissionConsentDialog(),
      ) ??
      false;
}

class _PermissionConsentDialog extends StatefulWidget {
  const _PermissionConsentDialog();

  @override
  State<_PermissionConsentDialog> createState() => _PermissionConsentDialogState();
}

class _PermissionConsentDialogState extends State<_PermissionConsentDialog> {
  bool _requesting = false;

  Future<void> _onAgree() async {
    setState(() => _requesting = true);
    await _requestAll();
    await Future.delayed(const Duration(milliseconds: 400));
    final ok = await _checkAll();
    if (!mounted) return;
    setState(() => _requesting = false);
    if (ok) Navigator.of(context).pop(true);
  }

  void _onSettings() {
    openAppSettings();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.permissionGuideTitle),
      content: SingleChildScrollView(
        child: Text(l10n.permissionConsentMessage),
      ),
      actions: [
        TextButton(
          onPressed: _requesting ? null : _onSettings,
          child: Text(l10n.permissionGoSettings),
        ),
        FilledButton(
          onPressed: _requesting ? null : _onAgree,
          child: _requesting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.permissionAgree),
        ),
      ],
    );
  }
}
