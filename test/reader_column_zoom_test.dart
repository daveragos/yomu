import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/screens/reading/widgets/reader_column.dart';

void main() {
  const window = Size(1280, 800);
  const columnWidth = 760.0;
  final page = GlobalKey();

  Future<void> pumpReader(WidgetTester tester, ValueNotifier<double> zoom) {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double? start;
    return tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<double>(
          valueListenable: zoom,
          builder: (context, value, _) => ReaderColumn(
            maxWidth: columnWidth,
            zoom: value,
            color: Colors.black,
            onPrevious: () {},
            onNext: () {},
            // As the reader wires it (reader_desktop.dart).
            child: PinchListener(
              onStart: () => start = zoom.value,
              onScale: (scale) => zoom.value = (start! * scale).clamp(1.0, 2.5),
              child: SizedBox.expand(
                child: ColoredBox(key: page, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pinch(WidgetTester tester, double scale) async {
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(const Offset(640, 400));
    await gesture.panZoomUpdate(const Offset(640, 400), scale: scale);
    await gesture.panZoomEnd();
    await tester.pump();
  }

  testWidgets('a pinch magnifies the page into the margins', (tester) async {
    final zoom = ValueNotifier(1.0);
    await pumpReader(tester, zoom);
    expect(tester.getRect(find.byKey(page)).width, columnWidth);

    await pinch(tester, 1.5);
    expect(zoom.value, 1.5);
    // Drawn 1.5× wider, laid out at the same width: the same line breaks,
    // just bigger, filling the space beside the column.
    expect(tester.getRect(find.byKey(page)).width, columnWidth * 1.5);
    expect(tester.getSize(find.byKey(page)).width, columnWidth);
  });

  testWidgets('a big pinch fills the window, then enlarges within it', (
    tester,
  ) async {
    final zoom = ValueNotifier(1.0);
    await pumpReader(tester, zoom);

    await pinch(tester, 2);
    final rect = tester.getRect(find.byKey(page));
    expect(rect.left, 0);
    expect(rect.width, window.width);
    expect(rect.height, window.height);

    await pinch(tester, 5);
    expect(zoom.value, 2.5);
  });

  testWidgets('a two-finger scroll does not zoom', (tester) async {
    final zoom = ValueNotifier(1.0);
    await pumpReader(tester, zoom);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(const Offset(640, 400));
    await gesture.panZoomUpdate(
      const Offset(640, 300),
      pan: const Offset(0, -100),
    );
    await gesture.panZoomEnd();
    await tester.pump();
    expect(zoom.value, 1);
  });
}
