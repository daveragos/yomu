import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Theme options for the reader
enum ReaderTheme { white, cream, darkBlue, black }

/// Text alignment options for the reader
enum ReaderAlignment { left, center, justified }

/// Lock states for the PDF reader
enum ReaderLockState { none, zoom, all }

/// How the reader moves through a book: one long vertical scroll, or
/// screen-sized pages that slide in from the side (Moon+ Reader's "Slide").
enum PageTurn { scroll, slide }

extension ReaderThemeBrightness on ReaderTheme {
  bool get isDark => this == ReaderTheme.darkBlue || this == ReaderTheme.black;
}

/// Reader display settings model
class ReaderSettings {
  final ReaderTheme theme;
  final ReaderTheme? epubTheme;
  final String typeface;
  final double textSize;
  final double lineHeight;
  final ReaderAlignment alignment;
  final bool usePublisherDefaults;
  final double autoScrollSpeed;
  final ReaderLockState lockState;

  /// Page turning for EPUBs and for PDFs, chosen separately: people tend to
  /// page through novels and scroll through PDFs.
  final PageTurn epubPageTurn;
  final PageTurn pdfPageTurn;

  /// The EPUB page theme to use while the app is light, and while it is
  /// dark. Choosing a theme stores it for the appearance in use, so a
  /// cream page by day and a black one by night switch on their own.
  final ReaderTheme lightPageTheme;
  final ReaderTheme darkPageTheme;

  const ReaderSettings({
    this.theme = ReaderTheme.black,
    this.epubTheme,
    this.typeface = 'Merriweather',
    this.textSize = 18.0,
    this.lineHeight = 1.6,
    this.alignment = ReaderAlignment.justified,
    this.usePublisherDefaults = false,
    this.autoScrollSpeed = 2.0,
    this.lockState = ReaderLockState.none,
    this.epubPageTurn = PageTurn.scroll,
    this.pdfPageTurn = PageTurn.scroll,
    this.lightPageTheme = ReaderTheme.white,
    this.darkPageTheme = ReaderTheme.black,
  });

  /// The page theme for EPUBs while the app has [appBrightness].
  ReaderTheme pageThemeFor(Brightness appBrightness) =>
      appBrightness == Brightness.dark ? darkPageTheme : lightPageTheme;

