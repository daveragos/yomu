import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/yomu_colors.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class LevelInfoCard extends StatelessWidget {
  final LibraryState state;
  final VoidCallback onTap;

  const LevelInfoCard({super.key, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentTitle = YomuConstants.getRankForLevel(
      state.level,
      state.unlockedAchievements.length,
    ).name;
    final colors = context.yomu;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.accent, width: 2),
              ),
              child: Center(
                child: Text(
                  '${state.level}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currentTitle,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colors.tint(0.38),
                      ),
                    ],
                  ),
                  Text(
                    'Current Level',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (state.totalXP % 1000) / 1000,
                      backgroundColor: colors.tint(0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${state.totalXP % 1000} / 1000 XP',
                        style: TextStyle(
                          color: colors.tint(0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${1000 - (state.totalXP % 1000)} XP to level up',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
