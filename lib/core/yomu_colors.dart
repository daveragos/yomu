import 'package:flutter/material.dart';

/// The app's colours for the current appearance (light or dark).
///
/// Read them with `context.yomu`. Dark is the original Yomu palette; light
/// is the same design on paper: solid white cards with a hairline border on
/// a warm off-white background, and green only as an accent.
///
/// The reader's page has its own themes (`ReaderSettings`); these colours
/// are for everything around the page: screens, sheets, dialogs, toasts.
@immutable
class YomuColors extends ThemeExtension<YomuColors> {
  const YomuColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.hairline,
    required this.outline,
    required this.cardShadow,
    required this.graphColors,
  });

  final Brightness brightness;

  /// Behind everything: the scaffold.
  final Color background;

  /// Cards and panels that sit on [background].
  final Color surface;

  /// Sheets, dialogs, menus and toasts: things that float above a screen.
  final Color surfaceRaised;

  /// Titles, body text and primary icons.
  final Color textPrimary;

  /// Labels, captions and secondary icons.
  final Color textSecondary;

  /// Primary actions, the selected item, progress, an active streak.
  final Color accent;

  /// Text and icons drawn on top of [accent].
  final Color onAccent;

  /// A card's edge against the background.
  final Color hairline;

  /// Dividers and quiet borders.
  final Color outline;

  final List<BoxShadow> cardShadow;

  /// Activity graph, from no activity to the most.
  final List<Color> graphColors;

  bool get isDark => brightness == Brightness.dark;

  /// The foreground colour at [alpha]: for translucent fills, pressed
  /// states, tracks and dividers. White in dark mode, ink in light mode, so
  /// the same alpha gives the same weight in both.
  Color tint(double alpha) => textPrimary.withValues(alpha: alpha);

  static const dark = YomuColors(
    brightness: Brightness.dark,
    background: Color(0xFF0A0B0E),
    surface: Color(0xFF16171D),
    surfaceRaised: Color(0xFF1C1D24),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
    accent: Color(0xFF2ECC71),
    onAccent: Color(0xFF000000),
    hairline: Color(0x0FFFFFFF),
    outline: Color(0xFF1E293B),
    cardShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
    graphColors: [
      Color(0xFF161B22),
      Color(0xFF0E4429),
      Color(0xFF006D32),
      Color(0xFF26A641),
      Color(0xFF39D353),
    ],
  );

  static const light = YomuColors(
    brightness: Brightness.light,
    background: Color(0xFFF5F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF15171C),
    textSecondary: Color(0xFF586273),
    // Deep enough to read on white (3.6:1), light enough for black text
    // on a green button (5.8:1).
    accent: Color(0xFF1E9A57),
    onAccent: Color(0xFF000000),
    hairline: Color(0x14000000),
    outline: Color(0xFFE1E4E8),
    cardShadow: [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
    graphColors: [
      Color(0xFFE8EAEE),
      Color(0xFF9BE9A8),
      Color(0xFF40C463),
      Color(0xFF30A14E),
      Color(0xFF216E39),
    ],
  );

  static YomuColors of(BuildContext context) =>
      Theme.of(context).extension<YomuColors>() ?? dark;

  @override
  YomuColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? hairline,
    Color? outline,
    List<BoxShadow>? cardShadow,
    List<Color>? graphColors,
  }) {
    return YomuColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      hairline: hairline ?? this.hairline,
      outline: outline ?? this.outline,
      cardShadow: cardShadow ?? this.cardShadow,
      graphColors: graphColors ?? this.graphColors,
    );
  }

  @override
  YomuColors lerp(YomuColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return YomuColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      hairline: c(hairline, other.hairline),
      outline: c(outline, other.outline),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      graphColors: [
        for (var i = 0; i < graphColors.length; i++)
          c(graphColors[i], other.graphColors[i]),
      ],
    );
  }
}

extension YomuColorsContext on BuildContext {
  /// The app's colours for the current appearance.
  YomuColors get yomu => YomuColors.of(this);
}
