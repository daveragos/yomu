import 'package:flutter/widgets.dart';

/// Window widths where the layout changes.
///
/// Layout follows the window's width, not the platform, so a narrow desktop
/// window gets the phone layout and a wide tablet gets the desktop one.
abstract final class Breakpoints {
  /// At or above this width the app shows a sidebar instead of the bottom
  /// bar, and caps how wide content grows. Matches Material's "expanded"
  /// window class.
  static const double wide = 840;

  /// The widest a single column of settings-style rows should grow. Past
  /// this, a label and its control drift too far apart to scan.
  static const double formMaxWidth = 760;

  /// The widest a multi-column dashboard (Home, Stats) should grow.
  static const double dashboardMaxWidth = 1240;

  /// Width a dashboard needs before it splits into two columns. Below it
  /// (a narrow desktop window, once the sidebar takes its share) the
  /// columns stack.
  static const double twoColumnMinWidth = 900;

  /// Horizontal page padding in wide layouts.
  static const double desktopGutter = 36;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}
