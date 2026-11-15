import 'package:flutter/material.dart';
import '../core/yomu_colors.dart';
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
    final colors = context.yomu;

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
                        color: colors.tint(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '2× XP',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
                color: colors.tint(0.54),
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
    final colors = context.yomu;

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
                      color: isCompleted
                          ? colors.tint(0.38)
                          : colors.tint(0.70),
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
                      style: TextStyle(
                        color: colors.tint(0.38),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              isCompleted ? 'Done' : '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: isCompleted ? colors.accent : colors.tint(0.60),
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
            backgroundColor: colors.tint(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reward: ${quest.xpReward} XP',
              style: TextStyle(color: colors.tint(0.38), fontSize: 11),
            ),
            if (isCompleted)
              Icon(
                Icons.check_circle,
                color: colors.accent,
                size: 14,
              ),
          ],
        ),
      ],
    );
  }
}
