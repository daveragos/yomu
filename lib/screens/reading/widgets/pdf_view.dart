import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';

class ReadingPdfView extends StatelessWidget {
  final Book book;
  final ReaderSettings settings;
  final PdfViewerController controller;
  final PdfTextSearcher? searcher;
  final Function(PdfDocument, PdfViewerController) onViewerReady;
  final Function(int?) onPageChanged;
  final VoidCallback onInteraction;
  final VoidCallback onHideControls;
  final bool showControls;

  const ReadingPdfView({
    super.key,
    required this.book,
    required this.settings,
    required this.controller,
    required this.onViewerReady,
    required this.onPageChanged,
    required this.onInteraction,
    required this.onHideControls,
    required this.showControls,
    this.searcher,
  });

  @override
  Widget build(BuildContext context) {
    final colorFilter = _getPdfColorFilter(settings.theme);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle &&
            showControls) {
          onHideControls();
        }
        return false;
      },
      child: Listener(
        onPointerDown: (_) => onInteraction(),
        child: Container(
          color: settings.backgroundColor,
          child: ColorFiltered(
            colorFilter:
                colorFilter ??
                const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: PdfViewer.file(
              book.filePath,
              controller: controller,
              params: PdfViewerParams(
                backgroundColor: settings.backgroundColor,
                onViewerReady: onViewerReady,
                pagePaintCallbacks: [
                  (canvas, pageRect, page) {
                    searcher?.pageTextMatchPaintCallback(
                      canvas,
                      pageRect,
                      page,
                    );
                  },
                ],
                onPageChanged: onPageChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ColorFilter? _getPdfColorFilter(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.darkBlue:
      case ReaderTheme.black:
        return const ColorFilter.matrix([
          -0.9,
          0,
          0,
          0,
          255,
          0,
          -0.9,
          0,
          0,
          255,
          0,
          0,
          -0.9,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ReaderTheme.cream:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ReaderTheme.white:
        return null;
    }
  }
}
