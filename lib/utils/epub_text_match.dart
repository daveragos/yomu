/// How the EPUB reader finds a highlight's passage in a chapter's HTML. Shared
/// by the chapter view (to draw highlights) and by placing notes that came
/// from another copy of the book, so both count occurrences the same way.
library;

/// The part of a chapter's HTML that gets rendered.
String cleanChapterHtml(String html) {
  if (html.isEmpty) return html;
  html = html.replaceAll(RegExp(r'<\?xml[^>]*\?>'), '');
  html = html.replaceAll(RegExp(r'<!DOCTYPE[^>]*>'), '');
  html = html.replaceAll(RegExp(r'<svg', caseSensitive: false), '<div');
  html = html.replaceAll(RegExp(r'</svg>', caseSensitive: false), '</div>');
  final bodyRegex = RegExp(
    r'(<body[^>]*>.*?</body>)',
    caseSensitive: false,
    dotAll: true,
  );
  final bodyMatch = bodyRegex.firstMatch(html);
  if (bodyMatch != null) return bodyMatch.group(1) ?? html;
  if (!html.toLowerCase().contains('<body')) return '<body>$html</body>';
  return html;
}

/// Matches [text] in HTML, lenient with whitespace, entities and tags
/// between words, and never starting inside a tag.
RegExp highlightPattern(String text) {
  final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
  const wsPattern = r'(?:\s|&nbsp;|&zwj;|&#160;|&#xa0;|&#x20;|<[^>]+>)+';
  final escapedText = RegExp.escape(normalizedText).replaceAll(' ', wsPattern);
  return RegExp('(?![^<]*>)$escapedText', caseSensitive: false);
}

/// Where a passage was found: its chapter, which occurrence it is there,
/// and roughly how far into the chapter (0 to 1).
class EpubTextLocation {
  const EpubTextLocation(this.chapter, this.occurrence, this.ratio);
  final int chapter;
  final int occurrence;
  final double ratio;

  /// The highlight position string the reader understands.
  String get position => '$chapter:exact:$occurrence:$ratio';
}

/// Finds [text] in [chapterHtml] (raw chapter HTML, one per chapter),
/// starting at chapter [near] and working outwards. In the chapter nearest
/// [near], picks the occurrence closest to [nearRatio].
EpubTextLocation? findInChapters(
  List<String> chapterHtml,
  String text, {
  int near = 0,
  double nearRatio = 0,
}) {
  if (text.trim().isEmpty || chapterHtml.isEmpty) return null;
  final pattern = highlightPattern(text.trim());
  final start = near.clamp(0, chapterHtml.length - 1);
  for (var step = 0; step < chapterHtml.length * 2; step++) {
    final offset = (step + 1) ~/ 2 * (step.isOdd ? 1 : -1);
    final chapter = start + offset;
    if (chapter < 0 || chapter >= chapterHtml.length) continue;
    final content = cleanChapterHtml(chapterHtml[chapter]);
    final matches = pattern.allMatches(content).toList();
    if (matches.isEmpty) continue;
    var best = 0;
    if (chapter == start) {
      var bestDistance = double.infinity;
      for (var i = 0; i < matches.length; i++) {
        final distance = (matches[i].start / content.length - nearRatio).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = i;
        }
      }
    }
    return EpubTextLocation(
      chapter,
      best,
      content.isEmpty ? 0 : matches[best].start / content.length,
    );
  }
  return null;
}
