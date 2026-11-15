import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/screens/reading/paging/chapter_pages.dart';

/// Lines of [lineHeight] stacked from [from], [count] of them.
List<ContentBand> lines(int count, {double lineHeight = 28, double from = 0}) => [
  for (var i = 0; i < count; i++)
    ContentBand(from + i * lineHeight, from + (i + 1) * lineHeight),
];

/// Every band that fits on a page lies wholly on one page, and no page is
/// taller than [ChapterPages.pageHeight].
void expectNoBandSplit(ChapterPages pages, List<ContentBand> bands) {
  for (var i = 0; i < pages.count; i++) {
    final height = pages.endOf(i) - pages.starts[i];
    expect(
      height,
      lessThanOrEqualTo(pages.pageHeight + 0.5),
      reason: 'page $i is taller than a page',
    );
  }
  for (final band in bands) {
    if (band.height > pages.pageHeight) continue;
    final page = pages.pageAt(band.top + 0.01);
    expect(
      band.bottom,
      lessThanOrEqualTo(pages.endOf(page) + leadingTolerance(band)),
      reason: '$band is cut at the bottom of page $page',
    );
  }
}

void main() {
  group('paginate', () {
    test('a chapter that fits is one page', () {
      final pages = paginate(lines(10), pageHeight: 700, contentHeight: 280);
      expect(pages.count, 1);
      expect(pages.progressOf(0), 1);
    });

    test('an empty chapter is one page', () {
      final pages = paginate(const [], pageHeight: 700, contentHeight: 0);
      expect(pages.count, 1);
    });

    test('pages end at a line boundary, never inside a line', () {
      // 700 / 28 = 25 lines; the 26th would cross the edge at 700.
      final bands = lines(100);
      final pages = paginate(bands, pageHeight: 710, contentHeight: 2800);
      expect(pages.starts.take(3), [0, 700, 1400]);
      expectNoBandSplit(pages, bands);
    });

    test('a line exactly at the page edge starts the next page', () {
      final bands = lines(50, lineHeight: 20);
      final pages = paginate(bands, pageHeight: 400, contentHeight: 1000);
      expect(pages.starts, [0, 400, 800]);
      expectNoBandSplit(pages, bands);
    });

    test('runs on one line with different heights are kept together', () {
      // A line with a big initial and a normal run: both bands start at the
      // line's top, the big one ends lower.
      final bands = [
        ...lines(24),
        const ContentBand(672, 720),
        const ContentBand(672, 700),
        ...lines(20, from: 720),
      ];
      final pages = paginate(bands, pageHeight: 710, contentHeight: 1280);
      expect(pages.starts[1], 672);
      expectNoBandSplit(pages, bands);
    });

    test('a picture taller than a page is cut at the page edge', () {
      final bands = [
        ...lines(5),
        const ContentBand(140, 1640),
        ...lines(5, from: 1640),
      ];
      final pages = paginate(bands, pageHeight: 700, contentHeight: 1780);
      // Text, then the picture from its top, then the rest of it.
      expect(pages.starts[1], 140);
      expect(pages.starts[2], 840);
      for (var i = 0; i < pages.count; i++) {
        expect(pages.endOf(i) - pages.starts[i], lessThanOrEqualTo(700.5));
      }
    });

    test('trailing margin does not get a page of its own', () {
      final bands = lines(25);
      // 25 lines end at 700; the chapter is 730 tall with its margin.
      final pages = paginate(bands, pageHeight: 710, contentHeight: 730);
      expect(pages.count, 1);
    });

    test('random chapters never split a line', () {
      final random = math.Random(7);
      for (var round = 0; round < 200; round++) {
        final bands = <ContentBand>[];
        var y = 0.0;
        final count = 20 + random.nextInt(400);
        for (var i = 0; i < count; i++) {
          // Paragraph gaps, headings, pictures and plain lines.
          if (random.nextDouble() < 0.1) y += 8 + random.nextDouble() * 30;
          final height = random.nextDouble() < 0.03
              ? 80 + random.nextDouble() * 500
              : 18 + random.nextDouble() * 22;
          bands.add(ContentBand(y, y + height));
          y += height;
        }
        final pageHeight = 300 + random.nextDouble() * 700;
        final pages = paginate(
          bands..shuffle(random),
          pageHeight: pageHeight,
          contentHeight: y + random.nextDouble() * 40,
        );
        expectNoBandSplit(pages, bands);
        // Every page shows something.
        for (var i = 0; i < pages.count; i++) {
          expect(
            bands.any(
              (b) => b.bottom > pages.starts[i] && b.top < pages.endOf(i),
            ),
            isTrue,
            reason: 'page $i of round $round is empty',
          );
        }
      }
    });
  });

  group('progress', () {
    final pages = paginate(lines(200), pageHeight: 710, contentHeight: 5600);

    test('every page opens again from its own progress', () {
      for (var page = 0; page < pages.count; page++) {
        expect(pages.pageForProgress(pages.progressOf(page)), page);
      }
    });

    test('the first page is 0 and the last is 1', () {
      expect(pages.progressOf(0), 0);
      expect(pages.progressOf(pages.last), 1);
      expect(pages.pageForProgress(1), pages.last);
      expect(pages.pageForProgress(0), 0);
    });

    test('a scroll position opens the page with the line at the top', () {
      // Scroll mode stores pixels / (content - viewport); the line at the
      // top of the screen was at progress * (content - page height).
      for (final y in [0.0, 650.0, 701.0, 2799.0, 4000.0]) {
        final progress = y / (5600 - 710);
        final page = pages.pageForProgress(progress);
        expect(pages.starts[page], lessThanOrEqualTo(y + 1));
        expect(pages.endOf(page), greaterThan(y));
      }
    });

    test('what was seen is the page, as a share of the chapter', () {
      final (from, to) = pages.seenFraction(1);
      expect(from, closeTo(700 / 5600, 1e-9));
      expect(to, closeTo(1400 / 5600, 1e-9));
    });
  });
}
