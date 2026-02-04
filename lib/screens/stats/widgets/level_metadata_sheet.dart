import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class LevelMetadataSheet extends StatelessWidget {
  final LibraryState state;

  const LevelMetadataSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final titles = [
      {
        'level': 1,
        'name': 'Kohai (後輩)',
        'desc': 'Getting started on the journey.',
      },
      {'level': 5, 'name': 'Yomite (読み手)', 'desc': 'A dedicated reader.'},
      {
        'level': 10,
        'name': 'Senpai (先輩)',
        'desc': 'Experienced and knowledgeable.',
      },
      {
        'level': 20,
        'name': 'Chousha (著者)',
        'desc': 'Deeply connected to the words.',
      },
      {
        'level': 40,
        'name': 'Sensei (先生)',
        'desc': 'A master of the literary arts.',
      },
      {
        'level': 50,
        'name': 'Tatsujin (達人)',
        'desc': 'Absolute mastery reached.',
      },
    ];

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
          const SizedBox(height: 4),
          Text(
            'Earn XP by reading to rank up!',
            style: TextStyle(color: YomuConstants.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ...titles.map((t) {
            final bool isReached = state.level >= (t['level'] as int);
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
                        '${t['level']}',
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
                          t['name'] as String,
                          style: TextStyle(
                            color: isReached ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          t['desc'] as String,
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
