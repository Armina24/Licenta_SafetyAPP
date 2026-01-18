import 'package:flutter/material.dart';

class AppTheme {
  // --- Dark Mode Deep Colors ---
  // Gradient background
  static const Color darkGradientTop = Color(0xFF1A1F38);
  static const Color darkGradientBottom = Color(0xFF101020);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0C3);
  static const Color textTertiary = Color(0xFF878899);

  // Glassmorphism (cards, containers)
  static const Color glassDarkMedium = Color(0x19FFFFFF); // 10% opacity white
  static const Color glassDarkLight = Color(0x0DFFFFFF); // 5% opacity white
  static const Color glassBorder = Color(0x19FFFFFF); // 10% opacity for borders

  // Accent colors (neon/vibrant)
  static const Color accentOrange = Color(0xFFFF8C42);
  static const Color accentRed = Color(0xFFFF4757);
  static const Color accentTeal = Color(0xFF00D2BA);
  static const Color accentBlue = Color(0xFF2D8CFF);
  static const Color accentPurple = Color(0xFF9D4EDD);
  static const Color accentGreen = Color(0xFF26D07C);

  // Neutral colors for dark mode
  static const Color darkNavy = Color(0xFF1A1F38);
  static const Color darkCardBackground = Color(0xFF2A2F48);
  static const Color darkBorder = Color(0xFF3A3F58);

  // --- Create Dark Theme for Material3 ---
  static ThemeData darkTheme() {
    const seedColor = Color(0xFFFF8C42);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      // Scaffold background will be handled by ScaffoldWrapper
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        // Override specific colors for consistency
        surface: glassDarkMedium,
        onSurface: textPrimary,
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
      // Cards
      cardTheme: CardThemeData(
        color: glassDarkMedium,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: textPrimary,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentOrange,
          side: const BorderSide(color: accentOrange, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassDarkMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
      ),
      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontFamily: 'Roboto',
        ),
        bodySmall: TextStyle(
          color: textTertiary,
          fontSize: 12,
          fontFamily: 'Roboto',
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
      ),
      // List tiles
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentOrange;
          }
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentOrange.withValues(alpha: 0.5);
          }
          return glassBorder;
        }),
      ),
    );
  }
}
