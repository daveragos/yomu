import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Stack(
      children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  YomuConstants.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(now).toUpperCase(),
              style: TextStyle(
                color: YomuConstants.accent.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
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
                      fontSize: 24,
                      color: YomuConstants.textSecondary,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: 'Yomite',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: YomuConstants.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
