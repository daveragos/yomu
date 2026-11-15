import 'package:flutter/foundation.dart';

import 'paged_chapter.dart';

/// The page a chapter shown as pages is on, for the footer.
@immutable
class ChapterPagePosition {
  const ChapterPagePosition(this.page, this.count);

  /// 1-based.
  final int page;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ChapterPagePosition && other.page == page && other.count == count;

  @override
  int get hashCode => Object.hash(page, count);
}

/// Connects the reader screen to the chapter on screen when an EPUB is
/// read as pages, so keys, the desktop gutters and auto page turn can turn
/// its pages, and the footer can show where in the chapter you are.
class EpubPageTurner {
  PagedChapterController? _current;

  /// Page in the current chapter; null when the book is scrolled.
  final ValueNotifier<ChapterPagePosition?> position = ValueNotifier(null);

  bool get isActive => _current != null;

  /// The chapter now being read.
  void attach(PagedChapterController controller) => _current = controller;

  void detach(PagedChapterController controller) {
    if (_current != controller) return;
    _current = null;
    position.value = null;
  }

  /// One page forward (1) or back (-1), across chapters. False when the
  /// book has no page that way or no chapter is attached.
  bool turn(int direction) => _current?.turn(direction) ?? false;

  void dispose() => position.dispose();
}
