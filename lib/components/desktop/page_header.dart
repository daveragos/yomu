import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// The title row at the top of a screen in a wide window: an uppercase
/// eyebrow, a large title, an optional subtitle, and actions on the right.
///
/// It replaces the centered phone app bars, so every desktop screen starts
/// the same way.
class DesktopPageHeader extends StatelessWidget {
  final String title;

  /// Small uppercase label above the title, in the accent color, as on the
  /// phone dashboard ("SUNDAY, NOV 15").
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;

  const DesktopPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: YomuConstants.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: YomuConstants.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: YomuConstants.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 12), action],
      ],
    );
  }
}

/// The primary action button for desktop headers: accent fill, dark label.
class DesktopPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const DesktopPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: YomuConstants.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
