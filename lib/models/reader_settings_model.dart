import 'package:flutter/material.dart';

/// Theme options for the reader
enum ReaderTheme { white, cream, darkBlue, black }

/// Text alignment options for the reader
enum ReaderAlignment { left, center, justified }

/// Reader display settings model
class ReaderSettings {
  final ReaderTheme theme;
  final String typeface;
  final double textSize;
  final double lineHeight;
  final ReaderAlignment alignment;
  final bool usePublisherDefaults;
  final double autoScrollSpeed;

  const ReaderSettings({
    this.theme = ReaderTheme.black,
    this.typeface = 'Merriweather',
    this.textSize = 18.0,
    this.lineHeight = 1.6,
    this.alignment = ReaderAlignment.justified,
    this.usePublisherDefaults = false,
    this.autoScrollSpeed = 2.0,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    String? typeface,
    double? textSize,
    double? lineHeight,
    ReaderAlignment? alignment,
    bool? usePublisherDefaults,
    double? autoScrollSpeed,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      typeface: typeface ?? this.typeface,
      textSize: textSize ?? this.textSize,
      lineHeight: lineHeight ?? this.lineHeight,
      alignment: alignment ?? this.alignment,
      usePublisherDefaults: usePublisherDefaults ?? this.usePublisherDefaults,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
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
      'typeface': typeface,
      'textSize': textSize,
      'lineHeight': lineHeight,
      'alignment': alignment.index,
      'usePublisherDefaults': usePublisherDefaults,
      'autoScrollSpeed': autoScrollSpeed,
    };
  }

  /// Create from Map
  factory ReaderSettings.fromMap(Map<String, dynamic> map) {
    return ReaderSettings(
      theme: ReaderTheme.values[map['theme'] as int? ?? 3],
      typeface: map['typeface'] as String? ?? 'Merriweather',
      textSize: (map['textSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.6,
      alignment: ReaderAlignment.values[map['alignment'] as int? ?? 2],
      usePublisherDefaults: map['usePublisherDefaults'] as bool? ?? false,
      autoScrollSpeed: (map['autoScrollSpeed'] as num).toDouble().clamp(
        0.5,
        10.0,
      ),
    );
  }

  /// Default settings
  static const ReaderSettings defaults = ReaderSettings();

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
