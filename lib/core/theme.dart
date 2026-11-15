import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'yomu_colors.dart';

class YomuTheme {
  /// Toasts in a wide window: a compact floating card above the bottom edge,
  /// in the app's raised surface colour, instead of a bar across the whole
  /// window.
  static SnackBarThemeData desktopSnackBarTheme(ThemeData base) {
    final colors = base.extension<YomuColors>() ?? YomuColors.dark;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 440,
      insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      backgroundColor: colors.surfaceRaised,
      elevation: colors.isDark ? 12 : 6,
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: colors.accent,
      closeIconColor: colors.textSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.tint(colors.isDark ? 0.08 : 0.10)),
      ),
    );
  }

  static final ThemeData darkTheme = _build(YomuColors.dark);
  static final ThemeData lightTheme = _build(YomuColors.light);

  static ThemeData _build(YomuColors c) {
    final isDark = c.isDark;
    final base = isDark ? const ColorScheme.dark() : const ColorScheme.light();
    final scheme = base.copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      // Material 3 tints containers from these; pin them to the palette so
      // menus, sheets and fields are neutral instead of lavender.
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: isDark ? const Color(0xFF24252D) : const Color(0xFFEDEEF0),
      surfaceTint: Colors.transparent,
      outline: c.tint(isDark ? 0.24 : 0.28),
      outlineVariant: c.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: scheme,
      extensions: [c],
      dividerColor: c.outline,
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary),
      textTheme: GoogleFonts.outfitTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: c.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: c.textPrimary,
        systemOverlayStyle: systemBars(c.brightness),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: c.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.background,
        selectedItemColor: c.accent,
        unselectedItemColor: c.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.tint(0.3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: c.textSecondary, fontSize: 15),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surfaceRaised : const Color(0xFF23252B),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: YomuColors.dark.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2B33) : const Color(0xFF23252B),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.tint(0.08),
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        thumbColor: c.accent,
        inactiveTrackColor: c.tint(0.12),
        overlayColor: c.accent.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onAccent
              : (isDark ? c.textSecondary : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.tint(isDark ? 0.12 : 0.16),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.accent : null,
        ),
        checkColor: WidgetStateProperty.all(c.onAccent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: c.tint(0.38)),
        labelStyle: TextStyle(color: c.textSecondary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.3),
        selectionHandleColor: c.accent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
    );
  }

  /// Status and navigation bar icons that read on the app's background.
  static SystemUiOverlayStyle systemBars(Brightness appBrightness) {
    final isDark = appBrightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
  }
}
