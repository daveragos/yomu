// Pages real EPUBs the way the reader does and checks that no line is ever
// cut between two pages.
//
// Not part of the normal run: point it at a folder of books.
//
//   YOMU_BOOKS_DIR="$HOME/Downloads/Telegram Desktop" flutter test test/real_books_paging_test.dart
//
// YOMU_BOOKS_LIMIT caps the chapters checked per book (default: all).
import 'dart:io';

import 'package:epub_view/epub_view.dart' show EpubChapter, EpubBook;
import 'package:epubx/epubx.dart' as epubx;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/models/reader_settings_model.dart';
import 'package:yomu/screens/reading/paging/chapter_pages.dart';
import 'package:yomu/screens/reading/paging/paged_chapter.dart';
import 'package:yomu/screens/reading/widgets/epub_chapter_page.dart';

List<EpubChapter> flatten(List<EpubChapter> chapters) => [
  for (final chapter in chapters) ...[
    chapter,
    ...flatten(chapter.SubChapters ?? const []),
  ],
];

class _Size {
  const _Size(this.name, this.width, this.height, this.textSize);
  final String name;
  final double width;
  final double height;
  final double textSize;
}

const _sizes = [
  _Size('phone, text 18', 390, 780, 18),
  _Size('phone, text 26', 390, 780, 26),
  _Size('small phone, text 14', 320, 560, 14),
  _Size('desktop column, text 18', 760, 980, 18),
];

void main() {
  final dir = Platform.environment['YOMU_BOOKS_DIR'];
  final limit = int.tryParse(Platform.environment['YOMU_BOOKS_LIMIT'] ?? '');
  final books = dir == null
      ? <File>[]
      : (Directory(dir).listSync().whereType<File>().where(
          (f) => f.path.toLowerCase().endsWith('.epub'),
        ).toList()..sort((a, b) => a.path.compareTo(b.path)));

  testWidgets(
    'real books: every line lands whole on one page',
    (tester) async {
      final report = StringBuffer();
      var failures = 0;
      for (final file in books) {
        final name = file.uri.pathSegments.last;
        final EpubBook? book = await tester.runAsync(
          () async => epubx.EpubReader.readBook(await file.readAsBytes()),
        );
        if (book == null) continue;
        final chapters = flatten(book.Chapters ?? const []);
        final count = limit == null ? chapters.length : chapters.length.clamp(0, limit);
        var pagesTotal = 0;

        for (final size in _sizes) {
          tester.view.physicalSize = Size(size.width, size.height);
          tester.view.devicePixelRatio = 1;
          for (var i = 0; i < count; i++) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: EpubChapterPage(
                    key: ValueKey('$name-$i-${size.name}'),
                    index: i,
                    isCurrentPage: true,
                    chapter: chapters[i],
                    settings: ReaderSettings(
                      typeface: 'System',
                      textSize: size.textSize,
                      epubPageTurn: PageTurn.slide,
                    ),
                    shouldJumpToBottom: false,
                    initialScrollProgress: 0,
                    onJumpedToBottom: () {},
                    onJumpedToPosition: () {},
                    pullDistanceNotifier: ValueNotifier(0),
                    isPullingDownNotifier: ValueNotifier(false),
                    scrollProgressNotifier: ValueNotifier(0),
                    showControls: false,
                    onHideControls: () {},
                    onToggleControls: () {},
                    onInteraction: () {},
                    pullTriggerDistance: 56,
                    pullDeadzone: 8,
                    chapters: chapters,
                    pageController: null,
                    autoScrollSpeedNotifier: ValueNotifier(0),
                    highlights: const [],
                    onHighlight: (_) {},
                    onDeleteHighlight: (_) {},
                    epubBook: book,
                    pageTurn: PageTurn.slide,
                  ),
                ),
              ),
            );
            await tester.pump();

            final view = tester.widget<PagedChapterView>(
              find.byType(PagedChapterView),
            );
            final pages = view.controller.pages;
            final bands = view.controller.debugBands;
            if (pages == null) {
              failures++;
              report.writeln('$name ch$i (${size.name}): no pages');
              continue;
            }
            pagesTotal += pages.count;
            final problems = _check(pages, bands);
            if (problems.isNotEmpty) {
              failures++;
              report.writeln(
                '$name ch$i "${chapters[i].Title}" (${size.name}): '
                '${problems.take(3).join('; ')}',
              );
            }
          }
        }
        report.writeln(
          '$name: $count chapters × ${_sizes.length} sizes, $pagesTotal pages',
        );
      }
      // ignore: avoid_print
      print(report);
      expect(failures, 0, reason: report.toString());
    },
    skip: books.isEmpty,
    timeout: const Timeout(Duration(minutes: 60)),
  );
}

/// Lines cut between pages, overfull pages and empty pages.
List<String> _check(ChapterPages pages, List<ContentBand> bands) {
  final problems = <String>[];
  for (var p = 0; p < pages.count; p++) {
    final height = pages.endOf(p) - pages.starts[p];
    if (height > pages.pageHeight + 0.5) {
      problems.add('page $p is ${height.round()} tall (page ${pages.pageHeight.round()})');
    }
    final shown = bands.any(
      (b) => b.height > 0.5 && b.bottom > pages.starts[p] + 0.5 && b.top < pages.endOf(p) - 0.5,
    );
    if (!shown) problems.add('page $p is empty');
  }
  for (final band in bands) {
    if (band.height <= 0.5 || band.height > pages.pageHeight) continue;
    final page = pages.pageAt(band.top + 0.01);
    if (band.bottom > pages.endOf(page) + leadingTolerance(band)) {
      if (Platform.environment['YOMU_BOOKS_DEBUG'] != null) {
        final start = pages.starts[page];
        final end = pages.endOf(page);
        final near = bands
            .where((b) => b.bottom > end - 60 && b.top < end + 60)
            .map((b) => '${b.top.toStringAsFixed(2)}-${b.bottom.toStringAsFixed(2)}')
            .join(', ');
        // ignore: avoid_print
        print('DEBUG page $page start=$start end=$end pageHeight=${pages.pageHeight} '
            'limit=${start + pages.pageHeight} near: $near');
      }
      problems.add(
        'line ${band.top.round()}–${band.bottom.round()} cut at '
        '${pages.endOf(page).round()} (page $page)',
      );
    }
  }
  return problems;
}
