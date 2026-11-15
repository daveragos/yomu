import 'dart:math' as math;

/// A horizontal band of a chapter's laid-out content that must stay on one
/// page: a line of text (with its share of line spacing) or a picture.
class ContentBand {
  const ContentBand(this.top, this.bottom);

  final double top;
  final double bottom;

  double get height => bottom - top;

  @override
  String toString() => 'ContentBand($top–$bottom)';
}

/// Where each page of a chapter starts, in the chapter's content
/// coordinates (one tall column of text, laid out once).
class ChapterPages {
  ChapterPages._(this.starts, this.contentHeight, this.pageHeight);

  /// A chapter that fits on one page (or has no layout yet).
  ChapterPages.single({required this.contentHeight, required this.pageHeight})
    : starts = const [0];

  /// Top of each page; the first is always 0.
  final List<double> starts;
  final double contentHeight;

  /// Height of the text area of a page.
  final double pageHeight;

  int get count => starts.length;
  int get last => starts.length - 1;

  /// Bottom of [page]: where the next page starts, so a line that didn't
  /// fit is not shown half-cut at the bottom. The last page ends with the
  /// chapter, or a page's height down when only trailing margin is left.
  double endOf(int page) => page < last
      ? starts[page + 1]
      : math.max(
          math.min(contentHeight, starts[page] + pageHeight),
          starts[page],
        );

  /// The page that shows content offset [y].
  int pageAt(double y) {
    var low = 0;
    var high = last;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (starts[mid] <= y) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// Position of [page] as the fraction the reader stores for a chapter,
  /// the same number scroll mode stores (`pixels / maxScrollExtent`), so a
  /// place saved in one mode opens at the same text in the other. The last
  /// page is 1: the chapter has been read to its end.
  double progressOf(int page) {
    if (page >= last) return 1;
    final scrollable = contentHeight - pageHeight;
    if (scrollable <= 0) return 1;
    return (starts[page] / scrollable).clamp(0.0, 1.0);
  }

  /// The page holding the place [progress] (see [progressOf]) points at.
  int pageForProgress(double progress) {
    if (progress >= 0.999) return last;
    if (progress <= 0) return 0;
    final scrollable = math.max(contentHeight - pageHeight, 0.0);
    // A hair past the point, so a progress that is exactly a page's start
    // opens that page rather than the one before it.
    return pageAt(progress * scrollable + 1);
  }

  /// The part of the chapter on [page], as fractions of its height.
  (double, double) seenFraction(int page) {
    if (contentHeight <= 0) return (0, 1);
    return (
      (starts[page] / contentHeight).clamp(0.0, 1.0),
      // The last page reads the chapter to its end, margins included.
      page >= last ? 1.0 : (endOf(page) / contentHeight).clamp(0.0, 1.0),
    );
  }
}

/// How far past a page's end a line's box may reach without cutting what
/// is drawn: rounding, half a pixel.
double leadingTolerance(ContentBand band) => 0.5;

/// Joins bands that are the same line: runs of different sizes (a footnote
/// number, a bigger initial) or a picture standing in a line of text. Two
/// bands are one line when most of the smaller one overlaps the other.
List<ContentBand> _mergeLines(List<ContentBand> sorted) {
  final lines = <ContentBand>[];
  for (final band in sorted) {
    if (lines.isNotEmpty) {
      final line = lines.last;
      final overlap = math.min(line.bottom, band.bottom) - band.top;
      final smaller = math.min(line.height, band.height);
      if (overlap > smaller * 0.5) {
        lines[lines.length - 1] = ContentBand(
          math.min(line.top, band.top),
          math.max(line.bottom, band.bottom),
        );
        continue;
      }
    }
    lines.add(band);
  }
  return lines;
}

/// Cuts a chapter into pages of [pageHeight] without splitting a band.
///
/// A page ends at the top of the first band that would cross its bottom
/// edge. Only a band taller than a whole page (a very tall picture) is cut,
/// at the page edge, since it can't fit anywhere.
ChapterPages paginate(
  List<ContentBand> bands, {
  required double pageHeight,
  required double contentHeight,
}) {
  if (pageHeight <= 1 || contentHeight <= pageHeight + 0.5) {
    return ChapterPages.single(
      contentHeight: contentHeight,
      pageHeight: pageHeight,
    );
  }

  const epsilon = 0.5;
  final sorted = _mergeLines([
    for (final band in bands)
      if (band.bottom - band.top > epsilon) band,
  ]..sort((a, b) => a.top.compareTo(b.top)));

  // Tallest band, so the scan for bands crossing a page edge can start that
  // far above the edge and stop at it.
  var tallest = 0.0;
  var lastBottom = 0.0;
  for (final band in sorted) {
    tallest = math.max(tallest, band.height);
    lastBottom = math.max(lastBottom, band.bottom);
  }
  // Trailing margins after the last line don't earn a page of their own.
  final end = sorted.isEmpty ? contentHeight : math.min(contentHeight, lastBottom);

  final starts = <double>[0];
  var first = 0;
  var top = 0.0;
  while (top + pageHeight < end - epsilon) {
    final limit = top + pageHeight;

    // Skip bands that end before this page could be affected.
    while (first < sorted.length &&
        sorted[first].top < limit - tallest - epsilon) {
      first++;
    }

    var next = limit;
    for (var i = first; i < sorted.length; i++) {
      final band = sorted[i];
      if (band.top >= limit) break;
      final crosses = band.bottom > limit + epsilon;
      if (crosses && band.top > top + epsilon && band.top < next) {
        next = band.top;
      }
    }

    // A band that started above the break must end by it; one that ends
    // past it moves the break up to its top (bands from different nested
    // blocks can sit a little out of line).
    var moved = true;
    while (moved && next > top + epsilon) {
      moved = false;
      for (var i = first; i < sorted.length; i++) {
        final band = sorted[i];
        if (band.top >= next) break;
        if (band.top > top + epsilon &&
            band.bottom > next + leadingTolerance(band)) {
          next = band.top;
          moved = true;
          break;
        }
      }
    }

    // Never stand still: a band starting at the page top that is taller
    // than the page gets cut at the edge.
    if (next <= top + epsilon) next = limit;
    starts.add(next);
    top = next;
  }

  return ChapterPages._(
    List.unmodifiable(starts),
    contentHeight,
    pageHeight,
  );
}
