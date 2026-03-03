import 'package:flutter/material.dart';

// --- 全局配色：桃色 → 淡灰 → 深灰 背景；鎏金 边框 ---

/// 桃色（浅）
const Color _kPeach = Color(0xFFF8D7DA);

/// 淡灰
const Color _kLightGray = Color(0xFFE8E4E0);

/// 深灰
const Color _kDarkGray = Color(0xFF3D3A36);

/// 鎏金渐变：亮金 → 金 → 暗金
const Color _kGoldLight = Color(0xFFF5E6C8);
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldDark = Color(0xFFB8860B);

/// 主题扩展：全局背景渐变与鎏金边框渐变
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.backgroundGradient,
    required this.borderGradient,
    required this.goldBorderColor,
  });

  final LinearGradient backgroundGradient;
  final LinearGradient borderGradient;
  /// 用于 InputBorder、Divider 等单色边框
  final Color goldBorderColor;

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    LinearGradient? backgroundGradient,
    LinearGradient? borderGradient,
    Color? goldBorderColor,
  }) {
    return AppThemeExtension(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      borderGradient: borderGradient ?? this.borderGradient,
      goldBorderColor: goldBorderColor ?? this.goldBorderColor,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      backgroundGradient: LinearGradient(
        begin: backgroundGradient.begin,
        end: backgroundGradient.end,
        colors: [
          Color.lerp(
            backgroundGradient.colors.first,
            other.backgroundGradient.colors.first,
            t,
          )!,
          Color.lerp(
            backgroundGradient.colors[1],
            other.backgroundGradient.colors[1],
            t,
          )!,
          Color.lerp(
            backgroundGradient.colors.last,
            other.backgroundGradient.colors.last,
            t,
          )!,
        ],
      ),
      borderGradient: LinearGradient(
        begin: borderGradient.begin,
        end: borderGradient.end,
        colors: [
          Color.lerp(borderGradient.colors.first, other.borderGradient.colors.first, t)!,
          Color.lerp(borderGradient.colors.last, other.borderGradient.colors.last, t)!,
        ],
      ),
      goldBorderColor: Color.lerp(goldBorderColor, other.goldBorderColor, t)!,
    );
  }

  static const AppThemeExtension _light = AppThemeExtension(
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_kPeach, _kLightGray, _kDarkGray],
    ),
    borderGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_kGoldLight, _kGold, _kGoldDark],
    ),
    goldBorderColor: _kGold,
  );

  static const AppThemeExtension _dark = AppThemeExtension(
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_kPeach, _kLightGray, _kDarkGray],
    ),
    borderGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_kGoldLight, _kGold, _kGoldDark],
    ),
    goldBorderColor: _kGold,
  );

  static AppThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<AppThemeExtension>() ?? _light;

  static AppThemeExtension light(BuildContext context) => _light;
  static AppThemeExtension dark(BuildContext context) => _dark;
}

/// 使用鎏金渐变做边框的容器（全局边框风格）
class GradientBorderBox extends StatelessWidget {
  const GradientBorderBox({
    super.key,
    required this.child,
    this.borderWidth = 1.5,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  static BorderRadius _deflate(BorderRadius r, double amount) {
    return BorderRadius.only(
      topLeft: Radius.circular((r.topLeft.x - amount).clamp(0.0, double.infinity)),
      topRight: Radius.circular((r.topRight.x - amount).clamp(0.0, double.infinity)),
      bottomLeft: Radius.circular((r.bottomLeft.x - amount).clamp(0.0, double.infinity)),
      bottomRight: Radius.circular((r.bottomRight.x - amount).clamp(0.0, double.infinity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppThemeExtension.of(context);
    final radius = borderRadius ?? BorderRadius.zero;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: ext.borderGradient,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: radius == BorderRadius.zero ? radius : _deflate(radius, borderWidth),
        ),
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

/// 应用主题（规约：简体中文为源语言，UI 简洁；全局桃色渐变淡深灰背景 + 鎏金线边框）
class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kGold,
          brightness: Brightness.light,
          primary: _kGold,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        extensions: const <ThemeExtension<dynamic>>[AppThemeExtension._light],
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.8)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _kGold, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.6)),
          ),
        ),
        dividerColor: _kGold.withValues(alpha: 0.6),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: _kGold.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kGold,
          brightness: Brightness.dark,
          primary: _kGold,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        extensions: const <ThemeExtension<dynamic>>[AppThemeExtension._dark],
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.7)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _kGold, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: _kGold.withValues(alpha: 0.5)),
          ),
        ),
        dividerColor: _kGold.withValues(alpha: 0.5),
        cardTheme: CardThemeData(
          color: Colors.black.withValues(alpha: 0.25),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: _kGold.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
