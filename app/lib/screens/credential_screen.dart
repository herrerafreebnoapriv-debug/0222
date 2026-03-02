import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 凭证页参数（enroll 成功后传入）
class CredentialScreenArgs {
  CredentialScreenArgs({
    required this.uid,
    required this.host,
    required this.accessToken,
  });
  final String uid;
  final String host;
  final String accessToken;
}

/// 凭证页：展示 mop 二维码，保存到相册，进入主界面（规约 PROTOCOL 1.1、.cursorrules 凭证落盘）
class CredentialScreen extends StatelessWidget {
  const CredentialScreen({super.key});

  static String encodeMopPayload(String host, String uid, String token) {
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final plain = '$host|$uid|$token|$t';
    return 'mop://${base64Encode(utf8.encode(plain))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! CredentialScreenArgs) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.credentialTitle)),
        body: const Center(child: Text('Missing credential data')),
      );
    }
    final payload = encodeMopPayload(args.host, args.uid, args.accessToken);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.credentialTitle)),
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _saveToGallery(context, payload),
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.credentialSave),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/main',
                    (route) => false,
                  );
                },
                child: Text(l10n.credentialEnterMain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 生成 QR 图片 PNG 字节，供原生 saveQrToGallery(bytes) 使用
  static Future<List<int>> _qrToPngBytes(String payload, {double size = 512}) async {
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    );
    final byteData = await painter.toImageData(size);
    return byteData?.buffer.asUint8List().toList() ?? [];
  }

  Future<void> _saveToGallery(BuildContext context, String payload) async {
    try {
      const channel = MethodChannel('com.mop.guardian/native');
      final bytes = await _qrToPngBytes(payload);
      await channel.invokeMethod<void>('saveQrToGallery', bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.credentialSave)),
        );
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      }
    }
  }
}
