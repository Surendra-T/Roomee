import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const presentationBackground = Color(0xFFE8E6E1);
  static const screenBackground = Color(0xFFFAF9F6);
  static const pureWhite = Color(0xFFFFFFFF);

  static const primaryAction = Color(0xFF1A3622);
  static const primaryActionHover = Color(0xFF112417);
  static const primaryText = Color(0xFF111111);

  static const accent = Color(0xFFC5A059);
  static const accentLight = Color(0xFFE5D3B3);

  static const subtleBorder = Color(0xFFE5E0D8);
  static const secondaryText = Color(0xFF666666);
  static const tertiaryText = Color(0xFF999999);
  static const subtleUiBackground = Color(0xFFFAF9F6);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.screenBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryAction,
        secondary: AppColors.accent,
        surface: AppColors.pureWhite,
        onPrimary: AppColors.pureWhite,
        onSecondary: AppColors.primaryText,
        onSurface: AppColors.primaryText,
      ),
    );

    final interText = GoogleFonts.interTextTheme(base.textTheme);
    final playfairText = GoogleFonts.playfairDisplayTextTheme(base.textTheme);
    final textTheme = interText.copyWith(
      displayLarge: playfairText.displayLarge,
      displayMedium: playfairText.displayMedium,
      displaySmall: playfairText.displaySmall,
      headlineLarge: playfairText.headlineLarge,
      headlineMedium: playfairText.headlineMedium,
      headlineSmall: playfairText.headlineSmall,
      titleLarge: playfairText.titleLarge,
      titleMedium: playfairText.titleMedium,
      titleSmall: playfairText.titleSmall,
    ).apply(
      bodyColor: AppColors.primaryText,
      displayColor: AppColors.primaryText,
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.screenBackground,
      canvasColor: AppColors.presentationBackground,
      dividerColor: AppColors.subtleBorder,
      cardColor: AppColors.pureWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        surfaceTintColor: AppColors.pureWhite,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.subtleUiBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryAction),
        ),
      ),
    );
  }
}
