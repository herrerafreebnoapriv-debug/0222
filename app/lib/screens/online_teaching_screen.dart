import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/device_info_service.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

/// 在线授课页背景图路径（可选，未放置则使用渐变背景）
const String _kOnlineTeachingBackgroundImage = 'assets/images/online_teaching_bg.png';

/// 在线授课 Tab 内容：进入时展示预览/权限页，相机与麦克风等权限全部允许后方可浏览和使用该 Tab 内资源与内容
class OnlineTeachingScreen extends StatefulWidget {
  const OnlineTeachingScreen({super.key});

  @override
  State<OnlineTeachingScreen> createState() => _OnlineTeachingScreenState();
}

class _OnlineTeachingScreenState extends State<OnlineTeachingScreen> {
  bool _permissionsGranted = false;
  bool _checking = true;
  bool _requesting = false;
  bool _reportingLocation = false;

  /// 背景层：优先使用背景图，加载失败则使用渐变
  Widget _buildBackground(BuildContext context) {
    return Image.asset(
      _kOnlineTeachingBackgroundImage,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            ],
          ),
        ),
      ),
    );
  }

  /// 内容层统一包一层带背景的 Stack，保证文字可读（半透明遮罩）；右上角悬浮「附近」浅蓝色按钮
  Widget _wrapWithBackground(BuildContext context, Widget content) {
    return Stack(
      children: [
        Positioned.fill(child: _buildBackground(context)),
        Positioned.fill(
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          ),
        ),
        content,
        Positioned(
          top: 16,
          right: 16,
          child: _buildNearbyButton(context),
        ),
      ],
    );
  }

  /// 右上角悬浮「附近」按钮：申请定位权限并将所在市上报到后台（8 位设备 ID 后仅显示市）
  Widget _buildNearbyButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _reportingLocation ? null : () => _onNearbyTap(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF87CEEB).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _reportingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  l10n.nearbyButton,
                  style: const TextStyle(
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _onNearbyTap(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    setState(() => _reportingLocation = true);
    try {
      final status = await Permission.location.request();
      if (!mounted) return;
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationPermissionDenied)),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String city = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.administrativeArea ?? p.subAdministrativeArea ?? '';
      }
      city = city.trim();
      if (city.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationReportFail)),
          );
        }
        return;
      }
      final deviceId = await DeviceInfoService.getDeviceId();
      final ok = await ApiClient().reportLocation(deviceId, city);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.locationReportSuccess : l10n.locationReportFail),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationReportFail)),
        );
      }
    } finally {
      if (mounted) setState(() => _reportingLocation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // 延后权限检查，避免首帧与主界面争抢导致卡顿（优化首次登录后卡顿）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _checkPermissions();
      });
    });
  }

  /// 检查权限；若未授予则主动触发系统权限申请（用户点击在线授课 Tab 即会弹出相机/麦克风请求）
  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    bool camera = await Permission.camera.status.isGranted;
    bool mic = await Permission.microphone.status.isGranted;
    if (!camera || !mic) {
      if (!camera) {
        final status = await Permission.camera.request();
        camera = status.isGranted;
      }
      if (!mounted) return;
      if (!mic) {
        await Future.delayed(const Duration(milliseconds: 200));
        final status = await Permission.microphone.request();
        mic = status.isGranted;
      }
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _permissionsGranted = camera && mic;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);
    await Permission.camera.request();
    await Future.delayed(const Duration(milliseconds: 300));
    await Permission.microphone.request();
    await Future.delayed(const Duration(milliseconds: 300));
    final camera = await Permission.camera.status.isGranted;
    final mic = await Permission.microphone.status.isGranted;
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permissionsGranted = camera && mic;
    });
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) return;
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_checking && !_permissionsGranted) {
      return _wrapWithBackground(
        context,
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.onlineTeachingChecking),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      return _wrapWithBackground(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.school_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.onlineTeachingTab,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.onlineTeachingPermissionMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _requesting ? null : _requestPermissions,
                child: _requesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.onlineTeachingGrantButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _openSettings,
                child: Text(l10n.onlineTeachingOpenSettings),
              ),
            ],
          ),
        ),
      );
    }

    return _wrapWithBackground(context, _buildContent(l10n));
  }

  Widget _buildContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.video_library_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onlineTeachingTab,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onlineTeachingContentHint,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _checkPermissions,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.onlineTeachingRefreshPermission),
          ),
        ],
      ),
    );
  }
}
