import '../models/highlight_model.dart';
import 'pdf_highlight_anchor.dart';

/// Reading order and places of annotations, for lists and walk-throughs.
class AnnotationOrder {
  /// Where in its chapter an EPUB highlight sits, 0 to 1. Positions look like
  /// `'3:exact:0:0.42'` or `'3:ratio:0.42'`; the scroll ratio comes last.
  static double epubRatio(Highlight h) =>
      double.tryParse(h.position.split(':').last) ?? 0;

  /// Sorts highlights the way they appear in the book.
  static List<Highlight> sorted(Iterable<Highlight> highlights, {
    required bool isPdf,
  }) => highlights.toList()..sort((a, b) => compare(a, b, isPdf: isPdf));

  static int compare(Highlight a, Highlight b, {required bool isPdf}) {
    final byChapter = a.chapterIndex.compareTo(b.chapterIndex);
    if (byChapter != 0) return byChapter;
    if (isPdf) {
      final ia = PdfHighlightAnchor.tryParse(a.position)?.startIndex ?? 0;
      final ib = PdfHighlightAnchor.tryParse(b.position)?.startIndex ?? 0;
      final byIndex = ia.compareTo(ib);
      if (byIndex != 0) return byIndex;
    } else {
      final byRatio = epubRatio(a).compareTo(epubRatio(b));
      if (byRatio != 0) return byRatio;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  /// "p. 12" for a PDF; the chapter's title (or "Chapter 3") for an EPUB.
  static String location(
    Highlight h, {
    required bool isPdf,
    List<String?> chapterTitles = const [],
  }) {
    if (isPdf) return 'p. ${h.chapterIndex + 1}';
    final title = h.chapterIndex >= 0 && h.chapterIndex < chapterTitles.length
        ? chapterTitles[h.chapterIndex]?.trim()
        : null;
    return title == null || title.isEmpty
        ? 'Chapter ${h.chapterIndex + 1}'
        : title;
  }
}
