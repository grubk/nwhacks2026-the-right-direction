import 'package:flutter/material.dart';

/// Accessible theme designed for users with visual impairments
/// High contrast colors, large touch targets, readable typography
class AppTheme {
  AppTheme._();

  // High contrast color palette
  static const Color primaryLight = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF90CAF9);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);

  // Deaf Mode specific colors (high visibility)
  static const Color deafModeAccent = Color(0xFFFFD600);
  static const Color deafModeBackground = Color(0xFF1A237E);
  
  // Blind Mode specific colors (high contrast for partial vision)
  static const Color blindModeAccent = Color(0xFF00E676);
  static const Color blindModeBackground = Color(0xFF000000);

  // Minimum touch target size per accessibility guidelines
  static const double minTouchTarget = 48.0;
  static const double largeTouchTarget = 72.0;

  // Typography scale for accessibility
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        onPrimary: Colors.white,
        secondary: deafModeAccent,
        onSecondary: Colors.black,
        surface: surfaceLight,
        onSurface: Colors.black87,
        error: errorColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: const TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
      ).apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(largeTouchTarget, largeTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: labelLarge.copyWith(color: Colors.white),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
      appBarTheme: const AppBarTheme(
        toolbarHeight: 64,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        onPrimary: Colors.black,
        secondary: blindModeAccent,
        onSecondary: Colors.black,
        surface: surfaceDark,
        onSurface: Colors.white,
        error: errorColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundDark,
      textTheme: const TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(largeTouchTarget, largeTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: labelLarge.copyWith(color: Colors.black),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
      appBarTheme: const AppBarTheme(
        toolbarHeight: 64,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}
