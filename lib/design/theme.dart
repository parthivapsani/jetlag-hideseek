import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';

class JetlagTheme {
  JetlagTheme._();

  static const _fontFamily = 'Plus Jakarta Sans';

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: JetlagColors.darkBg,
      colorScheme: const ColorScheme.dark(
        surface: JetlagColors.darkSurface,
        primary: JetlagColors.accent,
        secondary: JetlagColors.accent2,
        error: JetlagColors.red,
        onSurface: JetlagColors.darkText,
        onPrimary: Colors.white,
      ),
      cardTheme: CardTheme(
        color: JetlagColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          side: const BorderSide(color: JetlagColors.darkBorderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JetlagColors.darkBg,
        foregroundColor: JetlagColors.darkText,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerTheme: const DividerThemeData(
        color: JetlagColors.darkBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JetlagColors.darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.accent),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: JetlagColors.darkText2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: JetlagColors.darkText),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: JetlagColors.darkText),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: JetlagColors.darkText2),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: JetlagColors.darkText2),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: JetlagColors.darkText3),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: JetlagColors.darkText2, letterSpacing: 0.5),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: JetlagColors.lightBg,
      colorScheme: const ColorScheme.light(
        surface: JetlagColors.lightSurface,
        primary: JetlagColors.accentLight,
        secondary: JetlagColors.accentLight2,
        error: JetlagColors.redLight,
        onSurface: JetlagColors.lightText,
        onPrimary: Colors.white,
      ),
      cardTheme: CardTheme(
        color: JetlagColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          side: const BorderSide(color: JetlagColors.lightBorderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JetlagColors.lightBg,
        foregroundColor: JetlagColors.lightText,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: JetlagColors.lightBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JetlagColors.lightSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.accentLight),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: JetlagColors.lightText),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: JetlagColors.lightText),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: JetlagColors.lightText2),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: JetlagColors.lightText2),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: JetlagColors.lightText3),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: JetlagColors.lightText2, letterSpacing: 0.5),
      ),
    );
  }
}

/// Extension for quick access to design system colors from BuildContext.
extension JetlagThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? JetlagColors.darkBg : JetlagColors.lightBg;
  Color get surface => isDark ? JetlagColors.darkSurface : JetlagColors.lightSurface;
  Color get surface2 => isDark ? JetlagColors.darkSurface2 : JetlagColors.lightSurface2;
  Color get surface3 => isDark ? JetlagColors.darkSurface3 : JetlagColors.lightSurface3;
  Color get border => isDark ? JetlagColors.darkBorder : JetlagColors.lightBorder;
  Color get borderSubtle => isDark ? JetlagColors.darkBorderSubtle : JetlagColors.lightBorderSubtle;
  Color get textPrimary => isDark ? JetlagColors.darkText : JetlagColors.lightText;
  Color get textSecondary => isDark ? JetlagColors.darkText2 : JetlagColors.lightText2;
  Color get textTertiary => isDark ? JetlagColors.darkText3 : JetlagColors.lightText3;
  Color get accent => isDark ? JetlagColors.accent : JetlagColors.accentLight;
  Color get accentGlow => isDark ? JetlagColors.accentGlow : JetlagColors.accentGlowLight;
  Color get green => isDark ? JetlagColors.green : JetlagColors.greenLight;
  Color get red => isDark ? JetlagColors.red : JetlagColors.redLight;
  Color get orange => isDark ? JetlagColors.orange : JetlagColors.orangeLight;
  Color get purple => isDark ? JetlagColors.purple : JetlagColors.purpleLight;
}
