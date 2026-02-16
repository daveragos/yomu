import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/quest_model.dart';
import 'glass_container.dart';

class DailyQuestsCard extends StatelessWidget {
  final List<DailyQuest> quests;

  const DailyQuestsCard({super.key, required this.quests});

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Daily Quests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isWeekend) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        '2X XP',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Icon(
                isWeekend
                    ? Icons.celebration
                    : Icons.assignment_turned_in_outlined,
                color: isWeekend ? Colors.amber : Colors.white54,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final quest = quests[index];
              return _QuestItem(quest: quest, isWeekend: isWeekend);
            },
          ),
        ],
      ),
    );
  }
}

class _QuestItem extends StatelessWidget {
  final DailyQuest quest;
  final bool isWeekend;

  const _QuestItem({required this.quest, this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = quest.isCompleted;
    final double progress = quest.progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: TextStyle(
                      color: isCompleted ? Colors.white38 : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (!isCompleted)
                    Text(
                      quest.description,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              isCompleted ? 'Done' : '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: isCompleted ? YomuConstants.accent : Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted ? YomuConstants.accentGreen : YomuConstants.accent,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Reward: ${quest.xpReward} XP',
                  style: TextStyle(
                    color: isWeekend ? Colors.amber : Colors.white38,
                    fontSize: 11,
                    fontWeight: isWeekend ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isWeekend) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.flash_on, color: Colors.amber, size: 10),
                ],
              ],
            ),
            if (isCompleted)
              const Icon(
                Icons.check_circle,
                color: YomuConstants.accentGreen,
                size: 14,
              ),
          ],
        ),
      ],
    );
  }
}
