import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/models/book_model.dart';
import 'package:yomu/models/reader_settings_model.dart';
import 'package:yomu/screens/reading/paging/epub_page_turner.dart';
import 'package:yomu/screens/reading/paging/paged_chapter.dart';
import 'package:yomu/screens/reading/widgets/epub_view.dart';

EpubChapter chapter(String title, int paragraphs) => EpubChapter()
  ..Title = title
  ..HtmlContent = [
    for (var i = 0; i < paragraphs; i++)
      '<p>$title paragraph $i. Lorem ipsum dolor sit amet, consectetur '
          'adipiscing elit, sed do eiusmod tempor incididunt ut labore et '
          'dolore magna aliqua. Ut enim ad minim veniam, quis nostrud.</p>',
  ].join();

/// Drives ReadingEpubView in slide mode the way ReadingScreen does.
class _Harness extends StatefulWidget {
  const _Harness({required this.chapters});
  final List<EpubChapter> chapters;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final controller = PageController();
  final turner = EpubPageTurner();
  final progress = ValueNotifier<double>(0);
  int current = 0;
  bool jumpToBottom = false;
  int controlToggles = 0;
  final List<int> chapterChanges = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ReadingEpubView(
          book: Book(
            title: 't',
            author: 'a',
            coverPath: '',
            filePath: 'x.epub',
            addedAt: DateTime(2026),
          ),
          settings: const ReaderSettings(
            typeface: 'System',
            epubPageTurn: PageTurn.slide,
          ),
          pageTurn: PageTurn.slide,
          pageTurner: turner,
          chapters: widget.chapters,
          pageController: controller,
          currentChapterIndex: current,
          shouldJumpToBottom: jumpToBottom,
          initialScrollProgress: 0,
          pullDistanceNotifier: ValueNotifier(0),
          isPullingDownNotifier: ValueNotifier(false),
          scrollProgressNotifier: progress,
          autoScrollSpeedNotifier: ValueNotifier(0),
          showControls: false,
          onPageChanged: (index) {
            if (index == current) return;
            chapterChanges.add(index);
            setState(() {
              jumpToBottom = index < current;
              current = index;
              progress.value = 0;
            });
          },
          onJumpedToBottom: () => setState(() => jumpToBottom = false),
          onJumpedToPosition: () {},
          onHideControls: () {},
          onToggleControls: () => controlToggles++,
          onInteraction: () {},
          highlights: const [],
          onHighlight: (_) {},
          onDeleteHighlight: (_) {},
        ),
      ),
    );
  }
}

PagedChapterController pagedOf(WidgetTester tester, int chapterIndex) =>
    tester
        .widgetList<PagedChapterView>(find.byType(PagedChapterView))
        .firstWhere((v) => v.chapterIndex == chapterIndex)
        .controller;

