import 'package:flutter/material.dart';
import '../core/constants.dart';
import './glass_container.dart';

class StreakWidget extends StatelessWidget {
  final int streak;
  final bool isActive;

  const StreakWidget({super.key, required this.streak, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final Color fireColor = isActive
        ? (streak >= 30
              ? Colors.amber
              : (streak >= 7 ? Colors.orange : Colors.redAccent))
        : YomuConstants.textSecondary;

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(Icons.local_fire_department, color: fireColor, size: 24),
          const SizedBox(height: 8),
          Text(
            '$streak',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          Text(
            'Streak',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
