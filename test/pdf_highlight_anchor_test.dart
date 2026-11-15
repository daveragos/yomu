import 'package:flutter_test/flutter_test.dart';
import 'package:yomu/utils/pdf_highlight_anchor.dart';

void main() {
  const page = 'The quick brown fox\njumps over the lazy dog.\nThe end.';

  group('format and parse', () {
    test('round-trips', () {
      const anchor = PdfHighlightAnchor(
        startPage: 3,
        startIndex: 10,
        endPage: 4,
        endIndex: 7,
      );
      final parsed = PdfHighlightAnchor.tryParse(anchor.format())!;
      expect(anchor.format(), '3:pdf:10:4:7');
      expect(parsed.startPage, 3);
      expect(parsed.startIndex, 10);
      expect(parsed.endPage, 4);
      expect(parsed.endIndex, 7);
    });

    test('rejects EPUB positions and broken values', () {
      for (final position in [
        '3:exact:0:0.4',
        '5:ratio:0.9',
        '2:0.5',
        '1:pdf:4:1',
        '1:pdf:x:1:9',
        '1:pdf:-1:1:9',
        '2:pdf:9:1:20', // ends before it starts
        '1:pdf:5:1:5', // empty
      ]) {
        expect(PdfHighlightAnchor.tryParse(position), isNull, reason: position);
      }
    });

    test('contains', () {
      const outer = PdfHighlightAnchor(
        startPage: 1,
        startIndex: 40,
        endPage: 2,
        endIndex: 10,
      );
      expect(
        outer.contains(
          const PdfHighlightAnchor(
            startPage: 1,
            startIndex: 50,
            endPage: 1,
            endIndex: 60,
          ),
        ),
        isTrue,
      );
      expect(
        outer.contains(
          const PdfHighlightAnchor(
            startPage: 1,
            startIndex: 30,
            endPage: 1,
            endIndex: 60,
          ),
        ),
        isFalse,
      );
    });
  });

  group('rangeOnPage', () {
    test('uses the stored offsets when the text still matches', () {
      const anchor = PdfHighlightAnchor(
        startPage: 0,
        startIndex: 10,
        endPage: 0,
        endIndex: 25,
      );
      expect(page.substring(10, 25), 'brown fox\njumps');
      expect(anchor.rangeOnPage(0, page, 'brown fox jumps'), (
        start: 10,
        end: 25,
      ));
      expect(anchor.rangeOnPage(1, page, 'brown fox jumps'), isNull);
    });

    test('finds moved text, nearest to the old offset', () {
      const text = 'The quick brown fox\njumps. The quick fox.';
      const anchor = PdfHighlightAnchor(
        startPage: 2,
        startIndex: 26,
        endPage: 2,
        endIndex: 31,
      );
      // Offsets 26..31 no longer hold "quick", so it is looked up again.
      expect(anchor.rangeOnPage(2, text, 'quick'), (start: 31, end: 36));
    });

    test('tolerates line breaks inside the highlighted text', () {
      const anchor = PdfHighlightAnchor(
        startPage: 0,
        startIndex: 0,
        endPage: 0,
        endIndex: 9,
      );
      final range = anchor.rangeOnPage(0, page, 'lazy dog. The end')!;
      expect(page.substring(range.start, range.end), 'lazy dog.\nThe end');
    });

    test('gives up when the text is not on the page', () {
      const anchor = PdfHighlightAnchor(
        startPage: 0,
        startIndex: 0,
        endPage: 0,
        endIndex: 9,
      );
      expect(anchor.rangeOnPage(0, page, 'elephants'), isNull);
    });

    test('splits a multi-page highlight across its pages', () {
      const anchor = PdfHighlightAnchor(
        startPage: 4,
        startIndex: 45,
        endPage: 6,
        endIndex: 9,
      );
      const highlight = 'lazy dog. The end. Middle page. Next page';
      const middle = 'Middle page.';
      const last = 'Next page goes on.';
      expect(anchor.rangeOnPage(4, page, highlight), (start: 45, end: 53));
      expect(anchor.rangeOnPage(5, middle, highlight), (start: 0, end: 12));
      expect(anchor.rangeOnPage(6, last, highlight), (start: 0, end: 9));
      expect(anchor.rangeOnPage(7, last, highlight), isNull);
    });
  });
}
