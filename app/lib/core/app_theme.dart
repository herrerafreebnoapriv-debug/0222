import 'package:flutter/material.dart';

/// 应用主题（规约：简体中文为源语言，UI 简洁）
class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      );
}
