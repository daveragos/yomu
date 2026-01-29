import 'package:flutter/material.dart';

class YomuConstants {
  // Layout Constants
  static const double borderRadius = 16.0;
  static const double paddingUnit = 8.0;
  static const double horizontalPadding = 20.0;
  static const double verticalPadding = 20.0;

  // Colors (Dark Theme focused)
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF1C1C22);
  static const Color accent = Color(0xFF6366F1); // Indigo
  static const Color accentLight = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color glassy = Color(0x33FFFFFF);
  static const Color outline = Color(0xFF374151);

  // GitHub Graph Colors
  static List<Color> graphColors = [
    const Color(0xFF161B22), // empty
    const Color(0xFF0E4429), // level 1
    const Color(0xFF006D32), // level 2
    const Color(0xFF26A641), // level 3
    const Color(0xFF39D353), // level 4
  ];
}
