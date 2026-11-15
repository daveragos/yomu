import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// The title row at the top of a screen in a wide window: an optional
/// eyebrow, a large title, an optional subtitle, and actions on the right.
///
/// It replaces the centered phone app bars, so every desktop screen starts
/// the same way.
class DesktopPageHeader extends StatelessWidget {
  final String title;

  /// Small grey label above the title, as on the phone dashboard
  /// ("Sunday, Nov 15").
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
                  eyebrow!,
                  style: const TextStyle(
                    color: YomuConstants.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
        // The same 46pt height as the search field and toolbar buttons; the
        // desktop's compact density would otherwise shrink it to 32pt.
        minimumSize: const Size(0, desktopControlHeight),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Height of desktop header controls: search fields, toolbar buttons and
/// [DesktopPrimaryButton], so a row of them lines up.
const double desktopControlHeight = 46;

/// A labelled toolbar action for desktop headers, styled like the search
/// field and icon buttons beside it: a quiet surface with an accent icon.
/// Use [DesktopPrimaryButton] only for the one main action on a screen.
class DesktopToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const DesktopToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: YomuConstants.accent),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: YomuConstants.textPrimary,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        minimumSize: const Size(0, desktopControlHeight),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.only(left: 14, right: 18),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}
