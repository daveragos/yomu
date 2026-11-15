import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../providers/library_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final libraryState = ref.watch(libraryProvider);
    final rankName = libraryState.rankName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMM d').format(now),
          style: const TextStyle(
            color: YomuConstants.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: now.hour < 12
                    ? 'Good Morning, '
                    : now.hour < 17
                    ? 'Good Afternoon, '
                    : 'Good Evening, ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 18,
                  color: YomuConstants.textSecondary,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: rankName,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: YomuConstants.textPrimary,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        _buildXPProgressBar(libraryState),
      ],
    );
  }

  Widget _buildXPProgressBar(LibraryState state) {
    final int currentXP = state.totalXP;
    final int nextLevelXP = (state.level) * 1000;
    final int currentLevelStartXP = (state.level - 1) * 1000;
    final double progress =
        ((currentXP - currentLevelStartXP) /
                (nextLevelXP - currentLevelStartXP))
            .clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${state.level}',
              style: const TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${currentXP % 1000} / 1000 XP',
              style: const TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: YomuConstants.glassy,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: YomuConstants.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
