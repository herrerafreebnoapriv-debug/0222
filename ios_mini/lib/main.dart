import 'package:flutter/foundation.dart';
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
import 'package:mop_app/screens/voice_video_placeholder_screen.dart';
import 'package:mop_app/screens/login_screen.dart';
import 'package:mop_app/screens/my_credential_screen.dart';
import 'package:mop_app/screens/main_screen.dart';
import 'package:mop_app/screens/settings_screen.dart';
import 'package:mop_app/screens/terms_screen.dart';

const _kLocaleKey = 'app_locale';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MopApp());
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
          // 首帧兜底：无扩展主题时仍用浅灰底，避免白屏
          const fallbackBg = Color(0xFFE8E4E0);
          if (child == null) return const ColoredBox(color: fallbackBg);
          if (ext == null) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: fallbackBg,
              child: child,
            );
          }
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
          '/voice_video_join': (_) => const VoiceVideoPlaceholderScreen(),
        },
      ),
    );
  }
}

/// 启动门：根据本地是否存有 token 决定进入主界面或登录页（解决划掉后重进显示未登录）
class _StartupGatePage extends StatefulWidget {
  const _StartupGatePage();

  @override
  State<_StartupGatePage> createState() => _StartupGatePageState();
}

class _StartupGatePageState extends State<_StartupGatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    try {
      final token = await ApiClient().getAccessToken();
      if (!mounted) return;
      final route = (token != null && token.isNotEmpty) ? '/main' : '/login';
      Navigator.of(context).pushReplacementNamed(route);
    } catch (e, st) {
      if (kDebugMode) debugPrint('StartupGate _redirect error: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 首帧不依赖 Theme 解析，固定浅灰底+金色 loading，避免 iOS 白屏
    const bg = Color(0xFFE8E4E0);
    const accent = Color(0xFFD4AF37);
    return ColoredBox(
      color: bg,
      child: Center(
        child: CircularProgressIndicator(color: accent),
      ),
    );
  }
}
