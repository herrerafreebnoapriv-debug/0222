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

/// 仅检查主界面所需权限是否已全部授予（不弹窗），用于从设置页返回后判断是否可直接进入
Future<bool> checkAllPermissionsForMain() async => _checkAll();

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

class _PermissionConsentDialogState extends State<_PermissionConsentDialog>
    with WidgetsBindingObserver {
  bool _requesting = false;
  /// 防止 _onAgree 与 didChangeAppLifecycleState(resumed) 两处同时 pop 导致导航栈错乱（登录授权后卡死）
  bool _hasPopped = false;

  void _safePop() {
    if (_hasPopped) return;
    _hasPopped = true;
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 用户从设置页/悬浮窗页返回时重新检查，实时生效并关闭弹窗
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final ok = await _checkAll();
      if (!mounted) return;
      if (ok) _safePop();
    });
  }

  Future<void> _onAgree() async {
    setState(() => _requesting = true);
    await _requestAll();
    await Future.delayed(const Duration(milliseconds: 400));
    final ok = await _checkAll();
    if (!mounted) return;
    if (ok) {
      _safePop();
      return;
    }
    setState(() => _requesting = false);
  }

  void _onSettings() {
    openAppSettings();
    // 不关闭弹窗，用户从设置页返回时由 didChangeAppLifecycleState 重新检查并关闭，避免再次触发引导
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
