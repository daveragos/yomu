/// Where a PDF highlight sits: character offsets into the structured text of
/// its first and last pages.
///
/// Stored in `Highlight.position` as
/// `'<startPage>:pdf:<startIndex>:<endPage>:<endIndex>'`. Pages are 0-based
/// (the start page is also the highlight's `chapterIndex`) and the end index
/// is exclusive.
class PdfHighlightAnchor {
  const PdfHighlightAnchor({
    required this.startPage,
    required this.startIndex,
    required this.endPage,
    required this.endIndex,
  });

  final int startPage;
  final int startIndex;
  final int endPage;
  final int endIndex;

  static const _tag = 'pdf';

  static PdfHighlightAnchor? tryParse(String position) {
    final parts = position.split(':');
    if (parts.length != 5 || parts[1] != _tag) return null;
    final values = [
      parts[0],
      parts[2],
      parts[3],
      parts[4],
    ].map(int.tryParse).toList();
    if (values.any((v) => v == null || v < 0)) return null;
    final anchor = PdfHighlightAnchor(
      startPage: values[0]!,
      startIndex: values[1]!,
      endPage: values[2]!,
      endIndex: values[3]!,
    );
    return _compare(
              anchor.startPage,
              anchor.startIndex,
              anchor.endPage,
              anchor.endIndex,
            ) <
            0
        ? anchor
        : null;
  }

  String format() => '$startPage:$_tag:$startIndex:$endPage:$endIndex';

  bool get isSinglePage => startPage == endPage;

  bool coversPage(int page) => page >= startPage && page <= endPage;

  /// Whether [other] lies entirely inside this anchor.
  bool contains(PdfHighlightAnchor other) =>
      _compare(startPage, startIndex, other.startPage, other.startIndex) <= 0 &&
      _compare(endPage, endIndex, other.endPage, other.endIndex) >= 0;

  static int _compare(int pageA, int indexA, int pageB, int indexB) =>
      pageA != pageB ? pageA.compareTo(pageB) : indexA.compareTo(indexB);

  /// The `[start, end)` range this highlight covers on [page], whose structured
  /// text is [pageText].
  ///
  /// [highlightText] is the text saved with the highlight. When the stored
  /// offsets no longer point at it (say a newer PDF engine splits the page
  /// text differently), a single-page highlight is looked up by its text
  /// instead, picking the match nearest the old offset. Returns null when the
  /// text can't be found.
  ({int start, int end})? rangeOnPage(
    int page,
    String pageText,
    String highlightText,
  ) {
    if (!coversPage(page)) return null;
    final start = page == startPage ? startIndex : 0;
    final end = page == endPage ? endIndex : pageText.length;
    if (start < end && end <= pageText.length) {
      final segment = _normalize(pageText.substring(start, end));
      if (segment.isNotEmpty && _normalize(highlightText).contains(segment)) {
        return (start: start, end: end);
      }
    }
    if (!isSinglePage) return null;
    return _relocate(pageText, highlightText, startIndex);
  }

  /// Finds [text] in a page's text, preferring the match nearest [near].
  static ({int start, int end})? find(
    String pageText,
    String text, {
    int near = 0,
  }) => _relocate(pageText, text, near);

  static String _normalize(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static ({int start, int end})? _relocate(
    String pageText,
    String text,
    int near,
  ) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (words.isEmpty) return null;
    ({int start, int end})? best;
    for (final m in RegExp(words.join(r'\s*')).allMatches(pageText)) {
      if (m.end <= m.start) continue;
      if (best == null || (m.start - near).abs() < (best.start - near).abs()) {
        best = (start: m.start, end: m.end);
      }
    }
    return best;
  }
}
