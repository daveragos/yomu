import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';
import '../../core/yomu_colors.dart';

/// Which edge a sheet slides in from in a wide window.
enum SheetSide { left, right }

/// Shows [builder] as a bottom sheet on phones and as a floating side panel
/// in wide windows, where a sheet rising from the bottom edge of a large
/// window feels out of place.
///
/// The phone path is `showModalBottomSheet` with the same arguments, so call
/// sites can switch to this without changing how they look on phones. Sheets
/// keep sizing their own height; in the side panel they sit vertically
/// centered at [maxPanelWidth] wide.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SheetSide side = SheetSide.right,
  double maxPanelWidth = 420,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? barrierColor,
  ShapeBorder? shape,
}) {
  if (!Breakpoints.isWide(context)) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: barrierColor,
      shape: shape,
    );
  }

  final fromLeft = side == SheetSide.left;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) {
      return SafeArea(
        child: Align(
          alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            // A fixed width: sheets built for a phone often size rows to
            // their content and would otherwise shrink the panel.
            child: SizedBox(
              width: maxPanelWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                // Take the keyboard, so Escape closes the panel rather than
                // reaching the screen underneath.
                child: Focus(
                  autofocus: true,
                  // Sheets that rely on the bottom sheet's background color
                  // get it here too; the rest paint their own.
                  child: Material(
                    color: backgroundColor ?? Colors.transparent,
                    child: Builder(builder: builder),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(fromLeft ? -0.08 : 0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The grab handle at the top of a sheet. Sheets shown by [showAdaptiveSheet]
/// can only be dragged as phone bottom sheets, so in a wide window, where
/// they are side panels, it draws nothing.
class SheetHandle extends StatelessWidget {
  /// Defaults to the foreground at 24%, which reads in light and dark.
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const SheetHandle({super.key, this.color, this.margin});

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) {
      // Keep the space around it, so the panel's content isn't cramped.
      return Padding(padding: margin ?? EdgeInsets.zero);
    }
    return Container(
      margin: margin,
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? context.yomu.tint(0.24),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
