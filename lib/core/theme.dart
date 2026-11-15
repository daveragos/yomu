import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class YomuTheme {
  /// Toasts in a wide window: a compact floating card above the bottom edge,
  /// in the app's surface color, instead of a bar across the whole window.
  static SnackBarThemeData desktopSnackBarTheme(ThemeData base) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 440,
      insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      backgroundColor: const Color(0xFF1C1D24),
      elevation: 12,
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: YomuConstants.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: YomuConstants.accent,
      closeIconColor: YomuConstants.textSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: YomuConstants.background,
    colorScheme: const ColorScheme.dark(
      primary: YomuConstants.accent,
      secondary: YomuConstants.accentGreen,
      surface: YomuConstants.surface,
      onPrimary: Colors.black, // Better contrast with Lime
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
