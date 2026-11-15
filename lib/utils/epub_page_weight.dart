import 'dart:math' as math;

import 'package:epubx/epubx.dart';

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
List<int> epubChapterTextLengths(List<EpubChapter> chapters) {
  final entriesPerFile = <String, int>{};
  for (final c in chapters) {
    final file = c.ContentFileName;
    if (file != null) entriesPerFile[file] = (entriesPerFile[file] ?? 0) + 1;
  }
  final lengthPerFile = <String, int>{};
  return [
    for (final c in chapters)
      if (c.ContentFileName case final file?)
        (lengthPerFile[file] ??= visibleTextLength(c.HtmlContent)) ~/
            entriesPerFile[file]!
      else
        visibleTextLength(c.HtmlContent),
  ];
}

/// Pages a chapter with [textLength] visible characters counts as once read.
///
/// Rounds to the nearest page, with a minimum of one so a short or image-only
/// section the reader spent time on still counts, as any PDF page does.
int epubChapterPages(int textLength) {
  return math.max(1, (textLength / epubCharsPerPage).round());
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
  } else {
    var end = 0;
    for (var i = 0; i < lengths.length; i++) {
      end += lengths[i];
      if (end >= target) {
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
