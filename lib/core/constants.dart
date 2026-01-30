import 'package:flutter/material.dart';

class YomuConstants {
  // Layout Constants
  static const double borderRadius = 16.0;
  static const double paddingUnit = 8.0;
  static const double horizontalPadding = 20.0;
  static const double verticalPadding = 20.0;

  // Colors (Stitch Design Alignment)
  static const Color background = Color(0xFF0A0B0E);
  static const Color surface = Color(0xFF16171D);
  static const Color accent = Color(0xFF2ECC71); // Vibrant Emerald Green
  static const Color accentGreen = Color(
    0xFF27AE60,
  ); // Darker Green for secondary
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color glassy = Color(0x1AFFFFFF);
  static const Color outline = Color(0xFF2C2C2E);

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 10)),
  ];

  // GitHub Graph Colors
  static List<Color> graphColors = [
    const Color(0xFF161B22), // empty
    const Color(0xFF0E4429), // level 1
    const Color(0xFF006D32), // level 2
    const Color(0xFF26A641), // level 3
    const Color(0xFF39D353), // level 4
  ];
}
