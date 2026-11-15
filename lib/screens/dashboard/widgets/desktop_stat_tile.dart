import 'package:flutter/material.dart';

import '../../../components/glass_container.dart';
import '../../../core/constants.dart';

/// A stat for wide layouts: an icon chip beside a large value, so a
/// row of tiles fills its width without looking empty.
class DesktopStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Only for an icon that carries state, like a lit streak flame.
  final Color? color;

  const DesktopStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color ?? YomuConstants.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: YomuConstants.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: YomuConstants.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The streak flame color used across the app: the accent once today's
/// reading is done, grey until then.
Color streakColor({required int streak, required bool isActive}) {
  return isActive ? YomuConstants.accent : YomuConstants.textSecondary;
}
