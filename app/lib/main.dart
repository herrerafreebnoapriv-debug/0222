import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/login',
        routes: {
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
