import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/highlight_model.dart';
import 'pdf_selection_context_menu.dart';

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
    required this.highlights,
    required this.onHighlight,
    required this.onDeleteHighlight,
    this.searcher,
  });

  @override
  State<ReadingPdfView> createState() => _ReadingPdfViewState();
}

class _ReadingPdfViewState extends State<ReadingPdfView> {
  final _selectableRegionKey = GlobalKey<SelectableRegionState>();
  List<PdfTextRanges>? _selections;
  PdfDocument? _document;

  void _clearSelection() {
    _selectableRegionKey.currentState?.clearSelection();
    setState(() {
      _selections = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = _getPdfColorFilter(widget.settings.theme);

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
          child: ColorFiltered(
            colorFilter:
                colorFilter ??
                const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: PdfViewer.file(
              widget.book.filePath,
              controller: widget.controller,
              params: PdfViewerParams(
                backgroundColor: widget.settings.backgroundColor,
                onViewerReady: (document, controller) {
                  _document = document;
                  widget.onViewerReady(document, controller);
                },
                selectableRegionInjector: (context, child) {
                  return SelectionArea(key: _selectableRegionKey, child: child);
                },
                pagePaintCallbacks: [
                  (canvas, pageRect, page) {
                    widget.searcher?.pageTextMatchPaintCallback(
                      canvas,
                      pageRect,
                      page,
                    );

                    // Render highlights
                    for (final highlight in widget.highlights) {
                      if (highlight.position.contains(':')) {
                        final parts = highlight.position.split(':');
                        final pageNum = int.tryParse(parts[0]);
                        if (pageNum == page.pageNumber && parts.length > 1) {
                          final color = Color(
                            int.parse(
                              highlight.color.replaceFirst('#', '0xFF'),
                            ),
                          ).withValues(alpha: 0.5);
                          final paint = Paint()
                            ..color = color
                            ..style = PaintingStyle.fill;

                          // Parse rects from position: "pageNum:l,t,r,b;l,t,r,b"
                          final rectStrings = parts[1].split(';');
                          for (final rectStr in rectStrings) {
                            final coords = rectStr.split(',');
                            if (coords.length == 4) {
                              final rect = PdfRect(
                                double.parse(coords[0]),
                                double.parse(coords[1]),
                                double.parse(coords[2]),
                                double.parse(coords[3]),
                              );
                              canvas.drawRect(
                                rect.toRectInPageRect(
                                  page: page,
                                  pageRect: pageRect,
                                ),
                                paint,
                              );
                            }
                          }
                        }
                      }
                    }
                  },
                ],
                onPageChanged: widget.onPageChanged,
                onTextSelectionChange: (selections) {
                  setState(() {
                    _selections = selections;
                  });
                },
                viewerOverlayBuilder: (context, size, handle) {
                  if (widget.controller.isReady &&
                      _selections != null &&
                      _selections!.isNotEmpty &&
                      _document != null &&
                      !widget.showControls) {
                    final selection = _selections!.first;
                    final layout = widget.controller.layout;
                    final pageRect =
                        layout.pageLayouts[selection.pageNumber - 1];
                    final page = _document!.pages[selection.pageNumber - 1];
                    final rect = selection.bounds.toRectInPageRect(
                      page: page,
                      pageRect: pageRect,
                    );

                    return [
                      PdfSelectionContextMenu(
                        selections: _selections!,
                        position: rect,
                        onHighlight: (color) {
                          final selection = _selections!.first;
                          final fragments = selection.ranges
                              .expand(
                                (r) => r
                                    .toTextRangeWithFragments(
                                      selection.pageText,
                                    )!
                                    .fragments,
                              )
                              .toList();

                          final rects = fragments
                              .map(
                                (f) =>
                                    '${f.bounds.left},${f.bounds.top},${f.bounds.right},${f.bounds.bottom}',
                              )
                              .join(';');

                          final text = _selections!
                              .map(
                                (s) => s.ranges
                                    .map(
                                      (r) => s.pageText.fullText.substring(
                                        r.start,
                                        r.end,
                                      ),
                                    )
                                    .join(' '),
                              )
                              .join('\n');

                          widget.onHighlight(
                            Highlight(
                              bookId: widget.book.id!,
                              text: text,
                              color:
                                  '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                              position: '${selection.pageNumber}:$rects',
                              createdAt: DateTime.now(),
                            ),
                          );
                          _clearSelection();
                        },
                      ),
                    ];
                  }
                  return [];
                },
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
                            color: widget.settings.textColor.withValues(
                              alpha: 0.5,
                            ),
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
                              color: widget.settings.secondaryTextColor
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
