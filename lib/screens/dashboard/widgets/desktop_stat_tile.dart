import 'package:flutter/material.dart';

import '../../../components/glass_container.dart';
import '../../../core/yomu_colors.dart';

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
    final colors = context.yomu;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three tiles in a narrow column leave too little room beside the
        // icon for the label, so a narrow tile puts the icon above it.
        final stacked = constraints.maxWidth < 170;
        final badge = Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.tint(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? colors.textSecondary, size: 22),
        );
        final text = _text(colors);
        return GlassContainer(
          padding: const EdgeInsets.all(18),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [badge, const SizedBox(height: 12), text],
                )
              : Row(
                  children: [
                    badge,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                  ],
                ),
        );
      },
    );
  }

  Widget _text(YomuColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
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
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// The streak flame color used across the app: the accent once today's
/// reading is done, grey until then.
Color streakColor({
  required YomuColors colors,
  required int streak,
  required bool isActive,
}) {
  return isActive ? colors.accent : colors.textSecondary;
}
