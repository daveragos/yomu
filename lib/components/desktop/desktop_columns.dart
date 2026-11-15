import 'package:flutter/widgets.dart';

import '../../core/breakpoints.dart';

/// Two columns side by side when there's room for both, otherwise one
/// stacked above the other.
///
/// It goes by the width it is given, not the window's, since the sidebar
/// takes part of a wide window.
class DesktopColumns extends StatelessWidget {
  final Widget start;
  final Widget end;
  final int startFlex;
  final int endFlex;
  final double gap;

  const DesktopColumns({
    super.key,
    required this.start,
    required this.end,
    this.startFlex = 1,
    this.endFlex = 1,
    this.gap = 28,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.twoColumnMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [start, SizedBox(height: gap), end],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: startFlex, child: start),
            SizedBox(width: gap),
            Expanded(flex: endFlex, child: end),
          ],
        );
      },
    );
  }
}
