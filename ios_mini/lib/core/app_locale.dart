import 'package:flutter/material.dart';

/// 应用语言作用域：供设置页切换语言并持久化（规约：支持用户手动切换并持久化）
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });

  final Locale? locale;
  final void Function(Locale? locale) setLocale;

  static AppLocaleScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
  }

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) {
    return locale != oldWidget.locale;
  }
}
