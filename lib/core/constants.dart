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
  static const Color accent = Color(
    0xFF2ECC71,
  ); // Vibrant Green from Stitch alignment attempt
  static const Color accentGreen = Color(0xFF2ECC71); // Emerald Green
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color glassy = Color(0x1AFFFFFF);
  static const Color outline = Color(0xFF1E293B); // Slate 800

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

  // Ranks
  static const List<YomuRank> ranks = [
    YomuRank(
      level: 1,
      achievementsRequired: 0,
      name: 'Kohai (後輩)',
      description: 'Getting started on the journey.',
    ),
    YomuRank(
      level: 5,
      achievementsRequired: 2,
      name: 'Yomite (読み手)',
      description: 'A dedicated reader.',
    ),
    YomuRank(
      level: 10,
      achievementsRequired: 5,
      name: 'Senpai (先輩)',
      description: 'Experienced and knowledgeable.',
    ),
    YomuRank(
      level: 20,
      achievementsRequired: 8,
      name: 'Chousha (著者)',
      description: 'Deeply connected to the words.',
    ),
    YomuRank(
      level: 40,
      achievementsRequired: 10,
      name: 'Sensei (先生)',
      description: 'A master of the literary arts.',
    ),
    YomuRank(
      level: 50,
      achievementsRequired: 12,
      name: 'Tatsujin (達人)',
      description: 'Absolute mastery reached.',
    ),
  ];

  static YomuRank getRankForLevel(int level, int achievementCount) {
    YomuRank current = ranks.first;
    for (final rank in ranks) {
      if (level >= rank.level &&
          achievementCount >= rank.achievementsRequired) {
        current = rank;
      } else {
        break;
      }
    }
    return current;
  }
}

class YomuRank {
  final int level;
  final int achievementsRequired;
  final String name;
  final String description;

  const YomuRank({
    required this.level,
    required this.achievementsRequired,
    required this.name,
    required this.description,
  });
}
