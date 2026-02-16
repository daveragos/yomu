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
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Goals',
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
          if (state.weeklyPageGoal > 0)
            _buildGoalProgress(
              context: context,
              title: 'Pages',
              current: state.weeklyPagesRead.toDouble(),
              goal: state.weeklyPageGoal,
              unit: 'pages',
            ),
          if (state.weeklyMinuteGoal > 0) ...[
            if (state.weeklyPageGoal > 0) const SizedBox(height: 20),
            _buildGoalProgress(
              context: context,
              title: 'Minutes',
              current: state.weeklyMinutesRead.toDouble(),
              goal: state.weeklyMinuteGoal,
              unit: 'minutes',
            ),
          ],
          if (state.weeklyXPGoal > 0) ...[
            if (state.weeklyPageGoal > 0 || state.weeklyMinuteGoal > 0)
              const SizedBox(height: 20),
            _buildGoalProgress(
              context: context,
              title: 'Experience',
              current: state.weeklyXPRead.toDouble(),
              goal: state.weeklyXPGoal,
              unit: 'XP',
            ),
          ],
          if (state.weeklyPageGoal == 0 &&
              state.weeklyMinuteGoal == 0 &&
              state.weeklyXPGoal == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No goals set for this week',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress({
    required BuildContext context,
    required String title,
    required double current,
    required double goal,
    required String unit,
  }) {
    final double progress = (current / goal).clamp(0.0, 1.0);
    final bool isGoalMet = progress >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: isGoalMet ? YomuConstants.accent : Colors.white60,
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
              isGoalMet ? YomuConstants.accentGreen : YomuConstants.accent,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${current.toInt()} / ${goal.toInt()} $unit',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
