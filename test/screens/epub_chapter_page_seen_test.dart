import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/models/reader_settings_model.dart';
import 'package:yomu/screens/reading/widgets/epub_chapter_page.dart';
import 'package:yomu/utils/epub_page_weight.dart';

final EpubChapter _chapter = EpubChapter()
  ..Title = 'Chapter One'
  ..ContentFileName = 'one.xhtml'
  ..HtmlContent = '<html><body>${List.generate(
    150,
    (i) => '<p>Paragraph $i, long enough to wrap over a couple of lines '
        'on a phone-sized screen.</p>',
  ).join()}</body></html>';

/// Pumps a chapter page and returns the windows it reports as on screen.
Future<List<(double, double)>> _pumpChapter(
  WidgetTester tester, {
  double initialScrollProgress = 0,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final windows = <(double, double)>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EpubChapterPage(
          index: 0,
          isCurrentPage: true,
          chapter: _chapter,
          settings: const ReaderSettings(),
          shouldJumpToBottom: false,
          initialScrollProgress: initialScrollProgress,
          onJumpedToBottom: () {},
          onJumpedToPosition: () {},
          pullDistanceNotifier: ValueNotifier(0),
          isPullingDownNotifier: ValueNotifier(false),
          scrollProgressNotifier: ValueNotifier(0),
          showControls: false,
          onHideControls: () {},
          onToggleControls: () {},
          onInteraction: () {},
          pullTriggerDistance: 80,
          pullDeadzone: 8,
          chapters: [_chapter],
          pageController: null,
          autoScrollSpeedNotifier: ValueNotifier(0),
          highlights: const [],
          onHighlight: (_) {},
          onDeleteHighlight: (_) {},
          onContentSeen: (chapter, from, to) {
            expect(chapter, 0);
            windows.add((from, to));
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return windows;
}

double _seenFraction(List<(double, double)> windows) {
  final seen = SeenRanges();
  for (final (from, to) in windows) {
    seen.add(from, to);
  }
  return seen.fraction;
}

void main() {
  testWidgets('reports the first screen without any scrolling',
      (tester) async {
    final windows = await _pumpChapter(tester);
    expect(windows, isNotEmpty);
    expect(windows.first.$1, 0.0);
    expect(_seenFraction(windows), inExclusiveRange(0.0, 0.5));
  });

  testWidgets('scrolling adds what passed over the screen', (tester) async {
    final windows = await _pumpChapter(tester);
    final before = _seenFraction(windows);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(_seenFraction(windows), greaterThan(before));
    expect(_seenFraction(windows), lessThan(1.0));
  });

  testWidgets('a restored position does not count the skipped start',
      (tester) async {
    final windows = await _pumpChapter(tester, initialScrollProgress: 0.6);
    expect(windows, isNotEmpty);
    final firstSeen =
        windows.map((w) => w.$1).reduce((a, b) => a < b ? a : b);
    expect(firstSeen, greaterThan(0.4));
  });
}