  /// Page turning for a PDF or an EPUB.
  PageTurn pageTurnFor({required bool isPdf}) =>
      isPdf ? pdfPageTurn : epubPageTurn;

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderTheme? epubTheme,
    String? typeface,
    double? textSize,
    double? lineHeight,
    ReaderAlignment? alignment,
    bool? usePublisherDefaults,
    double? autoScrollSpeed,
    ReaderLockState? lockState,
    PageTurn? epubPageTurn,
    PageTurn? pdfPageTurn,
    ReaderTheme? lightPageTheme,
    ReaderTheme? darkPageTheme,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      epubTheme: epubTheme ?? this.epubTheme,
      typeface: typeface ?? this.typeface,
      textSize: textSize ?? this.textSize,
      lineHeight: lineHeight ?? this.lineHeight,
      alignment: alignment ?? this.alignment,
      usePublisherDefaults: usePublisherDefaults ?? this.usePublisherDefaults,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      lockState: lockState ?? this.lockState,
      epubPageTurn: epubPageTurn ?? this.epubPageTurn,
      pdfPageTurn: pdfPageTurn ?? this.pdfPageTurn,
      lightPageTheme: lightPageTheme ?? this.lightPageTheme,
      darkPageTheme: darkPageTheme ?? this.darkPageTheme,
    );
  }

  /// Get background color for current theme
  Color get backgroundColor {
    switch (theme) {
      case ReaderTheme.white:
        return const Color(0xFFFFFFFF);
      case ReaderTheme.cream:
        return const Color(0xFFF5F0E1);
      case ReaderTheme.darkBlue:
        return const Color(0xFF1A2744);
      case ReaderTheme.black:
        return const Color(0xFF0A0B0E);
    }
  }

  /// Get text color for current theme
  Color get textColor {
    switch (theme) {
      case ReaderTheme.white:
        return const Color(0xFF1A1A1A);
      case ReaderTheme.cream:
        return const Color(0xFF333333);
      case ReaderTheme.darkBlue:
        return const Color(0xFFE0E0E0);
      case ReaderTheme.black:
        return const Color(0xFFFFFFFF);
    }
  }

  /// Get secondary text color for current theme
  Color get secondaryTextColor {
    switch (theme) {
      case ReaderTheme.white:
        return const Color(0xFF666666);
      case ReaderTheme.cream:
        return const Color(0xFF666666);
      case ReaderTheme.darkBlue:
        return const Color(0xFF8E8E93);
      case ReaderTheme.black:
        return const Color(0xFF8E8E93);
    }
  }

  /// Get menu background color for floating toolbars
  Color get menuBackgroundColor {
    switch (theme) {
      case ReaderTheme.white:
      case ReaderTheme.cream:
        return const Color(0xFF1E1E2E); // Dark Slate for light themes
      case ReaderTheme.darkBlue:
      case ReaderTheme.black:
        return const Color(0xFF2C2C3E); // Elevated Charcoal for dark themes
    }
  }

  /// Get icon color for floating toolbars
  Color get menuIconColor {
    return const Color(0xFFFFFFFF); // Always use White for high contrast menus
  }

  /// Get TextAlign value for current alignment
  TextAlign get textAlign {
    switch (alignment) {
      case ReaderAlignment.left:
        return TextAlign.left;
      case ReaderAlignment.center:
        return TextAlign.center;
      case ReaderAlignment.justified:
        return TextAlign.justify;
    }
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'theme': theme.index,
      'epubTheme': epubTheme?.index,
      'typeface': typeface,
      'textSize': textSize,
      'lineHeight': lineHeight,
      'alignment': alignment.index,
      'usePublisherDefaults': usePublisherDefaults,
      'autoScrollSpeed': autoScrollSpeed,
      'lockState': lockState.index,
      'epubPageTurn': epubPageTurn.name,
      'pdfPageTurn': pdfPageTurn.name,
      'lightPageTheme': lightPageTheme.index,
      'darkPageTheme': darkPageTheme.index,
    };
  }

  /// Create from Map
  factory ReaderSettings.fromMap(Map<String, dynamic> map) {
    ReaderTheme? themeAt(Object? index) =>
        index is int && index >= 0 && index < ReaderTheme.values.length
        ? ReaderTheme.values[index]
        : null;
    PageTurn pageTurn(Object? name) => PageTurn.values.firstWhere(
      (p) => p.name == name,
      orElse: () => PageTurn.scroll,
    );

    final epubTheme = themeAt(map['epubTheme']);
    // Settings saved before light mode had one EPUB theme for everything;
    // it becomes the page for both appearances so nothing changes until
    // the reader picks another. (`theme` alone is no guide: opening a PDF
    // sets it to white.)
    final legacyPage = epubTheme;
    return ReaderSettings(
      theme: themeAt(map['theme']) ?? ReaderTheme.black,
      epubTheme: epubTheme,
      lightPageTheme:
          themeAt(map['lightPageTheme']) ?? legacyPage ?? ReaderTheme.white,
      darkPageTheme:
          themeAt(map['darkPageTheme']) ?? legacyPage ?? ReaderTheme.black,
      epubPageTurn: pageTurn(map['epubPageTurn']),
      pdfPageTurn: pageTurn(map['pdfPageTurn']),
      typeface: map['typeface'] as String? ?? 'Merriweather',
      textSize: (map['textSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.6,
      alignment: ReaderAlignment.values[map['alignment'] as int? ?? 2],
      usePublisherDefaults: map['usePublisherDefaults'] as bool? ?? false,
      autoScrollSpeed: ((map['autoScrollSpeed'] as num?) ?? 2.0)
          .toDouble()
          .clamp(0.5, 10.0),
      lockState: ReaderLockState.values[map['lockState'] as int? ?? 0],
    );
  }

  /// Default settings
  static const ReaderSettings defaults = ReaderSettings();

  /// The font family that draws [typeface], or null for the system font.
  ///
  /// Merriweather and Lexend ship with the app (pubspec `fonts:`). Georgia
  /// comes with macOS, Windows and iOS but not Linux or Android, where
  /// Gelasio, an open font made to Georgia's metrics, stands in for it.
  static String? fontFamilyFor(String typeface) {
    if (typeface == 'System') return null;
    if (typeface == 'Georgia' && (Platform.isLinux || Platform.isAndroid)) {
      return 'Gelasio';
    }
    return typeface;
  }

  String? get fontFamily => fontFamilyFor(typeface);

  /// Available typefaces
  static const List<String> availableTypefaces = [
    'Merriweather',
    'Georgia',
    'Lexend',
    'System',
  ];

  /// Theme preview colors for UI
  static const Map<ReaderTheme, Color> themePreviewColors = {
    ReaderTheme.white: Color(0xFFFFFFFF),
    ReaderTheme.cream: Color(0xFFF5F0E1),
    ReaderTheme.darkBlue: Color(0xFF1A2744),
    ReaderTheme.black: Color(0xFF0A0B0E),
  };
}
