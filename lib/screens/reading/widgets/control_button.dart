import 'package:flutter/material.dart';
import '../../../models/reader_settings_model.dart';

class ControlButton extends StatelessWidget {
  final Widget child;
  final ReaderSettings settings;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double borderRadius;

  const ControlButton({
    super.key,
    required this.child,
    required this.settings,
    required this.onTap,
    this.width = 44,
    this.height = 44,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: settings.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(child: child),
      ),
    );
  }
}
