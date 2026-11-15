import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/yomu_colors.dart';

class RankPathWidget extends StatelessWidget {
  final int currentLevel;
  final int achievementCount;

  const RankPathWidget({
    super.key,
    required this.currentLevel,
    required this.achievementCount,
  });

  @override
  Widget build(BuildContext context) {
    final ranks = YomuConstants.ranks;
    final currentRank = YomuConstants.getRankForLevel(
      currentLevel,
      achievementCount,
    );

    final colors = context.yomu;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: YomuConstants.horizontalPadding,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(YomuConstants.borderRadius),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mastery Path',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current Rank: ${currentRank.name}',
            style: TextStyle(
              color: colors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _buildPath(context, ranks),
        ],
      ),
    );
  }

  Widget _buildPath(BuildContext context, List<YomuRank> ranks) {
    final colors = context.yomu;
    return Column(
      children: List.generate(ranks.length, (index) {
        final rank = ranks[index];
        final isReached = currentLevel >= rank.level;
        final isNext =
            !isReached &&
            (index == 0 || currentLevel >= ranks[index - 1].level);
        final isLast = index == ranks.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isReached
                        ? colors.accent
                        : (isNext ? Colors.blueAccent : colors.tint(0.1)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isReached
                          ? Colors.transparent
                          : colors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: isReached
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isReached ? colors.accent : colors.tint(0.1),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank.name,
                    style: TextStyle(
                      color: isReached
                          ? colors.textPrimary
                          : (isNext ? Colors.blueAccent : colors.textSecondary),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Level ${rank.level}+ • ${rank.achievementsRequired} Achievements • ${rank.description}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
