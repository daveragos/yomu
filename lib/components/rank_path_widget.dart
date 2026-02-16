import 'package:flutter/material.dart';
import '../core/constants.dart';

class RankPathWidget extends StatelessWidget {
  final int currentLevel;

  const RankPathWidget({super.key, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    final ranks = YomuConstants.ranks;
    final currentRank = YomuConstants.getRankForLevel(currentLevel);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: YomuConstants.horizontalPadding,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YomuConstants.surface,
        borderRadius: BorderRadius.circular(YomuConstants.borderRadius),
        border: Border.all(color: YomuConstants.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mastery Path',
            style: TextStyle(
              color: YomuConstants.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current Rank: ${currentRank.name}',
            style: const TextStyle(
              color: YomuConstants.accentGreen,
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
                        ? YomuConstants.accentGreen
                        : (isNext ? Colors.blueAccent : YomuConstants.glassy),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isReached
                          ? Colors.transparent
                          : YomuConstants.textSecondary,
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
                    color: isReached
                        ? YomuConstants.accentGreen
                        : YomuConstants.glassy,
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
                          ? YomuConstants.textPrimary
                          : (isNext
                                ? Colors.blueAccent
                                : YomuConstants.textSecondary),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Level ${rank.level}+ • ${rank.description}',
                    style: const TextStyle(
                      color: YomuConstants.textSecondary,
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
