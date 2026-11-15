import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/yomu_colors.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class LevelMetadataSheet extends StatelessWidget {
  final LibraryState state;

  const LevelMetadataSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ranks = YomuConstants.ranks;
    final colors = context.yomu;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading Ranks',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.tint(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.tint(0.10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: colors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Earn XP: PDF (10/page), EPUB (40/chapter) + 5 XP/min. Every 1000 XP = 1 Level!',
                      style: TextStyle(
                        color: colors.tint(0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...ranks.map((t) {
              final bool isReached =
                  state.level >= t.level &&
                  state.unlockedAchievements.length >= t.achievementsRequired;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.tint(0.05),
                        border: Border.all(
                          color: isReached ? colors.accent : colors.tint(0.10),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${t.level}',
                          style: TextStyle(
                            color: isReached
                                ? colors.textPrimary
                                : colors.tint(0.54),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              color: isReached
                                  ? colors.textPrimary
                                  : colors.tint(0.54),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Level ${t.level}+ • ${t.achievementsRequired} Achievements\n${t.description}',
                            style: TextStyle(
                              color: isReached
                                  ? colors.textSecondary
                                  : colors.tint(0.30),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isReached)
                      Icon(
                        Icons.check_circle,
                        color: colors.accent,
                        size: 18,
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
