import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../models/book_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/highlight_model.dart';
import '../../../utils/pdf_highlight_anchor.dart';
import 'highlight_toolbar.dart';
import 'note_author_avatar.dart';
import 'note_marker.dart';
import 'share_quote_sheet.dart';

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
  final Function(String)? onLookup;

  /// Opens a highlight's note card, when it has something to show.
  final void Function(Highlight highlight)? onOpenNote;

  /// Replies per highlight uid, for the markers.
  final Map<String, int> replyCounts;

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
    this.onLookup,
    this.onOpenNote,
    this.replyCounts = const {},
    this.searcher,
  });

  @override
  State<ReadingPdfView> createState() => _ReadingPdfViewState();
}

/// A highlight's rectangles on one page, in PDF page coordinates.
class _PaintedHighlight {
  const _PaintedHighlight(
    this.highlight,
    this.rects,
    this.color, {
    required this.endsHere,
  });
  final Highlight highlight;
  final List<PdfRect> rects;
  final Color color;

  /// Whether the highlight ends on this page, where its marker goes.
  final bool endsHere;
}

class _ReadingPdfViewState extends State<ReadingPdfView> {
  /// Longest selection, in pages, that can become a highlight.
  static const _maxHighlightPages = 20;

  // Pointer tracking for tap detection. PdfViewer's internal gesture
  // recognizers consume taps in the gesture arena, so GestureDetector.onTap
  // never fires. Listener operates at the pointer level and bypasses the arena.
  DateTime? _pointerDownTime;
  Offset? _pointerDownPosition;

  /// Highlights by the 1-based pages they cover.
  Map<int, List<Highlight>> _highlightsByPage = {};

  /// Structured text of pages that have highlights, by 1-based page number.
  final Map<int, PdfPageText> _pageTexts = {};
  final Set<int> _loadingPages = {};
  final Set<int> _failedPages = {};

  /// What to paint on each 1-based page.
  final Map<int, List<_PaintedHighlight>> _painted = {};

  /// A highlight the reader tapped, whose menu is open at [_tappedAt].
  Highlight? _tappedHighlight;
  Offset? _tappedAt;

  @override
  void initState() {
    super.initState();
    _indexHighlights();
  }

