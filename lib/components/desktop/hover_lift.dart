import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Lifts [child] slightly and rims it with the accent color while the
/// pointer is over it, so cards read as clickable on desktop.
///
/// Touch devices never hover, so on phones this only adds the click cursor.
class HoverLift extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  /// How far the card rises on hover, in logical pixels.
  final double lift;

  /// Draws an accent-tinted outline on hover. Turn off for children that
  /// already draw their own border.
  final bool showOutline;

  final MouseCursor cursor;

  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.lift = 4,
    this.showOutline = true,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -widget.lift : 0, 0),
        foregroundDecoration: widget.showOutline
            ? BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: _hovered
                      ? YomuConstants.accent.withValues(alpha: 0.45)
                      : Colors.transparent,
                ),
              )
            : null,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: YomuConstants.accent.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
