import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Modern & Attractive Color Palette ---
  static const Color primaryColor = Color(0xFF005A9C);
  static const Color secondaryColor = Color(0xFF0077B6);
  static const Color accentColor = Color(0xFFFFA500);
  static const Color backgroundColor = Color(0xFFF7F9FC);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1A1A1A);
  static const Color textSecondaryColor = Color(0xFF6E7A8A);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      background: backgroundColor,
      surface: cardColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: textPrimaryColor,
      onSurface: textPrimaryColor,
      onError: Colors.white,
      error: errorColor,
      brightness: Brightness.light,
    ),

    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
      displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, height: 1.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, height: 1.4),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textPrimaryColor,
      elevation: 1,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        color: primaryColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: primaryColor),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        elevation: 2,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      hintStyle: GoogleFonts.inter(color: textSecondaryColor.withOpacity(0.8)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),

    // The 'const' keyword was removed from this line to fix the error.
    cardTheme: CardThemeData(
      elevation: 1,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
      elevation: 10.0,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
    ),
  );
}