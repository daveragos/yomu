import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class WeeklyGoalCard extends StatelessWidget {
  final LibraryState state;
  final VoidCallback onEdit;

  const WeeklyGoalCard({super.key, required this.state, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final double goal = state.weeklyGoalValue;
    final double current = state.weeklyGoalType == 'minutes'
        ? state.totalMinutesRead.toDouble()
        : state.totalPagesRead.toDouble();
    final double progress = (current / goal).clamp(0.0, 1.0);

    final bool isGoalMet = progress >= 1.0;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Goal',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isGoalMet
                ? 'Amazing! Goal Exceeded! 🎉'
                : 'Keep going! Progress: ${(progress * 100).toInt()}%',
            style: TextStyle(
              color: isGoalMet
                  ? YomuConstants.accent
                  : YomuConstants.textSecondary,
              fontSize: 14,
              fontWeight: isGoalMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isGoalMet ? YomuConstants.accentGreen : YomuConstants.accent,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${current.toInt()} / ${goal.toInt()} ${state.weeklyGoalType}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
