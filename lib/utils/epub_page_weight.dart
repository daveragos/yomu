import 'dart:math' as math;

import 'package:epubx/epubx.dart';

import 'epub_text_match.dart';

/// Visible characters that count as one printed page of an EPUB.
///
/// A paperback page holds about 250–300 words, and EPUB prose measures about
/// 5.6 characters per word once spaces and punctuation are included, so
/// ~1,500 characters (~270 words) make a page. On Animal Farm this gives
/// 10 pages for Chapter One and ~113 for the book; print editions run 95–140.
const int epubCharsPerPage = 1500;

final RegExp _invisibleBlocks = RegExp(
  r'<head[\s>].*?</head\s*>|<style[\s>].*?</style\s*>|<script[\s>].*?</script\s*>|<!--.*?-->',
  caseSensitive: false,
  dotAll: true,
);
final RegExp _tags = RegExp(r'<[^>]*>');
final RegExp _entities = RegExp(
  r'&(?:#\d+|#x[0-9a-f]+|[a-z][a-z0-9]*);',
  caseSensitive: false,
);
final RegExp _whitespace = RegExp(r'\s+');

/// Number of characters a reader actually sees in a chapter's (X)HTML.
///
/// Drops the `<head>` (title, CSS links), `<style>`, `<script>` and comments,
/// removes tags with their attributes, counts each entity as one character
/// and collapses whitespace runs the way rendering does.
int visibleTextLength(String? html) {
  if (html == null || html.isEmpty) return 0;
  return html
      .replaceAll(_invisibleBlocks, ' ')
      .replaceAll(_tags, ' ')
      .replaceAll(_entities, '_')
      .replaceAll(_whitespace, ' ')
      .trim()
      .length;
}

/// Visible text length of each chapter, used both as its page weight and as
/// its share of the book for progress.
///
/// Sub-chapters that point into the same file by anchor all render that whole
/// file, so the file's text is split evenly between them instead of being
/// counted once per entry.
///
/// Only what the reader renders counts: the first `<body>`, as
/// [cleanChapterHtml] picks it. epubx appends every other `*_split_*` file
/// of a Calibre-split book to each chapter's `HtmlContent`, which would
/// otherwise make every chapter weigh as much as the whole book.
List<int> epubChapterTextLengths(List<EpubChapter> chapters) {
  int measure(EpubChapter c) =>
      visibleTextLength(cleanChapterHtml(c.HtmlContent ?? ''));
  final entriesPerFile = <String, int>{};
  for (final c in chapters) {
    final file = c.ContentFileName;
    if (file != null) entriesPerFile[file] = (entriesPerFile[file] ?? 0) + 1;
  }
  final lengthPerFile = <String, int>{};
  return [
    for (final c in chapters)
      if (c.ContentFileName case final file?)
        (lengthPerFile[file] ??= measure(c)) ~/ entriesPerFile[file]!
      else
        measure(c),
  ];
}

/// Pages a chapter with [textLength] visible characters counts as once read.
///
/// Rounds to the nearest page, with a minimum of one so a short or image-only
/// section the reader spent time on still counts, as any PDF page does.
int epubChapterPages(int textLength) {
  return math.max(1, (textLength / epubCharsPerPage).round());
}

/// The parts of one chapter that have been on screen, as 0–1 fractions of its
/// content.
class SeenRanges {
  final List<(double, double)> _ranges = []; // sorted, non-overlapping

  void add(double from, double to) {
    var start = from.clamp(0.0, 1.0);
    var end = to.clamp(0.0, 1.0);
    if (end <= start) return;
    final merged = <(double, double)>[];
    var placed = false;
    for (final (rangeStart, rangeEnd) in _ranges) {
      if (rangeEnd < start) {
        merged.add((rangeStart, rangeEnd));
      } else if (rangeStart > end) {
        if (!placed) merged.add((start, end));
        placed = true;
        merged.add((rangeStart, rangeEnd));
      } else {
        start = math.min(start, rangeStart);
        end = math.max(end, rangeEnd);
      }
    }
    if (!placed) merged.add((start, end));
    _ranges
      ..clear()
      ..addAll(merged);
  }

