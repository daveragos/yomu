import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/utils/share_files.dart';

/// share_plus refuses to share on an iPad unless the popover points at a
/// non-empty spot inside the screen.
void main() {
  late BuildContext boxContext;

  Future<void> pumpBoxAt(WidgetTester tester, Offset at, Size size) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              width: size.width,
              height: size.height,
              child: Builder(
                builder: (context) {
                  boxContext = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Rect screenOf(WidgetTester tester) =>
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  testWidgets('points at the widget that shared', (tester) async {
    await pumpBoxAt(tester, const Offset(100, 200), const Size(50, 40));
    expect(
      sharePopoverOrigin(boxContext),
      const Rect.fromLTWH(100, 200, 50, 40),
    );
  });

  testWidgets('a widget running off the screen is clipped to it', (
    tester,
  ) async {
    final screen = screenOf(tester);
    await pumpBoxAt(
      tester,
      Offset(10, screen.height - 20),
      const Size(100, 300),
    );
    expect(
      sharePopoverOrigin(boxContext),
      Rect.fromLTRB(10, screen.height - 20, 110, screen.height),
    );
  });

  testWidgets('a widget off the screen points at the middle', (tester) async {
    final screen = screenOf(tester);
    await pumpBoxAt(tester, Offset(screen.width + 10, 0), const Size(50, 50));
    final origin = sharePopoverOrigin(boxContext);
    expect(origin.center, screen.center);
    expect(origin.isEmpty, isFalse);
  });

  testWidgets('a closed sheet points at the middle', (tester) async {
    final screen = screenOf(tester);
    await pumpBoxAt(tester, const Offset(100, 200), const Size(50, 40));
    final closed = boxContext;
    await tester.pumpWidget(const SizedBox());
    expect(closed.mounted, isFalse);
    final origin = sharePopoverOrigin(closed);
    expect(origin.center, screen.center);
    expect(origin.isEmpty, isFalse);
  });
}
