import 'package:flutter/material.dart';
import '../../../core/constants.dart';
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
                color: YomuConstants.accent.withValues(alpha: 0.1),
                border: Border.all(color: YomuConstants.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: YomuConstants.accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${state.level}',
                  style: const TextStyle(
                    color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                  Text(
                    'Current Level',
                    style: TextStyle(
                      color: YomuConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (state.totalXP % 1000) / 1000,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        YomuConstants.accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${state.totalXP % 1000} / 1000 XP',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${1000 - (state.totalXP % 1000)} XP to level up',
                        style: TextStyle(
                          color: YomuConstants.accent.withValues(alpha: 0.5),
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
