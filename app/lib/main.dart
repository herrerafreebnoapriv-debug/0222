import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/core/app_locale.dart';
import 'package:mop_app/core/app_navigator.dart';
import 'package:mop_app/core/app_theme.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/screens/activate_screen.dart';
import 'package:mop_app/screens/add_friend_screen.dart';
import 'package:mop_app/screens/chat_screen.dart';
import 'package:mop_app/screens/change_avatar_screen.dart';
import 'package:mop_app/screens/change_password_screen.dart';
import 'package:mop_app/screens/credential_screen.dart';
import 'package:mop_app/screens/edit_profile_screen.dart';
import 'package:mop_app/screens/enroll_screen.dart';
import 'package:mop_app/screens/jitsi_join_screen.dart';
import 'package:mop_app/screens/login_screen.dart';
import 'package:mop_app/screens/my_credential_screen.dart';
import 'package:mop_app/screens/main_screen.dart';
import 'package:mop_app/screens/settings_screen.dart';
import 'package:mop_app/screens/terms_screen.dart';

const _kLocaleKey = 'app_locale';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 首帧或异步异常时至少显示可见错误，便于企业重签等环境排查
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) {
    return Material(
      color: Colors.grey.shade800,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                '${details.exception}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };
  runZonedGuarded(() {
    runApp(const MopApp());
  }, (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  });
}

/// MOP 加固 IM 应用（规约：i18n 中英、用户须知、登录/主界面/设置；语言可手动切换并持久化）
class MopApp extends StatefulWidget {
  const MopApp({super.key});

  @override
  State<MopApp> createState() => _MopAppState();
}

class _MopAppState extends State<MopApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (!mounted) return;
    setState(() {
      if (code == 'zh' || code == 'en') {
        _locale = Locale(code!);
      } else {
        _locale = null; // 跟随系统
      }
    });
  }

  void _setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale?.languageCode ?? '');
    if (mounted) setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      locale: _locale,
      setLocale: _setLocale,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'MOP',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: _locale,
        builder: (context, child) {
          final ext = Theme.of(context).extension<AppThemeExtension>();
          if (ext == null || child == null) return child ?? const SizedBox.shrink();
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: ext.backgroundGradient),
            child: child,
          );
        },
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/',
        routes: {
          '/': (_) => const _StartupGatePage(),
          '/login': (_) => const LoginScreen(),
          '/activate': (_) => const ActivateScreen(),
          '/enroll': (_) => const EnrollScreen(),
          '/credential': (_) => const CredentialScreen(),
          '/my_credential': (_) => const MyCredentialScreen(),
          '/main': (_) => const MainScreen(),
          '/chat': (_) => const ChatScreen(),
          '/add_friend': (_) => const AddFriendScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/change_avatar': (_) => const ChangeAvatarScreen(),
          '/terms': (_) => const TermsScreen(),
          '/change_password': (_) => const ChangePasswordScreen(),
          '/edit_profile': (_) => const EditProfileScreen(),
          '/jitsi_join': (_) => const JitsiJoinScreen(),
        },
      ),
    );
  }
}

/// 启动门：根据本地是否存有 token 决定进入主界面或登录页（解决划掉后重进显示未登录）
/// 首屏使用固定浅色底+深色转圈，避免深色主题下「看不见」；捕获 token 读取异常并做超时提示，便于企业重签等环境排查。
class _StartupGatePage extends StatefulWidget {
  const _StartupGatePage();

  @override
  State<_StartupGatePage> createState() => _StartupGatePageState();
}

class _StartupGatePageState extends State<_StartupGatePage> {
  bool _showTimeoutHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
      _startTimeoutHint();
    });
  }

  Future<void> _redirect() async {
    try {
      final token = await ApiClient().getAccessToken();
      if (!mounted) return;
      final route = (token != null && token.isNotEmpty) ? '/main' : '/login';
      Navigator.of(context).pushReplacementNamed(route);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _startTimeoutHint() {
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _showTimeoutHint = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E4E0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF3D3A36),
              strokeWidth: 2.5,
            ),
            if (_showTimeoutHint) ...[
              const SizedBox(height: 24),
              Text(
                'Loading is taking longer than usual.\nTry again or check network.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
