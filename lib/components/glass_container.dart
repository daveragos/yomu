import 'package:flutter/material.dart';
import '../core/constants.dart';

/// The app's card surface: a solid panel with a hairline border, the same
/// on phone and desktop.
///
/// It keeps its old name so callers don't change, but it no longer blurs or
/// tints whatever sits behind it.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.borderRadius = YomuConstants.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? YomuConstants.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: YomuConstants.hairline),
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
