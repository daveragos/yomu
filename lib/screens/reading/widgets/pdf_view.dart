import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';

class ReadingPdfView extends StatefulWidget {
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
  State<ReadingPdfView> createState() => _ReadingPdfViewState();
}

class _ReadingPdfViewState extends State<ReadingPdfView> {
  final _viewerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final colorFilter = _getPdfColorFilter(widget.settings.theme);

    Widget pdfViewer = PdfViewer.file(
      widget.book.filePath,
      key: _viewerKey,
      controller: widget.controller,
      params: PdfViewerParams(
        backgroundColor: widget.settings.backgroundColor,
        onViewerReady: widget.onViewerReady,
        enableTextSelection: false,
        margin: 1.0,
        pageDropShadow: null,
        interactionEndFrictionCoefficient: 0.000005,
        verticalCacheExtent: 3.0,
        maxImageBytesCachedOnMemory: 256 * 1024 * 1024,
        maxScale: widget.settings.lockState != ReaderLockState.none
            ? (widget.controller.isReady ? widget.controller.currentZoom : 1.0)
            : 8.0,
        minScale: widget.settings.lockState != ReaderLockState.none
            ? (widget.controller.isReady ? widget.controller.currentZoom : 1.0)
            : 0.1,
        panEnabled: true,
        scaleEnabled: widget.settings.lockState == ReaderLockState.none,
        panAxis: widget.settings.lockState == ReaderLockState.all
            ? PanAxis.vertical
            : PanAxis.free,
        pagePaintCallbacks: (widget.searcher != null)
            ? [
                (canvas, pageRect, page) {
                  widget.searcher!.pageTextMatchPaintCallback(
                    canvas,
                    pageRect,
                    page,
                  );
                },
              ]
            : null,
        onPageChanged: widget.onPageChanged,
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: widget.settings.textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load PDF',
                    style: TextStyle(
                      color: widget.settings.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The file may be corrupted or missing.',
                    style: TextStyle(
                      color: widget.settings.secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.toString().replaceAll('PdfException: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.settings.secondaryTextColor.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle &&
            widget.showControls) {
          widget.onHideControls();
        }
        return false;
      },
      child: Listener(
        onPointerDown: (_) => widget.onInteraction(),
        child: Container(
          color: widget.settings.backgroundColor,
          child: colorFilter != null
              ? ColorFiltered(colorFilter: colorFilter, child: pdfViewer)
              : pdfViewer,
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