void main() {
  late _HarnessState harness;
  const size = Size(400, 700);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _Harness(chapters: [chapter('One', 40), chapter('Two', 40), chapter('Three', 3)]),
    );
    await tester.pumpAndSettle();
    harness = tester.state(find.byType(_Harness));
  }

  testWidgets('a chapter is cut into pages and opens on the first', (
    tester,
  ) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    expect(paged.pageCount, greaterThan(3));
    expect(paged.page, 0);
    expect(harness.turner.position.value?.page, 1);
    expect(harness.turner.position.value?.count, paged.pageCount);
  });

  testWidgets('tapping the edges turns pages; the middle shows controls', (
    tester,
  ) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pumpAndSettle();
    expect(paged.page, 1);
    expect(harness.progress.value, greaterThan(0));

    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pumpAndSettle();
    expect(paged.page, 0);

    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pumpAndSettle();
    expect(harness.controlToggles, 1);
    expect(paged.page, 0);
  });

  testWidgets('a swipe turns the page; a short drag springs back', (
    tester,
  ) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    await tester.fling(
      find.byType(PagedChapterView).first,
      const Offset(-150, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(paged.page, 1);

    await tester.drag(find.byType(PagedChapterView).first, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(paged.page, 1);
    expect(paged.position, 1.0);
  });

  testWidgets('past the last page the next chapter slides in, and back '
      'from it lands on the last page', (tester) async {
    await open(tester);
    final first = pagedOf(tester, 0);
    final last = first.pageCount - 1;
    for (var i = 0; i < last; i++) {
      harness.turner.turn(1);
      await tester.pumpAndSettle();
    }
    expect(first.page, last);
    expect(harness.progress.value, 1.0);

    // Dragging on the last page drags the next chapter in.
    await tester.fling(
      find.byType(PagedChapterView).first,
      const Offset(-200, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(harness.chapterChanges, [1]);
    expect(pagedOf(tester, 1).page, 0);

    // And back again: the first chapter is on its last page.
    harness.turner.turn(-1);
    await tester.pumpAndSettle();
    expect(harness.chapterChanges, [1, 0]);
    expect(pagedOf(tester, 0).page, last);
  });

  testWidgets('a slow swipe back over the chapter edge finishes even though '
      'the chapter changes during it', (tester) async {
    await open(tester);
    harness.turner.turn(1);
    await tester.pumpAndSettle();
    final last = pagedOf(tester, 0).pageCount - 1;
    for (var i = 1; i < last; i++) {
      harness.turner.turn(1);
      await tester.pumpAndSettle();
    }
    await tester.fling(find.byType(PagedChapterView).first, const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(harness.current, 1);

    // Drag right in small steps, rebuilding between them, past halfway.
    final gesture = await tester.startGesture(Offset(40, size.height / 2));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(harness.current, 0, reason: 'the chapter changed mid-swipe');
    await gesture.up();
    await tester.pumpAndSettle();

    final pager = harness.controller.position;
    expect(pager.pixels, 0, reason: 'the chapters settled, not half-way');
    expect(pagedOf(tester, 0).page, last);
  });

  testWidgets('a mouse-wheel notch turns one page; a burst still one', (
    tester,
  ) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    final center = Offset(size.width / 2, size.height / 2);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    // A wheel notch arrives as several scroll events in a row.
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(
        mouse.scroll(
          const Offset(0, 40),
          timeStamp: Duration(milliseconds: 1000 + i * 16),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(paged.page, 1);

    await tester.sendEventToBinding(
      mouse.scroll(
        const Offset(0, -40),
        timeStamp: const Duration(milliseconds: 1600),
      ),
    );
    await tester.pumpAndSettle();
    expect(paged.page, 0);
  });

  testWidgets('a two-finger trackpad swipe up turns a page', (tester) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    final trackpad = TestPointer(2, PointerDeviceKind.trackpad);
    final at = Offset(size.width / 2, size.height / 2);
    await tester.sendEventToBinding(trackpad.panZoomStart(at));
    for (var i = 1; i <= 6; i++) {
      await tester.sendEventToBinding(
        trackpad.panZoomUpdate(at, pan: Offset(0, -20.0 * i)),
      );
    }
    await tester.sendEventToBinding(trackpad.panZoomEnd());
    await tester.pumpAndSettle();
    expect(paged.page, 1, reason: 'one page per swipe, however long');
  });

  testWidgets('a mouse click in the margin does not turn the page', (
    tester,
  ) async {
    await open(tester);
    final paged = pagedOf(tester, 0);
    final gesture = await tester.startGesture(
      Offset(size.width * 0.95, size.height / 2),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(paged.page, 0, reason: 'clicks select text and follow links');
  });

  testWidgets('the book ends do not move', (tester) async {
    await open(tester);
    expect(harness.turner.turn(-1), isFalse);
    await tester.drag(find.byType(PagedChapterView).first, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(pagedOf(tester, 0).page, 0);
    expect(harness.chapterChanges, isEmpty);
  });
}
