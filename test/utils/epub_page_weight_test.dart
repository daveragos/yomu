import 'dart:math' as math;

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/utils/epub_page_weight.dart';

EpubChapter chapter(String? file, String html) => EpubChapter()
  ..ContentFileName = file
  ..HtmlContent = html;

/// A chapter file with [words] words of prose wrapped in typical EPUB markup:
/// XML prolog, a head with inline CSS, and classed/styled paragraphs.
String epubXhtml(int words) {
  final paragraphs = StringBuffer();
  for (var i = 0; i < words; i += 10) {
    paragraphs.write(
      '<p class="calibre_paragraph_indent" style="margin:0;text-indent:1.5em">'
      '<span class="calibre_span">${List.filled(10, 'word').join(' ')}.</span>'
      '</p>\n',
    );
  }
  return '<?xml version="1.0" encoding="utf-8"?>\n'
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter</title>'
      '<link rel="stylesheet" type="text/css" href="stylesheet.css"/>'
      '<style type="text/css">p { margin: 0; } .calibre_span { font-size: 1em; }</style>'
      '</head><body class="calibre"><div class="chapter">$paragraphs</div></body></html>';
}

void main() {
  group('visibleTextLength', () {
    test('counts only text a reader sees', () {
      const html = '<?xml version="1.0"?><html><head><title>Hidden title</title>'
          '<style>p { color: red; }</style></head>'
          '<body><!-- note --><script>var x = 1;</script>'
          '<p class="a" style="margin:0">Hello <b>world</b></p></body></html>';
      expect(visibleTextLength(html), 'Hello world'.length);
    });

    test('collapses whitespace and counts entities as one character', () {
      expect(visibleTextLength('<p>  a \n\n b&nbsp;&amp;&#8212;c </p>'),
          'a b___c'.length);
    });

    test('keeps a bare ampersand and an unclosed entity-like run', () {
      expect(visibleTextLength('<p>Tom & Jerry; fin</p>'),
          'Tom & Jerry; fin'.length);
    });

    test('is zero for missing or empty content', () {
      expect(visibleTextLength(null), 0);
      expect(visibleTextLength(''), 0);
      expect(visibleTextLength('<div><img src="cover.jpg"/></div>'), 0);
    });
  });

  group('epubChapterPages', () {
    test('uses ~1,500 visible characters per page, rounded', () {
      expect(epubChapterPages(epubCharsPerPage), 1);
      expect(epubChapterPages(epubCharsPerPage * 10), 10);
      expect(epubChapterPages((epubCharsPerPage * 2.4).round()), 2);
      expect(epubChapterPages((epubCharsPerPage * 2.6).round()), 3);
    });

    test('counts any chapter as at least one page', () {
      expect(epubChapterPages(0), 1);
      expect(epubChapterPages(200), 1);
    });

    test('a ~2,700 word chapter is about 10 printed pages, whatever the markup',
        () {
      final html = epubXhtml(2700);
      final pages = epubChapterPages(visibleTextLength(html));
      expect(pages, inInclusiveRange(9, 12));
      // The old measure (raw HTML / 1000) counted markup as reading.
      expect((html.length / 1000).ceil(), greaterThan(pages * 2));
    });
  });

  group('epubChapterTextLengths', () {
    test('measures each chapter file by its visible text', () {
      final lengths = epubChapterTextLengths([
        chapter('a.xhtml', '<p>12345</p>'),
        chapter('b.xhtml', '<head><style>x{}</style></head><p>123</p>'),
      ]);
      expect(lengths, [5, 3]);
    });

    test('splits a file shared by anchored sub-chapters between them', () {
      final shared = '<p>${'x' * 900}</p>';
      final lengths = epubChapterTextLengths([
        chapter('intro.xhtml', '<p>${'y' * 100}</p>'),
        chapter('part1.xhtml', shared),
        chapter('part1.xhtml', shared),
        chapter('part1.xhtml', shared),
      ]);
      expect(lengths, [100, 300, 300, 300]);
    });

    test('counts only the rendered body of a Calibre-split chapter', () {
      // epubx appends every other index_split_* file to each chapter.
      String doc(String text) =>
          '<?xml version="1.0"?><html><head><title>t</title></head>'
          '<body><p>$text</p></body></html>';
      final a = doc('a' * 400), b = doc('b' * 600), c = doc('c' * 800);
      final lengths = epubChapterTextLengths([
        chapter('index_split_001.html', a + b + c),
        chapter('index_split_002.html', b + a + c),
        chapter('index_split_003.html', c + a + b),
      ]);
      expect(lengths, [400, 600, 800]);
    });

    test('does not merge chapters without a file name', () {
      final lengths = epubChapterTextLengths([
        chapter(null, '<p>abc</p>'),
        chapter(null, '<p>abc</p>'),
      ]);
      expect(lengths, [3, 3]);
    });
  });

  group('SeenRanges', () {
    test('merges overlapping and touching windows', () {
      final seen = SeenRanges()
        ..add(0.0, 0.1)
        ..add(0.05, 0.2)
        ..add(0.2, 0.3);
      expect(seen.fraction, closeTo(0.3, 1e-9));
    });

    test('does not count a skipped gap', () {
      final seen = SeenRanges()
        ..add(0.0, 0.1)
        ..add(0.8, 0.9);
      expect(seen.fraction, closeTo(0.2, 1e-9));
      seen.add(0.05, 0.85); // later reads the gap
      expect(seen.fraction, closeTo(0.9, 1e-9));
    });

    test('ignores empty windows and clamps to the chapter', () {
      final seen = SeenRanges()
        ..add(0.5, 0.5)
        ..add(-0.2, 0.1)
        ..add(0.95, 1.4);
      expect(seen.fraction, closeTo(0.15, 1e-9));
    });
  });

  group('EpubReadingCredit', () {
    const pages = [10, 4];
    const plenty = Duration(minutes: 30);

    /// Scrolls through [from]–[to] of [chapter] one screen (2%) at a time.
    void scroll(EpubReadingCredit credit, int chapter, double from, double to) {
      for (var top = from; top < to - 1e-9; top += 0.02) {
        credit.markSeen(chapter, top, math.min(top + 0.02, to));
      }
    }

    test('credits only the part of a chapter scrolled through', () {
      final credit = EpubReadingCredit();
      scroll(credit, 0, 0.0, 0.5);
      expect(credit.takePages(pages, plenty), 5);
    });

    test('resuming mid-chapter credits from there, not from the start', () {
      final credit = EpubReadingCredit();
      scroll(credit, 0, 0.6, 1.0);
      expect(credit.takePages(pages, plenty), 4);
    });

    test('opening a chapter and leaving after a few seconds credits ~nothing',
        () {
      final credit = EpubReadingCredit()..markSeen(0, 0.0, 0.03);
      expect(credit.takePages(pages, const Duration(seconds: 6)), 0);
    });

    test('flinging through a chapter credits one page per 5 s at most', () {
      final credit = EpubReadingCredit();
      scroll(credit, 0, 0.0, 1.0);
      expect(credit.takePages(pages, const Duration(seconds: 10)), 2);
      // The skimmed rest is not credited later by time spent elsewhere.
      expect(credit.takePages(pages, plenty), 0);
    });

    test('re-reading a chapter in the same session adds nothing', () {
      final credit = EpubReadingCredit();
      scroll(credit, 0, 0.0, 1.0);
      expect(credit.takePages(pages, plenty), 10);
      scroll(credit, 0, 0.0, 1.0);
      expect(credit.takePages(pages, plenty), 0);
    });

    test('carries part pages over and counts every chapter read', () {
      final credit = EpubReadingCredit();
      scroll(credit, 0, 0.0, 0.25); // 2.5 pages
      expect(credit.takePages(pages, plenty), 2);
      scroll(credit, 1, 0.0, 0.5); // 2 pages + the 0.5 carried
      expect(credit.takePages(pages, plenty), 2);
      scroll(credit, 1, 0.5, 0.65); // 0.6 pages + 0.5 carried
      expect(credit.takePages(pages, plenty), 1);
    });

    test('ignores chapters outside the book', () {
      final credit = EpubReadingCredit()..markSeen(7, 0, 1);
      expect(credit.takePages(pages, plenty), 0);
    });

    test('clear starts a fresh session', () {
      final credit = EpubReadingCredit();
      scroll(credit, 1, 0.0, 1.0);
      credit.clear();
      expect(credit.takePages(pages, plenty), 0);
    });
  });

  group('progress and resume', () {
    const lengths = [1200, 0, 5000, 3000, 800];

    test('progress runs from 0 to 1 weighted by chapter length', () {
      expect(epubProgressAt(lengths, 0, 0), 0.0);
      expect(epubProgressAt(lengths, 2, 0.5), closeTo(3700 / 10000, 1e-9));
      expect(epubProgressAt(lengths, 4, 1), 1.0);
    });

    test('reopening lands where the reader left off', () {
      for (var c = 0; c < lengths.length; c++) {
        for (final scroll in [0.0, 0.3, 0.75, 1.0]) {
          final progress = epubProgressAt(lengths, c, scroll);
          final position = epubPositionAt(lengths, progress, savedChapter: c);
          expect(position.chapter, c, reason: 'chapter $c at $scroll');
          if (lengths[c] > 0) {
            expect(position.scroll, closeTo(scroll, 1e-9));
          }
        }
      }
    });

    test('without a saved chapter, mid-chapter positions still round-trip', () {
      for (var c = 0; c < lengths.length; c++) {
        if (lengths[c] == 0) continue;
        for (final scroll in [0.1, 0.5, 0.9]) {
          final progress = epubProgressAt(lengths, c, scroll);
          final position = epubPositionAt(lengths, progress);
          expect(position.chapter, c);
          expect(position.scroll, closeTo(scroll, 1e-9));
        }
      }
    });

    test('progress saved under the old HTML-length measure reopens in the '
        'saved chapter', () {
      // A markup-heavy index at the end (as in real books) gives it a much
      // bigger share under the old weights, so the same fraction now falls
      // in an earlier chapter.
      const oldHtmlLengths = [1000, 4000, 12000, 12000, 40000];
      const textLengths = [500, 3500, 11000, 11000, 4000];
      final savedProgress = epubProgressAt(oldHtmlLengths, 3, 0.05);

      expect(epubPositionAt(textLengths, savedProgress).chapter, 2);

      final position =
          epubPositionAt(textLengths, savedProgress, savedChapter: 3);
      expect(position.chapter, 3);
      expect(position.scroll, 0.0);
    });

    test('progress on a chapter boundary resumes at the next chapter start',
        () {
      final atStartOf3 = epubProgressAt(lengths, 3, 0);
      final position = epubPositionAt(lengths, atStartOf3);
      expect(position.chapter, 3);
      expect(position.scroll, 0.0);

      final finished = epubPositionAt(lengths, 1.0);
      expect(finished.chapter, lengths.length - 1);
      expect(finished.scroll, 1.0);
    });

    test('a new book opens at the start even if it begins with no text', () {
      final position = epubPositionAt(const [0, 0, 4000, 3000], 0.0);
      expect(position.chapter, 0);
      expect(position.scroll, 0.0);
    });

    test('ignores an out-of-range saved chapter', () {
      final progress = epubProgressAt(lengths, 3, 0.5);
      expect(epubPositionAt(lengths, progress, savedChapter: 9).chapter, 3);
      expect(epubPositionAt(lengths, progress, savedChapter: -1).chapter, 3);
    });

    test('empty book opens at the start', () {
      final position = epubPositionAt(const [], 0.4);
      expect(position.chapter, 0);
      expect(position.scroll, 0.0);
    });
  });
}
