import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class YomuTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: YomuConstants.background,
    colorScheme: const ColorScheme.dark(
      primary: YomuConstants.accent,
      secondary: YomuConstants.accentLight,
      surface: YomuConstants.surface,
      onPrimary: Colors.white,
      onSurface: YomuConstants.textPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: YomuConstants.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: YomuConstants.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: YomuConstants.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: YomuConstants.textSecondary),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: YomuConstants.textPrimary,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: YomuConstants.background,
      selectedItemColor: YomuConstants.accent,
      unselectedItemColor: YomuConstants.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