  /// Share of the chapter seen so far (0–1).
  double get fraction =>
      _ranges.fold(0.0, (sum, range) => sum + range.$2 - range.$1);
}

/// Turns what a reader has had on screen into EPUB pages read.
///
/// Each chapter credits the share of its pages that has been on screen, once
/// per session, so skipping through a chapter or re-reading it adds nothing.
/// Pages are also credited no faster than one per [minTimePerPage] of reading
/// time, the minimum a PDF page needs, so flinging to the end of a chapter
/// does not count as reading it.
class EpubReadingCredit {
  EpubReadingCredit({this.minTimePerPage = const Duration(seconds: 5)});

  final Duration minTimePerPage;
  final Map<int, SeenRanges> _seen = {};
  final Map<int, double> _settled = {}; // pages per chapter credited or skimmed
  double _carry = 0; // fraction of a page credited but not yet reported

  /// Records that [from]–[to] (0–1) of [chapter] is on screen.
  void markSeen(int chapter, double from, double to) {
    _seen.putIfAbsent(chapter, SeenRanges.new).add(from, to);
  }

  /// Whole pages read since the last call, given each chapter's page count
  /// and the reading time [elapsed] since the last call.
  ///
  /// Newly seen pages beyond what [elapsed] allows were skimmed and are
  /// dropped; part pages carry over to the next call.
  int takePages(List<int> chapterPages, Duration elapsed) {
    var allowed = elapsed.inMicroseconds / minTimePerPage.inMicroseconds;
    for (final MapEntry(key: chapter, value: seen) in _seen.entries) {
      if (chapter < 0 || chapter >= chapterPages.length) continue;
      final seenPages = seen.fraction * chapterPages[chapter];
      final fresh = seenPages - (_settled[chapter] ?? 0);
      if (fresh <= 0) continue;
      final credited = math.min(fresh, math.max(allowed, 0.0));
      allowed -= credited;
      _carry += credited;
      _settled[chapter] = seenPages;
    }
    final whole = (_carry + 1e-9).floor();
    _carry = math.max(_carry - whole, 0.0);
    return whole;
  }

  /// Forgets everything, for a new book or session.
  void clear() {
    _seen.clear();
    _settled.clear();
    _carry = 0;
  }
}

/// Overall progress (0–1) for being [scroll] (0–1) through [chapter],
/// weighting each chapter by [lengths].
double epubProgressAt(List<int> lengths, int chapter, double scroll) {
  final total = lengths.fold<int>(0, (sum, len) => sum + len);
  if (total <= 0 || chapter < 0 || chapter >= lengths.length) return 0.0;
  final before = lengths.take(chapter).fold<int>(0, (sum, len) => sum + len);
  return ((before + lengths[chapter] * scroll) / total).clamp(0.0, 1.0);
}

/// Where to reopen a book saved at [progress]: the chapter and how far into
/// it (0–1). Inverse of [epubProgressAt].
///
/// [savedChapter] is the chapter index saved with the progress. When valid it
/// wins, so progress saved under an older length measure still reopens in the
/// right chapter; only the spot inside the chapter comes from [progress].
({int chapter, double scroll}) epubPositionAt(
  List<int> lengths,
  double progress, {
  int? savedChapter,
}) {
  if (lengths.isEmpty) return (chapter: 0, scroll: 0.0);
  final total = lengths.fold<int>(0, (sum, len) => sum + len);
  final target = progress * total;

  var chapter = lengths.length - 1;
  if (savedChapter != null &&
      savedChapter >= 0 &&
      savedChapter < lengths.length) {
    chapter = savedChapter;
  } else if (target <= 0) {
    chapter = 0; // a new book opens at the very start, cover included
  } else {
    var end = 0;
    for (var i = 0; i < lengths.length; i++) {
      end += lengths[i];
      // Strictly past this chapter: progress that ends exactly at a chapter
      // boundary resumes at the start of the next chapter.
      if (end > target) {
        chapter = i;
        break;
      }
    }
  }

  final before = lengths.take(chapter).fold<int>(0, (sum, len) => sum + len);
  final length = lengths[chapter];
  final scroll =
      length > 0 ? ((target - before) / length).clamp(0.0, 1.0) : 0.0;
  return (chapter: chapter, scroll: scroll);
}