  @override
  void didUpdateWidget(ReadingPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.highlights, oldWidget.highlights) ||
        !identical(widget.replyCounts, oldWidget.replyCounts)) {
      _indexHighlights();
      _painted.clear();
      _pageTexts.forEach((pageNumber, text) {
        final painted = _paintedForPage(pageNumber, text);
        if (painted.isNotEmpty) _painted[pageNumber] = painted;
      });
      if (_tappedHighlight != null &&
          !widget.highlights.any((h) => h.id == _tappedHighlight!.id)) {
        _tappedHighlight = null;
      }
      if (widget.controller.isReady) widget.controller.invalidate();
    }
  }

  void _indexHighlights() {
    final byPage = <int, List<Highlight>>{};
    for (final h in widget.highlights) {
      final anchor = PdfHighlightAnchor.tryParse(h.position);
      if (anchor == null ||
          anchor.endPage - anchor.startPage >= _maxHighlightPages) {
        continue;
      }
      for (var page = anchor.startPage; page <= anchor.endPage; page++) {
        (byPage[page + 1] ??= []).add(h);
      }
    }
    _highlightsByPage = byPage;
  }

  List<_PaintedHighlight> _paintedForPage(int pageNumber, PdfPageText text) {
    final result = <_PaintedHighlight>[];
    for (final h in _highlightsByPage[pageNumber] ?? const <Highlight>[]) {
      final anchor = PdfHighlightAnchor.tryParse(h.position)!;
      final range = anchor.rangeOnPage(pageNumber - 1, text.fullText, h.text);
      if (range == null) continue;
      final rects = PdfPageTextRange(
        pageText: text,
        start: range.start,
        end: range.end,
      ).enumerateFragmentBoundingRects().map((r) => r.bounds).toList();
      if (rects.isEmpty) continue;
      result.add(
        _PaintedHighlight(
          h,
          rects,
          _parseColor(h.color),
          endsHere: anchor.endPage == pageNumber - 1,
        ),
      );
    }
    return result;
  }

  void _loadPageText(PdfPage page) {
    final pageNumber = page.pageNumber;
    if (_failedPages.contains(pageNumber) || !_loadingPages.add(pageNumber)) {
      return;
    }
    page
        .loadStructuredText(ensureLoaded: true)
        .then((text) {
          if (!mounted) return;
          _pageTexts[pageNumber] = text;
          final painted = _paintedForPage(pageNumber, text);
          if (painted.isEmpty) {
            _painted.remove(pageNumber);
          } else {
            _painted[pageNumber] = painted;
            if (widget.controller.isReady) widget.controller.invalidate();
          }
        })
        .catchError((Object e) {
          debugPrint('Could not load text of page $pageNumber: $e');
          _failedPages.add(pageNumber);
        })
        .whenComplete(() => _loadingPages.remove(pageNumber));
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final pageNumber = page.pageNumber;
    if (!_highlightsByPage.containsKey(pageNumber)) return;
    if (!_pageTexts.containsKey(pageNumber)) {
      _loadPageText(page);
      return;
    }
    for (final painted in _painted[pageNumber] ?? const <_PaintedHighlight>[]) {
      final fill = Paint()..color = painted.color.withValues(alpha: 0.35);
      final underline = Paint()..color = painted.color;
      for (final r in painted.rects) {
        final rect = r.toRectInDocument(page: page, pageRect: pageRect);
        canvas.drawRect(rect, fill);
        final thickness = (rect.height * 0.08).clamp(0.5, 2.0);
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left,
            rect.bottom - thickness,
            rect.right,
            rect.bottom,
          ),
          underline,
        );
      }
      final marker = _markerRect(painted, (r) {
        return r.toRectInDocument(page: page, pageRect: pageRect);
      });
      if (marker != null) _paintMarker(canvas, marker, painted.highlight);
    }
  }

  bool _hasMarker(Highlight h) =>
      widget.onOpenNote != null &&
      NoteMarker.shows(h, widget.replyCounts[h.uid] ?? 0);

  /// Where a highlight's marker sits: just after its last line, sized to it.
  /// [toDocument] places page rectangles in the document.
  Rect? _markerRect(
    _PaintedHighlight painted,
    Rect Function(PdfRect) toDocument,
  ) {
    if (!painted.endsHere || !_hasMarker(painted.highlight)) return null;
    final last = toDocument(painted.rects.last);
    final size = (last.height * 0.9).clamp(6.0, 28.0);
    return Rect.fromLTWH(
      last.right + size * 0.2,
      last.center.dy - size / 2,
      size,
      size,
    );
  }

  void _paintMarker(Canvas canvas, Rect rect, Highlight h) {
    final replies = widget.replyCounts[h.uid] ?? 0;
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()..color = noteAuthorColor(h.sharedBy).withValues(alpha: 0.92),
    );
    final icon = NoteMarker.iconFor(h, replies);
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: rect.width * 0.62,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(
      canvas,
      rect.center - Offset(glyph.width / 2, glyph.height / 2),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0xF1C40F));
  }

  /// The highlight under a point in the viewer, if any.
  Highlight? _highlightAt(Offset localPosition) {
    final controller = widget.controller;
    if (!controller.isReady || _painted.isEmpty) return null;
    final documentPosition = controller.localToDocument(localPosition);
    for (final entry in _painted.entries) {
      Rect toDocument(PdfRect r) =>
          controller.calcRectForRectInsidePage(pageNumber: entry.key, rect: r);
      for (final painted in entry.value) {
        final marker = _markerRect(painted, toDocument);
        if (marker != null &&
            marker.inflate(marker.width * 0.6).contains(documentPosition)) {
          return painted.highlight;
        }
        for (final r in painted.rects) {
          if (toDocument(r).inflate(4).contains(documentPosition)) {
            return painted.highlight;
          }
        }
      }
    }
    return null;
  }

  /// A saved highlight that fully contains the current selection, so the
  /// menu edits it instead of stacking a new one on top.
  Highlight? _highlightContaining(PdfHighlightAnchor selection) {
    for (final h
        in _highlightsByPage[selection.startPage + 1] ?? const <Highlight>[]) {
      final anchor = PdfHighlightAnchor.tryParse(h.position)!;
      if (anchor.contains(selection)) return h;
    }
    return null;
  }

  static String _cleanText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  void _showTooLong() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Select a shorter passage to highlight it.'),
        ),
      );
  }

  void _openNoteEditor({
    Highlight? existing,
    String? text,
    PdfHighlightAnchor? anchor,
  }) {
    showHighlightNoteSheet(
      context,
      settings: widget.settings,
      existing: existing,
      onSave: (result) {
        final color = result.color ?? existing?.color ?? defaultHighlightColor;
        if (existing != null) {
          widget.onHighlight(
            existing.copyWith(
              note: result.markdown,
              color: color,
              audioFile: result.audioFile,
              audioDurationMs: result.audioDurationMs,
              audioWaveform: result.audioWaveform,
            ),
          );
          return;
        }
        widget.onHighlight(
          Highlight(
            bookId: 0,
            chapterIndex: anchor!.startPage,
            text: text!,
            note: result.markdown,
            color: color,
            createdAt: DateTime.now(),
            position: anchor.format(),
            audioFile: result.audioFile,
            audioDurationMs: result.audioDurationMs,
            audioWaveform: result.audioWaveform,
          ),
        );
      },
    );
  }

  void _share(String text) {
    ShareQuoteSheet.show(
      context,
      text: text,
      bookTitle: widget.book.title,
      bookAuthor: widget.book.author,
    );
  }

  void _lookup(String text) {
    final word = text.trim().split(RegExp(r'\s+')).first;
    if (word.isNotEmpty) widget.onLookup?.call(word);
  }

  /// Menu for selected text, placed by pdfrx next to the selection.
  Widget? _buildSelectionMenu(
    BuildContext menuContext,
    PdfViewerContextMenuBuilderParams params,
  ) {
    if (params.contextMenuFor != PdfViewerPart.selectedText) return null;
    final delegate = params.textSelectionDelegate;
    final range = delegate.textSelectionPointRange;
    if (range == null) return null;

    final selection = PdfHighlightAnchor(
      startPage: range.start.text.pageNumber - 1,
      startIndex: range.start.index,
      endPage: range.end.text.pageNumber - 1,
      endIndex: range.end.index + 1,
    );
    final tooLong =
        selection.endPage - selection.startPage >= _maxHighlightPages;
    final existing = _highlightContaining(selection);

    Future<String> selectedText() async =>
        _cleanText(await delegate.getSelectedText());

    return HighlightToolbar(
      settings: widget.settings,
      onColor: (hex) async {
        if (existing != null) {
          widget.onHighlight(existing.copyWith(color: hex));
        } else if (tooLong) {
          _showTooLong();
        } else {
          final text = await selectedText();
          if (text.isNotEmpty) {
            widget.onHighlight(
              Highlight(
                bookId: 0,
                chapterIndex: selection.startPage,
                text: text,
                color: hex,
                createdAt: DateTime.now(),
                position: selection.format(),
              ),
            );
          }
        }
        await delegate.clearTextSelection();
      },
      onRemove: existing == null
          ? null
          : () {
              widget.onDeleteHighlight(existing.id!);
              delegate.clearTextSelection();
            },
      onNote: () async {
        final text = existing == null ? await selectedText() : null;
        await delegate.clearTextSelection();
        if (!mounted) return;
        if (existing != null) {
          _openNoteEditor(existing: existing);
        } else if (tooLong) {
          _showTooLong();
        } else if (text != null && text.isNotEmpty) {
          _openNoteEditor(text: text, anchor: selection);
        }
      },
      onPlayVoiceNote: existing != null && existing.hasAudio
          ? () {
              delegate.clearTextSelection();
              showVoiceNoteSheet(
                context,
                settings: widget.settings,
                highlight: existing,
              );
            }
          : null,
      onCopy: () => delegate.copyTextSelection(),
      onLookup: widget.onLookup == null
          ? null
          : () async {
              final text = await selectedText();
              await delegate.clearTextSelection();
              _lookup(text);
            },
      onShare: () async {
        final text = await selectedText();
        await delegate.clearTextSelection();
        if (mounted) _share(text);
      },
    );
  }

  void _dismissTapped() {
    if (_tappedHighlight != null) {
      setState(() {
        _tappedHighlight = null;
        _tappedAt = null;
      });
    }
  }

  void _handleTap(Offset localPosition) {
    if (_tappedHighlight != null) {
      _dismissTapped();
      return;
    }
    final controller = widget.controller;
    // A tap while text is selected only clears the selection (pdfrx does
    // that), and taps on the selection menu land here too.
    if (controller.isReady &&
        controller.textSelectionDelegate.hasSelectedText) {
      return;
    }
    final hit = _highlightAt(localPosition);
    if (hit != null && _hasMarker(hit)) {
      widget.onOpenNote!(hit);
      return;
    }
    if (hit != null) {
      setState(() {
        _tappedHighlight = hit;
        _tappedAt = localPosition;
      });
      return;
    }
    widget.onHideControls();
  }

  /// Menu for a highlight the reader tapped.
  Widget _buildTappedMenu(BoxConstraints constraints) {
    final h = _tappedHighlight!;
    final at = _tappedAt!;
    final left = (at.dx - HighlightToolbar.width / 2)
        .clamp(
          8.0,
          math.max(8.0, constraints.maxWidth - HighlightToolbar.width - 8),
        )
        .toDouble();
    var top = at.dy - HighlightToolbar.height - 16;
    if (top < 8) top = at.dy + 16;

    return Positioned(
      left: left,
      top: top,
      child: HighlightToolbar(
        settings: widget.settings,
        onColor: (hex) {
          _dismissTapped();
          widget.onHighlight(h.copyWith(color: hex));
        },
        onRemove: () {
          _dismissTapped();
          widget.onDeleteHighlight(h.id!);
        },
        onNote: () {
          _dismissTapped();
          _openNoteEditor(existing: h);
        },
        onPlayVoiceNote: h.hasAudio
            ? () {
                _dismissTapped();
                showVoiceNoteSheet(
                  context,
                  settings: widget.settings,
                  highlight: h,
                );
              }
            : null,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: h.text));
          _dismissTapped();
        },
        onLookup: widget.onLookup == null
            ? null
            : () {
                _dismissTapped();
                _lookup(h.text);
              },
        onShare: () {
          _dismissTapped();
          _share(h.text);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget pdfViewer = PdfViewer.file(
      widget.book.filePath,
      controller: widget.controller,

      params: PdfViewerParams(
        backgroundColor: widget.settings.backgroundColor,
        // Themes recolour only the page images, so highlights, the selection
        // and the selection menu keep their real colours.
        pageImageColorFilter: _getPdfColorFilter(widget.settings.theme),

        onViewerReady: widget.onViewerReady,
        textSelectionParams: const PdfTextSelectionParams(),
        buildContextMenu: _buildSelectionMenu,
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
        sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
          maxScale: widget.settings.lockState != ReaderLockState.none
              ? (widget.controller.isReady
                    ? widget.controller.currentZoom
                    : 1.0)
              : 8.0,
          minScale: widget.settings.lockState != ReaderLockState.none
              ? (widget.controller.isReady
                    ? widget.controller.currentZoom
                    : 1.0)
              : 0.1,
        ),
        panEnabled: true,
        scaleEnabled: widget.settings.lockState == ReaderLockState.none,
        panAxis: widget.settings.lockState == ReaderLockState.all
            ? PanAxis.vertical
            : PanAxis.free,
        pagePaintCallbacks: [
          _paintHighlights,
          if (widget.searcher != null)
            widget.searcher!.pageTextMatchPaintCallback,
        ],
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

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              _pointerDownTime = DateTime.now();
              _pointerDownPosition = event.localPosition;
              widget.onInteraction();
            },
            onPointerMove: (event) {
              final down = _pointerDownPosition;
              if (_tappedHighlight != null &&
                  down != null &&
                  (event.localPosition - down).distance >= 20) {
                _dismissTapped();
              }
            },
            onPointerUp: (event) {
              if (_pointerDownTime == null || _pointerDownPosition == null) {
                return;
              }
              final elapsed = DateTime.now().difference(_pointerDownTime!);
              final distance =
                  (event.localPosition - _pointerDownPosition!).distance;

              // Short tap: under 300ms and minimal movement (not a scroll/pan)
              if (elapsed < const Duration(milliseconds: 300) &&
                  distance < 20) {
                _handleTap(event.localPosition);
              }
              _pointerDownTime = null;
              _pointerDownPosition = null;
            },
            child: Container(
              color: widget.settings.backgroundColor,
              child: pdfViewer,
            ),
          ),
          if (_tappedHighlight != null) _buildTappedMenu(constraints),
        ],
      ),
    );
  }

  /// Recolours page images for the reading theme; null leaves them as is.
  ColorFilter? _getPdfColorFilter(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.darkBlue:
        // Use difference with a calculated "pivot" color to map white to dark and black to light.
        // Target background: #1A2744 (26, 39, 68) -> Pivot: (229, 216, 187) -> 0xFFE5D8BB
        return const ColorFilter.mode(Color(0xFFE5D8BB), BlendMode.difference);
      case ReaderTheme.black:
        // Pure inversion: White (255) -> Black (0), Black (0) -> White (255)
        return const ColorFilter.mode(Colors.white, BlendMode.difference);
      case ReaderTheme.cream:
        // Dim/Cream: Multiply with the target color
        return const ColorFilter.mode(Color(0xFFF5F0E1), BlendMode.multiply);
      case ReaderTheme.white:
        return null;
    }
  }
}
