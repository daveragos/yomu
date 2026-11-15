import 'package:flutter/material.dart';
import '../core/constants.dart';
import './glass_container.dart';

class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Only for an icon that carries state, like a lit streak flame.
  final Color? color;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color ?? YomuConstants.textSecondary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
