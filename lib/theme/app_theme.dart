import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._();

  static const backgroundColor = EliColors.darkBackground;

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: EliColors.mint,
      brightness: Brightness.dark,
      primary: EliColors.mint,
      secondary: EliColors.ice,
      tertiary: EliColors.lavender,
      surface: EliColors.surfaceDark,
      background: EliColors.darkBackground,
      onBackground: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: EliColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: EliColors.surfaceDark,
        foregroundColor: scheme.onSurface,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: EliColors.ice),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: EliColors.mint),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EliColors.surfaceDark,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.never),
    );
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: EliColors.mint,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
    );
  }
}
