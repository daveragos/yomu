import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/models/book_model.dart';
import 'package:yomu/models/reader_settings_model.dart';
import 'package:yomu/screens/reading/widgets/epub_chapter_page.dart';
import 'package:yomu/screens/reading/widgets/epub_view.dart';

/// Mirrors how ReadingScreen drives ReadingEpubView: it owns the current
/// chapter, the one-shot jump-to-bottom flag and the progress notifier, and
/// reacts to page changes the same way `_handleChapterPageChange` does.
class _Harness extends StatefulWidget {
  const _Harness({required this.chapters, this.initialChapter = 0});

  final List<EpubChapter> chapters;
  final int initialChapter;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final PageController controller =
      PageController(initialPage: widget.initialChapter);
  late int current = widget.initialChapter;
  bool shouldJumpToBottom = false;
  final progress = ValueNotifier<double>(0);
  final pull = ValueNotifier<double>(0);
  final pullingDown = ValueNotifier<bool>(false);
  final autoScroll = ValueNotifier<double>(0);
  final List<double> progressLog = [];

  @override
  void initState() {
    super.initState();
    progress.addListener(() => progressLog.add(progress.value));
  }

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
          settings: const ReaderSettings(typeface: 'System'),
          chapters: widget.chapters,
          pageController: controller,
          currentChapterIndex: current,
          shouldJumpToBottom: shouldJumpToBottom,
          initialScrollProgress: 0,
          pullDistanceNotifier: pull,
          isPullingDownNotifier: pullingDown,
          scrollProgressNotifier: progress,
          autoScrollSpeedNotifier: autoScroll,
          showControls: false,
          onPageChanged: (index) {
            if (index == current) return;
            setState(() {
              shouldJumpToBottom = index < current;
              current = index;
              progress.value = 0;
            });
          },
          onJumpedToBottom: () => setState(() => shouldJumpToBottom = false),
          onJumpedToPosition: () {},
          onHideControls: () {},
          onToggleControls: () {},
          onInteraction: () {},
          highlights: const [],
          onHighlight: (_) {},
          onDeleteHighlight: (_) {},
        ),
      ),
    );
  }
}

EpubChapter _chapter(String title) {
  final paragraphs = List.generate(
    40,
    (i) => '<p>$title paragraph $i. Lorem ipsum dolor sit amet, consectetur '
        'adipiscing elit, sed do eiusmod tempor incididunt ut labore.</p>',
  ).join();
  return EpubChapter()
    ..Title = title
    ..HtmlContent = '<html><body>$paragraphs</body></html>';
}

final _chapters = [_chapter('One'), _chapter('Two'), _chapter('Three')];

Finder _pageScrollable(int index) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is EpubChapterPage && w.index == index,
      ),
      matching: find.byType(Scrollable),
    );

ScrollPosition _position(WidgetTester tester, int index) =>
    tester.state<ScrollableState>(_pageScrollable(index).first).position;

double _page(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness)).controller.page!;

/// Drags the chapter by [dy] in small steps and keeps the finger down.
Future<TestGesture> _drag(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(const Offset(400, 300));
  const steps = 20;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

Future<void> _scrollToEnd(WidgetTester tester, int index) async {
  final position = _position(tester, index);
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
}

void main() {
  testWidgets('releasing a long pull at the end changes chapter at once', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(chapters: _chapters));
    await tester.pumpAndSettle();
    await _scrollToEnd(tester, 0);

    final gesture = await _drag(tester, -220);
    expect(find.text('Release for next chapter'), findsOneWidget);
    await gesture.up();

    // The page turn starts on release, not after the bounce settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_page(tester), greaterThan(0.05));

    await tester.pumpAndSettle();
    expect(_page(tester), 1.0);
    expect(_position(tester, 1).pixels, 0.0);
    expect(find.text('Release for next chapter'), findsNothing);
  });

  testWidgets('a short pull shows the hint but stays on the chapter', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(chapters: _chapters));
    await tester.pumpAndSettle();
    await _scrollToEnd(tester, 0);

    final gesture = await _drag(tester, -70);
    expect(find.text('Pull for next chapter'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_page(tester), 0.0);
    final position = _position(tester, 0);
    expect(position.pixels, position.maxScrollExtent);
  });

  testWidgets('a fling into the end of a chapter does not change chapter', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(chapters: _chapters));
    await tester.pumpAndSettle();
    final position = _position(tester, 0);
    position.jumpTo(position.maxScrollExtent - 150);
    await tester.pump();

    await tester.fling(
      _pageScrollable(0).first,
      const Offset(0, -150),
      4000,
    );
    await tester.pumpAndSettle();

    expect(_page(tester), 0.0);
  });

  testWidgets('pulling back shows the previous chapter from its end', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(chapters: _chapters, initialChapter: 1));
    await tester.pumpAndSettle();
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    expect(_position(tester, 1).pixels, 0.0);

    final gesture = await _drag(tester, 220);
    expect(find.text('Release for previous chapter'), findsOneWidget);
    await gesture.up();

    // Early in the animation, before the page change is reported, the
    // chapter sliding in from above must already be at its end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final previous = _position(tester, 0);
    expect(previous.pixels, previous.maxScrollExtent);

    // Through the rest of the animation, including the frame where the page
    // change is reported, the chapter being left must not jump to its own end.
    // (It only bounces back from the pull, which may coast a little past its
    // top.)
    var sawPageChange = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_pageScrollable(1).evaluate().isEmpty) break;
      sawPageChange |= harness.current == 0;
      expect(_position(tester, 1).pixels, lessThan(300));
    }
    expect(sawPageChange, isTrue);

    await tester.pumpAndSettle();
    expect(_page(tester), 0.0);
    expect(harness.current, 0);
    expect(harness.shouldJumpToBottom, isFalse);
    expect(_position(tester, 0).pixels, _position(tester, 0).maxScrollExtent);
    // Progress reflects the end of the previous chapter, not its start.
    expect(harness.progress.value, 1.0);
  });

  testWidgets('progress never dips to 0 before the next chapter is current', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(chapters: _chapters));
    await tester.pumpAndSettle();
    await _scrollToEnd(tester, 0);
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    expect(harness.progress.value, 1.0);

    final gesture = await _drag(tester, -220);
    await gesture.up();
    // While chapter 0 is still current, progress must stay at its end.
    for (var i = 0; i < 40 && harness.current == 0; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (harness.current == 0) expect(harness.progress.value, 1.0);
    }
    await tester.pumpAndSettle();
    expect(harness.current, 1);
    expect(harness.progress.value, 0.0);
  });
}
