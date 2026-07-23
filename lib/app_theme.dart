import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _darkBackground = Color(0xff282a36);
  static const _darkSurface = Color(0xff343746);
  static const _darkSurfaceVariant = Color(0xff44475a);
  static const _darkForeground = Color(0xfff8f8f2);
  static const _darkPurple = Color(0xffbd93f9);
  static const _darkPink = Color(0xffff79c6);
  static const _darkCyan = Color(0xff8be9fd);
  static const _darkRed = Color(0xffff5555);

  static const _lightBackground = Color(0xfff4f3f8);
  static const _lightSurface = Color(0xfffdfcff);
  static const _lightSurfaceVariant = Color(0xffe8e5ef);
  static const _lightForeground = Color(0xff282a36);
  static const _lightPurple = Color(0xff6d46a8);
  static const _lightPink = Color(0xffa83270);
  static const _lightCyan = Color(0xff087d91);
  static const _lightRed = Color(0xffb32635);

  static final light = _theme(
    ColorScheme(
      brightness: Brightness.light,
      primary: _lightPurple,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xffe9ddff),
      onPrimaryContainer: const Color(0xff29104d),
      secondary: _lightPink,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xffffd8e9),
      onSecondaryContainer: const Color(0xff3e0023),
      tertiary: _lightCyan,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xffb8eff7),
      onTertiaryContainer: const Color(0xff002f37),
      error: _lightRed,
      onError: Colors.white,
      errorContainer: const Color(0xffffdadd),
      onErrorContainer: const Color(0xff410009),
      surface: _lightSurface,
      onSurface: _lightForeground,
      surfaceContainerHighest: _lightSurfaceVariant,
      onSurfaceVariant: const Color(0xff5c5865),
      outline: const Color(0xff77727f),
      outlineVariant: const Color(0xffcac5d0),
      shadow: const Color(0xff000000),
      scrim: const Color(0xff000000),
      inverseSurface: _darkSurface,
      onInverseSurface: _darkForeground,
      inversePrimary: _darkPurple,
    ),
    scaffoldBackground: _lightBackground,
  );

  static final dark = _theme(
    ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPurple,
      onPrimary: const Color(0xff2d1747),
      primaryContainer: const Color(0xff553d75),
      onPrimaryContainer: const Color(0xfff2e7ff),
      secondary: _darkPink,
      onSecondary: const Color(0xff4d1737),
      secondaryContainer: const Color(0xff713858),
      onSecondaryContainer: const Color(0xffffe1ef),
      tertiary: _darkCyan,
      onTertiary: const Color(0xff00363d),
      tertiaryContainer: const Color(0xff24505a),
      onTertiaryContainer: const Color(0xffc7f5ff),
      error: _darkRed,
      onError: const Color(0xff4b1119),
      errorContainer: const Color(0xff733039),
      onErrorContainer: const Color(0xffffdadd),
      surface: _darkSurface,
      onSurface: _darkForeground,
      surfaceContainerHighest: _darkSurfaceVariant,
      onSurfaceVariant: const Color(0xffd7d4df),
      outline: const Color(0xffa9a4b2),
      outlineVariant: const Color(0xff5f6170),
      shadow: const Color(0xff000000),
      scrim: const Color(0xff000000),
      inverseSurface: _darkForeground,
      onInverseSurface: _darkBackground,
      inversePrimary: _lightPurple,
    ),
    scaffoldBackground: _darkBackground,
  );

  static ThemeData _theme(
    ColorScheme colors, {
    required Color scaffoldBackground,
  }) {
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: scaffoldBackground,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: const OutlineInputBorder(),
      ),
      dividerColor: colors.outlineVariant,
    );
  }
}
