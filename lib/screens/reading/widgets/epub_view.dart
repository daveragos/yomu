import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' show EpubChapter, EpubBook;
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import './epub_chapter_page.dart';

class ReadingEpubView extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final List<EpubChapter> chapters;
  final EpubBook? epubBook;
  final PageController? pageController;
  final int currentChapterIndex;
  final bool shouldJumpToBottom;
  final double initialScrollProgress;
  final String? searchQuery;
  final ValueNotifier<double> pullDistanceNotifier;
  final ValueNotifier<bool> isPullingDownNotifier;
  final ValueNotifier<double> scrollProgressNotifier;
  final ValueNotifier<double> autoScrollSpeedNotifier;
  final bool showControls;
  final Function(int) onPageChanged;
  final VoidCallback onJumpedToBottom;
  final VoidCallback onJumpedToPosition;
  final VoidCallback onHideControls;

  const ReadingEpubView({
    super.key,
    required this.book,
    required this.settings,
    required this.chapters,
    required this.pageController,
    required this.currentChapterIndex,
    required this.shouldJumpToBottom,
    required this.initialScrollProgress,
    required this.pullDistanceNotifier,
    required this.isPullingDownNotifier,
    required this.scrollProgressNotifier,
    required this.autoScrollSpeedNotifier,
    required this.showControls,
    required this.onPageChanged,
    required this.onJumpedToBottom,
    required this.onJumpedToPosition,
    required this.onHideControls,
    this.searchQuery,
    this.epubBook,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty || pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: pageController,
      itemCount: chapters.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        return EpubChapterPage(
          index: index,
          chapter: chapters[index],
          settings: settings,
          shouldJumpToBottom: shouldJumpToBottom,
          initialScrollProgress: initialScrollProgress,
          onJumpedToBottom: onJumpedToBottom,
          onJumpedToPosition: onJumpedToPosition,
          pullDistanceNotifier: pullDistanceNotifier,
          isPullingDownNotifier: isPullingDownNotifier,
          scrollProgressNotifier: scrollProgressNotifier,
          showControls: showControls,
          onHideControls: onHideControls,
          pullTriggerDistance: 80.0,
          pullDeadzone: 8.0,
          chapters: chapters,
          pageController: pageController,
          autoScrollSpeedNotifier: autoScrollSpeedNotifier,
          searchQuery: searchQuery,
          epubBook: epubBook,
        );
      },
    );
  }
}
