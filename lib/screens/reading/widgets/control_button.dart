import 'package:flutter/material.dart';
import '../../../models/reader_settings_model.dart';

class ControlButton extends StatefulWidget {
  final Widget child;
  final ReaderSettings settings;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double borderRadius;

  /// Shown on hover with a pointer; ignored on touch.
  final String? tooltip;

  const ControlButton({
    super.key,
    required this.child,
    required this.settings,
    required this.onTap,
    this.width = 44,
    this.height = 44,
    this.borderRadius = 12,
    this.tooltip,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.settings.textColor.withValues(
              alpha: _hovered ? 0.12 : 0.05,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: button,
    );
  }
}
