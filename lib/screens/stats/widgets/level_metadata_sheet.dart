import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class LevelMetadataSheet extends StatelessWidget {
  final LibraryState state;

  const LevelMetadataSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ranks = YomuConstants.ranks;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reading Ranks',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: YomuConstants.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: YomuConstants.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: YomuConstants.accent, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Earn 10 XP/page and 5 XP/min. Every 1000 XP = 1 Level!',
                    style: TextStyle(
                      color: Colors.white70,
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
            final bool isReached = state.level >= t.level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached
                          ? YomuConstants.accent.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: isReached
                            ? YomuConstants.accent
                            : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${t.level}',
                        style: TextStyle(
                          color: isReached ? Colors.white : Colors.white54,
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
                            color: isReached ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          t.description,
                          style: TextStyle(
                            color: isReached
                                ? YomuConstants.textSecondary
                                : Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isReached)
                    Icon(
                      Icons.check_circle,
                      color: YomuConstants.accent,
                      size: 18,
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
