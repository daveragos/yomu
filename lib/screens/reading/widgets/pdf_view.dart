import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/highlight_model.dart';

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
  final List<Highlight> highlights;
  final Function(Highlight) onHighlight;
  final Function(int) onDeleteHighlight;

  final ValueNotifier<double> scrollProgressNotifier;

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
    required this.scrollProgressNotifier,
    required this.highlights,
    required this.onHighlight,
    required this.onDeleteHighlight,
    this.searcher,
  });

  @override
  State<ReadingPdfView> createState() => _ReadingPdfViewState();
}

class _ReadingPdfViewState extends State<ReadingPdfView> {
  // For dark themes (darkBlue/black), we defer the BlendMode.difference color
  // filter until the PDF viewer reports it is ready. This avoids applying the
  // filter before the platform texture has rendered its first frame.
  bool _filterReady = false;

  // Pointer tracking for tap detection. PdfViewer's internal gesture
  // recognizers consume taps in the gesture arena, so GestureDetector.onTap
  // never fires. Listener operates at the pointer level and bypasses the arena.
  DateTime? _pointerDownTime;
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
    // Light themes don't use BlendMode.difference, so the filter is safe immediately.
    // We also consider it "ready" if the controller already reports a document is loaded.
    if (widget.settings.theme == ReaderTheme.white ||
        widget.settings.theme == ReaderTheme.cream ||
        widget.controller.isReady) {
      _filterReady = true;
    }
  }

  @override
  void didUpdateWidget(ReadingPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.theme != oldWidget.settings.theme) {
      // Manual theme change or settings updated — safe to apply.
      _filterReady = true;
    }
  }

  void _onViewerReadyInternal(PdfDocument document, PdfViewerController controller) {
    if (!_filterReady && mounted) {
      // Small delay to ensure the platform view has painted its first frame
      // before applying a complex blend mode (like Difference).
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _filterReady = true;
          });
        }
      });
    }
    widget.onViewerReady(document, controller);
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = _getPdfColorFilter(widget.settings.theme);

    Widget pdfViewer = PdfViewer.file(
      widget.book.filePath,
      controller: widget.controller,

      params: PdfViewerParams(
        // Maintain a white background so that the transparent parts of the PDF
        // are treated as white pages before the color filter is applied.
        // The matrix filters map white to the target theme background.
        backgroundColor: Colors.white,

        onViewerReady: _onViewerReadyInternal,
        enableTextSelection: true,
        margin: 4.0,
        pageDropShadow: const BoxShadow(
          color: Colors.black12,
          blurRadius: 4.0,
          spreadRadius: 1.0,
          offset: Offset(0, 2),
        ),
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerDownTime = DateTime.now();
        _pointerDownPosition = event.position;
        widget.onInteraction();
      },
      onPointerUp: (event) {
        if (_pointerDownTime == null || _pointerDownPosition == null) return;
        final elapsed = DateTime.now().difference(_pointerDownTime!);
        final distance = (event.position - _pointerDownPosition!).distance;

        // Short tap: under 300ms and minimal movement (not a scroll/pan)
        if (elapsed < const Duration(milliseconds: 300) && distance < 20) {
          widget.onHideControls();
        }
        _pointerDownTime = null;
        _pointerDownPosition = null;
      },
      child: Container(
        color: widget.settings.backgroundColor,
        // Always wrap in ColorFiltered to avoid reparenting the PdfViewer when theme changes.
        child: AnimatedOpacity(
          opacity: _filterReady ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeIn,
          child: ColorFiltered(
            key: ValueKey(widget.settings.theme),
            colorFilter: colorFilter,
            child: pdfViewer,
          ),
        ),
      ),
    );
  }

  ColorFilter _getPdfColorFilter(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.darkBlue:
        // Use difference with a calculated "pivot" color to map white to dark and black to light.
        // This is much more compatible than matrices with negative coefficients.
        // Target background: #1A2744 (26, 39, 68) -> Pivot: (229, 216, 187) -> 0xFFE5D8BB
        return const ColorFilter.mode(Color(0xFFE5D8BB), BlendMode.difference);
      case ReaderTheme.black:
        // Pure inversion: White (255) -> Black (0), Black (0) -> White (255)
        return const ColorFilter.mode(Colors.white, BlendMode.difference);
      case ReaderTheme.cream:
        // Dim/Cream: Multiply with the target color
        return const ColorFilter.mode(Color(0xFFF5F0E1), BlendMode.multiply);
      case ReaderTheme.white:
        // Identity matrix - does nothing
        return const ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }
}
