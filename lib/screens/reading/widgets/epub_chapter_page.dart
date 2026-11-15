import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:epub_view/epub_view.dart'
    show EpubChapter, EpubBook, EpubByteContentFile;
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/highlight_model.dart';
import 'share_quote_sheet.dart';
import 'highlight_toolbar.dart';
import 'note_marker.dart';
import '../../../utils/epub_text_match.dart';

class EpubChapterPage extends StatefulWidget {
  final int index;
  final bool isCurrentPage;

  /// Whether this chapter sits above the current one in the vertical pager,
  /// so it should open scrolled to its end (it slides in from the top).
  final bool opensAtEnd;
  final EpubChapter chapter;
  final ReaderSettings settings;
  final bool shouldJumpToBottom;
  final double initialScrollProgress;
  final VoidCallback onJumpedToBottom;
  final VoidCallback onJumpedToPosition;
  final ValueNotifier<double> pullDistanceNotifier;
  final ValueNotifier<bool> isPullingDownNotifier;
  final ValueNotifier<double> scrollProgressNotifier;
  final bool showControls;
  final VoidCallback onHideControls;
  final VoidCallback onToggleControls;
  final VoidCallback onInteraction;
  final double pullTriggerDistance;
  final double pullDeadzone;
  final List<EpubChapter> chapters;
  final PageController? pageController;
  final ValueNotifier<double> autoScrollSpeedNotifier;
  final String? searchQuery;
  final EpubBook? epubBook;
  final String? bookTitle;
  final String? bookAuthor;
  final List<Highlight> highlights;
  final Function(Highlight) onHighlight;
  final Function(int) onDeleteHighlight;
  final Function(String)? onLookup;

  /// Opens a highlight's note card, from the marker after it in the text.
  final void Function(Highlight highlight)? onOpenNote;

  /// Replies per highlight uid, for the markers.
  final Map<String, int> replyCounts;

  /// Called with the part of the chapter now on screen, as 0–1 fractions.
  final void Function(int chapter, double from, double to)? onContentSeen;

  const EpubChapterPage({
    super.key,
    required this.index,
    required this.isCurrentPage,
    this.opensAtEnd = false,
    required this.chapter,
    required this.settings,
    required this.shouldJumpToBottom,
    required this.initialScrollProgress,
    required this.onJumpedToBottom,
    required this.onJumpedToPosition,
    required this.pullDistanceNotifier,
    required this.isPullingDownNotifier,
    required this.scrollProgressNotifier,
    required this.showControls,
    required this.onHideControls,
    required this.onToggleControls,
    required this.onInteraction,
    required this.pullTriggerDistance,
    required this.pullDeadzone,
    required this.chapters,
    required this.pageController,
    required this.autoScrollSpeedNotifier,
    required this.highlights,
    required this.onHighlight,
    required this.onDeleteHighlight,
    this.onLookup,
    this.onOpenNote,
    this.replyCounts = const {},
    this.onContentSeen,
    this.searchQuery,
    this.epubBook,
    this.bookTitle,
    this.bookAuthor,
  });

  @override
  State<EpubChapterPage> createState() => _EpubChapterPageState();
}

class _EpubChapterPageState extends State<EpubChapterPage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isNavigating = false;
  bool _isInitialPositionRestored = false;

  /// Overscroll produced by the finger while it is still on the screen:
  /// positive past the end (next chapter), negative past the start
  /// (previous chapter). Momentum overscroll from a fling never counts.
  final ValueNotifier<double> _pullOffset = ValueNotifier(0.0);
  bool _pullArmed = false;
  int _activePointers = 0;

  /// Keeps the chapter pinned to its end while late content (decoded images)
  /// grows it, until the reader scrolls it themselves.
  bool _pinnedToEnd = false;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  String _processedHtml = '';
  SelectedContent? _selectedContent;
  final Map<String, Uint8List> _imageCache = {};
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Only the current chapter consumes the screen's one-shot position
    // requests; a chapter that is merely passing through the pager must not
    // jump (or acknowledge the request on the current chapter's behalf).
    final bool jumpRequested =
        widget.isCurrentPage && widget.shouldJumpToBottom;
    if (widget.opensAtEnd || jumpRequested) {
      _jumpToEnd(acknowledge: jumpRequested);
      _isInitialPositionRestored = true;
    } else if (widget.isCurrentPage && widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
    } else {
      _isInitialPositionRestored = true;
    }

    _ticker = createTicker((elapsed) {
      final speed = widget.autoScrollSpeedNotifier.value;
      if (speed > 0 && _scrollController.hasClients) {
        final deltaTime = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
        _lastElapsed = elapsed;

        if (deltaTime <= 0) return;

        final currentPos = _scrollController.offset;
        final maxPos = _scrollController.position.maxScrollExtent;
        if (currentPos < maxPos) {
          final increment = speed * 30.0 * deltaTime;
          _scrollController.jumpTo(currentPos + increment);
        }
      } else {
        _lastElapsed = elapsed;
      }
    });

    widget.autoScrollSpeedNotifier.addListener(_handleSpeedChange);
    if (widget.autoScrollSpeedNotifier.value > 0) {
      _ticker?.start();
    }
    _updateProcessedHtml();
  }

  void _handleSpeedChange() {
    if (widget.autoScrollSpeedNotifier.value > 0) {
      if (!(_ticker?.isActive ?? false)) {
        _ticker?.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  @override
  void didUpdateWidget(EpubChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _reportSeen(_scrollController.position);
        }
      });
    }
    // The chapter being left stays mounted until the page animation ends, so
    // position requests must only move the chapter that is now current.
    if (widget.isCurrentPage &&
        widget.shouldJumpToBottom &&
        !oldWidget.shouldJumpToBottom) {
      _jumpToEnd(acknowledge: true);
    } else if (widget.isCurrentPage &&
        widget.initialScrollProgress != oldWidget.initialScrollProgress &&
        widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
    } else if (widget.isCurrentPage && !oldWidget.isCurrentPage) {
      // The screen resets progress to 0 on a chapter change; report where
      // this chapter actually is (its end, when it was entered from below).
      WidgetsBinding.instance.addPostFrameCallback((_) => _publishProgress());
    }

    final bool bookChanged = !identical(widget.epubBook, oldWidget.epubBook);

    if (widget.chapter != oldWidget.chapter ||
        widget.settings.usePublisherDefaults !=
            oldWidget.settings.usePublisherDefaults ||
        widget.searchQuery != oldWidget.searchQuery ||
        widget.highlights != oldWidget.highlights ||
        widget.replyCounts != oldWidget.replyCounts ||
        bookChanged) {
      _updateProcessedHtml();
    }
  }

  void _updateProcessedHtml() {
    final book = widget.epubBook;
    final settings = widget.settings;
    final chapter = widget.chapter;

    String content = _cleanHtml(chapter.HtmlContent ?? '');

    // Inject highlight spans for saved highlights
    final chapterHighlights = widget.highlights
        .where((h) => h.chapterIndex == widget.index)
        .toList();
    chapterHighlights.sort((a, b) => b.text.length.compareTo(a.text.length));
    for (final highlight in chapterHighlights) {
      // Lenient with HTML whitespace and nested tags, never starting in a tag.
      final regex = highlightPattern(highlight.text);
      final rgba = _hexToRgba(highlight.color, 0.35);
      
      final matches = regex.allMatches(content).toList();
      if (matches.isEmpty) continue;

      int targetMatchIndex = 0;
      final parts = highlight.position.split(':');
      if (parts.length >= 3 && parts[1] == 'exact') {
        targetMatchIndex = int.tryParse(parts[2]) ?? 0;
      } else {
        double targetRatio = 0.0;
        if (parts.length >= 2) {
          targetRatio = double.tryParse(parts.last) ?? 0.0;
        }
        double minDistance = double.infinity;
        for (int i = 0; i < matches.length; i++) {
          final matchRatio = matches[i].start / content.length;
          final distance = (matchRatio - targetRatio).abs();
          if (distance < minDistance) {
            minDistance = distance;
            targetMatchIndex = i;
          }
        }
      }

      // A marker after the highlight opens its note card.
      final marker =
          widget.onOpenNote != null &&
              highlight.id != null &&
              NoteMarker.shows(
                highlight,
                widget.replyCounts[highlight.uid] ?? 0,
              )
          ? '<yomu-note data-id="${highlight.id}"></yomu-note>'
          : '';
      int currentMatchIndex = 0;
      content = content.replaceAllMapped(regex, (match) {
        final result = currentMatchIndex == targetMatchIndex
            ? '<span style="background-color: $rgba; border-bottom: 2px solid ${highlight.color};">${match.group(0)}</span>$marker'
            : match.group(0)!;
        currentMatchIndex++;
        return result;
      });
    }

    final query = widget.searchQuery;
    if (query != null && query.isNotEmpty) {
      final escapedQuery = RegExp.escape(query);
      final regex = RegExp('(?![^<]*>)$escapedQuery', caseSensitive: false);
      content = content.replaceAllMapped(regex, (match) {
        return '<span style="background-color: #2ECC71; color: #000000; border-radius: 2px; padding: 0 2px;">${match.group(0)}</span>';
      });
    }

    if (settings.usePublisherDefaults && book != null) {
      final cssFiles = book.Content?.Css;
      if (cssFiles != null && cssFiles.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.write('<style>');
        for (final cssFile in cssFiles.values) {
          final fileContent = cssFile.Content;
          if (fileContent != null) {
            buffer.write(fileContent);
          }
        }
        buffer.write('</style>');
        content = buffer.toString() + content;
      }
    }

    setState(() {
      _processedHtml = content;
    });
  }

  /// Scrolls to the end of the chapter after the first layout, and keeps it
  /// there while the content is still growing (see [_handleMetricsChange]).
  /// [acknowledge] tells the screen its jump-to-bottom request was handled.
  void _jumpToEnd({required bool acknowledge}) {
    _pinnedToEnd = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        if (_scrollController.offset != maxScroll) {
          _scrollController.jumpTo(maxScroll);
        }
      }
      if (acknowledge) widget.onJumpedToBottom();
      _publishProgress();
    });
  }

  bool _handleMetricsChange(ScrollMetricsNotification notification) {
    // Metrics change without scrolling on first layout and when a short
    // chapter fits on screen, so what's on screen is reported here too.
    if (notification.depth == 0) _reportSeen(notification.metrics);
    if (notification.depth == 0 &&
        _pinnedToEnd &&
        _activePointers == 0 &&
        _scrollController.hasClients) {
      final double maxScroll = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset < maxScroll) {
        _scrollController.jumpTo(maxScroll);
      }
    }
    return false;
  }

  void _publishProgress() {
    if (!mounted ||
        !widget.isCurrentPage ||
        !_isInitialPositionRestored ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final double progress = position.maxScrollExtent > 0
        ? (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0)
        : 1.0;
    widget.scrollProgressNotifier.value = progress;
  }

  void _checkAndJumpToPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll * widget.initialScrollProgress);
          setState(() => _isInitialPositionRestored = true);
          _reportSeen(_scrollController.position);
          widget.onJumpedToPosition();
        } else {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _scrollController.hasClients) {
              final double newMaxScroll =
                  _scrollController.position.maxScrollExtent;
              if (newMaxScroll > 0) {
                _scrollController.jumpTo(
                  newMaxScroll * widget.initialScrollProgress,
                );
              }
              setState(() => _isInitialPositionRestored = true);
              _reportSeen(_scrollController.position);
              widget.onJumpedToPosition();
            }
          });
        }
      }
    });
  }

  /// Reports the part of the chapter on screen, so only what was actually
  /// scrolled through counts as read. Skips positions the reader did not
  /// choose: before a saved position is restored or a jump to the bottom.
  void _reportSeen(ScrollMetrics metrics) {
    final onContentSeen = widget.onContentSeen;
    if (onContentSeen == null ||
        metrics.axis != Axis.vertical ||
        !metrics.hasContentDimensions ||
        !metrics.hasPixels ||
        !metrics.hasViewportDimension ||
        !widget.isCurrentPage ||
        !_isInitialPositionRestored ||
        widget.shouldJumpToBottom) {
      return;
    }
    final total = metrics.extentTotal;
    if (total <= 0) return;
    onContentSeen(
      widget.index,
      metrics.extentBefore / total,
      (metrics.extentBefore + metrics.extentInside) / total,
    );
  }

  @override
  void dispose() {
    widget.autoScrollSpeedNotifier.removeListener(_handleSpeedChange);
    _ticker?.dispose();
    _scrollController.dispose();
    _pullOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _activePointers++,
      onPointerUp: (_) => _handlePointerRelease(canNavigate: true),
      onPointerCancel: (_) => _handlePointerRelease(canNavigate: false),
      onPointerPanZoomStart: (_) => _activePointers++,
      onPointerPanZoomEnd: (_) => _handlePointerRelease(canNavigate: true),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleMetricsChange,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Stack(
            fit: StackFit.expand,
            children: [_buildScrollView(), _buildPullIndicator()],
          ),
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    _reportSeen(metrics);

    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _pinnedToEnd = false;
      if (widget.showControls) widget.onHideControls();
    }

    if (notification is ScrollUpdateNotification) {
      // dragDetails is only set while the finger moves the content; bounce
      // and fling frames leave it null, so momentum can't change chapter.
      _setPull(notification.dragDetails != null ? _overscrollOf(metrics) : 0);
    }

    final double progressValue = metrics.maxScrollExtent > 0
        ? (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0)
        : 1.0;

    if (widget.isCurrentPage && _isInitialPositionRestored) {
      if (progressValue != widget.scrollProgressNotifier.value) {
        widget.scrollProgressNotifier.value = progressValue;
        widget.onInteraction();
      }
    }

    if (metrics.pixels != 0) {
      widget.onInteraction();
    }
    return false;
  }

  static double _overscrollOf(ScrollMetrics metrics) {
    if (metrics.pixels > metrics.maxScrollExtent) {
      return metrics.pixels - metrics.maxScrollExtent;
    }
    if (metrics.pixels < metrics.minScrollExtent) {
      return metrics.pixels - metrics.minScrollExtent;
    }
    return 0;
  }

  bool _hasChapterInDirection(bool forward) => forward
      ? widget.index < widget.chapters.length - 1
      : widget.index > 0;

  void _setPull(double overscroll) {
    if (overscroll != 0 && !_hasChapterInDirection(overscroll > 0)) {
      overscroll = 0;
    }
    _pullOffset.value = overscroll;
    final bool armed = overscroll.abs() >= widget.pullTriggerDistance;
    if (armed && !_pullArmed) HapticFeedback.selectionClick();
    _pullArmed = armed;
  }

  /// Changes chapter the moment the finger lifts past the threshold, instead
  /// of waiting for the bounce-back to settle.
  void _handlePointerRelease({required bool canNavigate}) {
    if (_activePointers > 0) _activePointers--;
    if (_activePointers > 0) return;

    final double pull = _pullOffset.value;
    _setPull(0);
    if (canNavigate && pull.abs() >= widget.pullTriggerDistance) {
      _navigateToAdjacentChapter(forward: pull > 0);
    }
  }

  void _navigateToAdjacentChapter({required bool forward}) {
    final controller = widget.pageController;
    if (_isNavigating ||
        controller == null ||
        !controller.hasClients ||
        !_hasChapterInDirection(forward)) {
      return;
    }
    _isNavigating = true;
    HapticFeedback.mediumImpact();
    const duration = Duration(milliseconds: 450);
    const curve = Curves.easeOutCubic;
    final Future<void> animation = forward
        ? controller.nextPage(duration: duration, curve: curve)
        : controller.previousPage(duration: duration, curve: curve);
    animation.whenComplete(() {
      if (mounted) _isNavigating = false;
    });
  }

  Widget _buildPullIndicator() {
    return ValueListenableBuilder<double>(
      valueListenable: _pullOffset,
      builder: (context, pull, _) {
        final double distance = pull.abs();
        if (distance <= widget.pullDeadzone) return const SizedBox.shrink();

        final bool forward = pull > 0;
        final bool armed = distance >= widget.pullTriggerDistance;
        final double reveal = ((distance - widget.pullDeadzone) /
                (widget.pullTriggerDistance - widget.pullDeadzone))
            .clamp(0.0, 1.0);
        final EpubChapter target =
            widget.chapters[forward ? widget.index + 1 : widget.index - 1];
        final String direction = forward ? 'next' : 'previous';
        final Color color = armed
            ? widget.settings.textColor
            : widget.settings.secondaryTextColor;

        final indicator = Opacity(
          opacity: reveal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                forward ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                armed
                    ? 'Release for $direction chapter'
                    : 'Pull for $direction chapter',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (target.Title != null) ...[
                const SizedBox(height: 2),
                Text(
                  target.Title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.settings.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );

        return Positioned(
          left: 32,
          right: 32,
          top: forward ? null : 24,
          bottom: forward ? 24 : null,
          child: IgnorePointer(child: Center(child: indicator)),
        );
      },
    );
  }

  Widget _buildScrollView() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: SelectionArea(
                key: _contentKey,
                onSelectionChanged: (content) {
                  _selectedContent = content;
                },
                contextMenuBuilder: (context, selectableRegionState) {
                  return _buildHighlightMenu(context, selectableRegionState);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 100),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final title = widget.chapter.Title;
                            if (title != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Text(
                                  title.toUpperCase(),
                                  style: TextStyle(
                                    color: widget.settings.secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        Html(
                          key: ValueKey(
                            'epub_html_${widget.index}_${widget.chapter.Title ?? "none"}',
                          ),
                          data: _processedHtml,
                          onLinkTap: (url, attributes, element) {
                            if (url == null ||
                                url.isEmpty ||
                                widget.pageController == null) {
                              return;
                            }

                            String targetUrl = url;
                            while (targetUrl.startsWith('../')) {
                              targetUrl = targetUrl.substring(3);
                            }

                            final parts = targetUrl.split('#');
                            final targetFile = parts[0];
                            final anchor = parts.length > 1 ? parts[1] : null;

                            if (targetFile.isEmpty && anchor != null) {
                              for (int i = 0; i < widget.chapters.length; i++) {
                                final ch = widget.chapters[i];
                                if (ch.Anchor == anchor &&
                                    ch.ContentFileName ==
                                        widget.chapter.ContentFileName) {
                                  widget.pageController?.jumpToPage(i);
                                  return;
                                }
                              }
                              return;
                            }

                            int? targetIndex;
                            int? fileOnlyIndex;
                            for (int i = 0; i < widget.chapters.length; i++) {
                               final ch = widget.chapters[i];
                               final chapterFile = ch.ContentFileName ?? '';
                               if (chapterFile.isEmpty) continue;
                               final fileMatches =
                                   chapterFile == targetFile ||
                                   chapterFile.endsWith('/$targetFile') ||
                                   chapterFile.endsWith(targetFile);
                               if (!fileMatches) continue;

                               if (anchor != null &&
                                   anchor.isNotEmpty &&
                                   ch.Anchor == anchor) {
                                 targetIndex = i;
                                 break;
                               }
                               fileOnlyIndex ??= i;
                            }

                            targetIndex ??= fileOnlyIndex;
                            if (targetIndex != null) {
                              widget.pageController?.jumpToPage(targetIndex);
                            }
                          },
                          extensions: [
                            TagExtension(
                              tagsToExtend: {'yomu-note'},
                              builder: (extensionContext) {
                                final id = int.tryParse(
                                  extensionContext.attributes['data-id'] ?? '',
                                );
                                final highlight = widget.highlights
                                    .where((h) => h.id == id)
                                    .firstOrNull;
                                if (highlight == null ||
                                    widget.onOpenNote == null) {
                                  return const SizedBox.shrink();
                                }
                                return NoteMarker(
                                  highlight: highlight,
                                  replyCount:
                                      widget.replyCounts[highlight.uid] ?? 0,
                                  size: (widget.settings.textSize * 0.85)
                                      .clamp(14.0, 22.0),
                                  onTap: () => widget.onOpenNote!(highlight),
                                );
                              },
                            ),
                            TagExtension(
                              tagsToExtend: {"img", "image"},
                              builder: (extensionContext) {
                                final src = extensionContext.attributes['src'] ??
                                    extensionContext.attributes['href'] ??
                                    extensionContext.attributes['xlink:href'];

                                if (src == null || widget.epubBook == null) {
                                  return const SizedBox.shrink();
                                }

                                if (src.startsWith('data:image/')) {
                                  try {
                                    if (!_imageCache.containsKey(src)) {
                                      final parts = src.split(',');
                                      if (parts.length == 2) {
                                        _imageCache[src] = base64Decode(parts[1].trim());
                                      }
                                    }
                                    final bytes = _imageCache[src];
                                    if (bytes != null) {
                                      return ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width - 40,
                                        ),
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.scaleDown,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.medium,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    return const SizedBox.shrink();
                                  }
                                }

                                String path = Uri.decodeComponent(src);
                                path = path.split('?').first.split('#').first;
                                
                                while (path.startsWith('../')) {
                                  path = path.substring(3);
                                }
                                if (path.startsWith('/')) {
                                  path = path.substring(1);
                                }

                                final images = widget.epubBook?.Content?.Images;
                                if (images == null) return const SizedBox.shrink();

                                EpubByteContentFile? imageFile = images[path];

                                if (imageFile == null) {
                                  final fileName = path.split('/').last;
                                  for (final file in images.values) {
                                    if (file.FileName == fileName ||
                                        file.FileName == Uri.decodeComponent(fileName)) {
                                      imageFile = file;
                                      break;
                                    }
                                  }
                                }

                                if (imageFile != null) {
                                  if (!_imageCache.containsKey(path)) {
                                    final content = imageFile.Content;
                                    if (content != null) {
                                      _imageCache[path] = content is Uint8List
                                          ? content
                                          : Uint8List.fromList(content);
                                    }
                                  }
                                  
                                  final bytes = _imageCache[path];
                                  if (bytes != null) {
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width - 40,
                                      ),
                                      child: Image.memory(
                                        bytes,
                                        key: ValueKey('img_${path.hashCode}_${bytes.length}'),
                                        fit: BoxFit.scaleDown,
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                          style: {
                            "body": Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(widget.settings.textSize, Unit.px),
                              lineHeight: LineHeight(widget.settings.lineHeight, units: ""),
                              color: widget.settings.textColor,
                              textAlign: _convertTextAlign(widget.settings.textAlign),
                              fontFamily: widget.settings.typeface == 'System' ? null : widget.settings.typeface,
                            ),
                            "p": Style(
                              margin: Margins.only(bottom: 16),
                              lineHeight: LineHeight(widget.settings.lineHeight, units: ""),
                            ),
                            "h1": Style(
                              fontSize: FontSize(widget.settings.textSize * 1.5, Unit.px),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 24, bottom: 12),
                            ),
                            "h2": Style(
                              fontSize: FontSize(widget.settings.textSize * 1.3, Unit.px),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 20, bottom: 10),
                            ),
                            "h3": Style(
                              fontSize: FontSize(widget.settings.textSize * 1.1, Unit.px),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 16, bottom: 8),
                            ),
                            "blockquote": Style(
                              margin: Margins.only(left: 20, right: 20, bottom: 16),
                              padding: HtmlPaddings.only(left: 12),
                              border: Border(left: BorderSide(color: widget.settings.secondaryTextColor, width: 3)),
                            ),
                            "code": Style(
                              fontFamily: "monospace",
                              backgroundColor: widget.settings.textColor.withValues(alpha: 0.1),
                              padding: HtmlPaddings.symmetric(horizontal: 4),
                            ),
                            "pre": Style(
                              margin: Margins.only(bottom: 16),
                              padding: HtmlPaddings.all(12),
                              backgroundColor: widget.settings.textColor.withValues(alpha: 0.1),
                              fontFamily: "monospace",
                              display: Display.block,
                            ),
                            "img": Style(
                              width: Width(MediaQuery.of(context).size.width - 40, Unit.px),
                              alignment: Alignment.center,
                            ),
                            "image": Style(
                              width: Width(MediaQuery.of(context).size.width - 40, Unit.px),
                              alignment: Alignment.center,
                            ),
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }

  int? _findOccurrenceIndex(String selectedText, Offset primaryAnchor) {
    final RenderBox? contentBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null) return null;

    final List<RenderParagraph> paragraphs = [];
    void collectParagraphs(RenderObject node) {
      if (node is RenderParagraph) {
        if (node.text.toPlainText().isNotEmpty) paragraphs.add(node);
      }
      node.visitChildren(collectParagraphs);
    }
    collectParagraphs(contentBox);

    RenderParagraph? targetParagraph;
    double minDistance = double.infinity;

    for (final p in paragraphs) {
      final text = p.text.toPlainText();
      if (text.contains(selectedText)) {
        final bounds = p.paintBounds;
        final globalOffset = p.localToGlobal(Offset.zero);
        final globalBounds = globalOffset & bounds.size;
        
        double distance = 0.0;
        if (globalBounds.contains(primaryAnchor)) {
          distance = 0.0;
        } else {
          final center = globalBounds.center;
          distance = (center.dy - primaryAnchor.dy).abs() + (center.dx - primaryAnchor.dx).abs() * 0.1;
        }
        
        if (distance < minDistance) {
          minDistance = distance;
          targetParagraph = p;
        }
      }
    }

    if (targetParagraph == null) return null;

    int occurrenceIndex = 0;
    for (final p in paragraphs) {
      final text = p.text.toPlainText();
      if (p == targetParagraph) {
        final localOffset = p.globalToLocal(primaryAnchor);
        final textPos = p.getPositionForOffset(localOffset).offset;
        
        int bestMatchIndex = 0;
        int closestTextDistance = 999999;
        int searchIndex = 0;
        int localCount = 0;
        
        while (true) {
          searchIndex = text.indexOf(selectedText, searchIndex);
          if (searchIndex == -1) break;
          final dist = (searchIndex - textPos).abs();
          if (dist < closestTextDistance) {
            closestTextDistance = dist;
            bestMatchIndex = localCount;
          }
          localCount++;
          searchIndex += selectedText.length;
        }
        
        occurrenceIndex += bestMatchIndex;
        break;
      } else {
        int searchIndex = 0;
        while (true) {
          searchIndex = text.indexOf(selectedText, searchIndex);
          if (searchIndex == -1) break;
          occurrenceIndex++;
          searchIndex += selectedText.length;
        }
      }
    }
    return occurrenceIndex;
  }

  Widget _buildHighlightMenu(BuildContext context, SelectableRegionState selectableRegionState) {
    final selectedText = _selectedContent?.plainText;
    if (selectedText == null || selectedText.isEmpty) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: selectableRegionState.contextMenuAnchors,
        buttonItems: selectableRegionState.contextMenuButtonItems,
      );
    }


    final anchors = selectableRegionState.contextMenuAnchors;
    final primaryAnchor = anchors.primaryAnchor;
    final occurrenceIndex = _findOccurrenceIndex(selectedText, primaryAnchor);

    Highlight? existingHighlight;
    for (final h in widget.highlights) {
      if (h.chapterIndex == widget.index && h.text == selectedText) {
        final parts = h.position.split(':');
        if (parts.length >= 3 && parts[1] == 'exact') {
          if (occurrenceIndex != null && int.tryParse(parts[2]) == occurrenceIndex) {
            existingHighlight = h;
            break;
          }
        }
      }
    }

    if (existingHighlight == null) {
      double exactRatio = _scrollController.hasClients && _scrollController.position.maxScrollExtent > 0
          ? (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0)
          : 0.0;
      double minDistance = double.infinity;
      for (final h in widget.highlights) {
        if (h.chapterIndex == widget.index && h.text == selectedText) {
          final parts = h.position.split(':');
          if (parts.length < 3 || parts[1] != 'exact') {
            double targetRatio = double.tryParse(parts.last) ?? 0.0;
            final distance = (targetRatio - exactRatio).abs();
            if (distance < minDistance) {
              minDistance = distance;
              existingHighlight = h;
            }
          }
        }
      }
    }

    final existing = existingHighlight;
    final screenWidth = MediaQuery.of(context).size.width;
    const toolbarWidth = HighlightToolbar.width;
    const toolbarHeight = HighlightToolbar.height;
    final left = (primaryAnchor.dx - toolbarWidth / 2).clamp(8.0, screenWidth - toolbarWidth - 8.0);
    final top = (primaryAnchor.dy - toolbarHeight - 8).clamp(8.0, double.infinity);

    void close() {
      selectableRegionState.hideToolbar();
      selectableRegionState.clearSelection();
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: HighlightToolbar(
            settings: widget.settings,
            onColor: (hexColor) {
              final ratio = _scrollController.hasClients && _scrollController.position.maxScrollExtent > 0 ? (_scrollController.offset / _scrollController.position.maxScrollExtent) : 0.0;
              widget.onHighlight(Highlight(
                bookId: 0,
                chapterIndex: widget.index,
                text: selectedText,
                color: hexColor,
                createdAt: DateTime.now(),
                position: '${widget.index}:${occurrenceIndex != null ? 'exact:$occurrenceIndex' : 'ratio'}:$ratio',
              ));
              close();
            },
            onRemove: existing == null
                ? null
                : () {
                    widget.onDeleteHighlight(existing.id!);
                    close();
                  },
            onNote: () {
              selectableRegionState.hideToolbar();
              _showNoteSheet(context, selectedText, existing);
            },
            onPlayVoiceNote: existing != null && existing.hasAudio
                ? () {
                    selectableRegionState.hideToolbar();
                    showVoiceNoteSheet(context, settings: widget.settings, highlight: existing);
                  }
                : null,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: selectedText));
              selectableRegionState.hideToolbar();
            },
            onLookup: () {
              _lookupDictionary(selectedText);
              selectableRegionState.hideToolbar();
            },
            onShare: () {
              selectableRegionState.hideToolbar();
              ShareQuoteSheet.show(context, text: selectedText, bookTitle: widget.bookTitle, bookAuthor: widget.bookAuthor);
            },
          ),
        ),
      ],
    );
  }

  void _showNoteSheet(BuildContext context, String text, Highlight? existing) {
    final ratio = _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0
        ? (_scrollController.offset /
              _scrollController.position.maxScrollExtent)
        : 0.0;
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
            chapterIndex: widget.index,
            text: text,
            note: result.markdown,
            color: color,
            createdAt: DateTime.now(),
            position: '${widget.index}:ratio:$ratio',
            audioFile: result.audioFile,
            audioDurationMs: result.audioDurationMs,
            audioWaveform: result.audioWaveform,
          ),
        );
      },
    );
  }

  Future<void> _lookupDictionary(String word) async {
    final lookupWord = word.trim().split(RegExp(r'\s+')).first;
    
    // Delegate to parent if provided, as it handles database recording and platform intents
    if (widget.onLookup != null) {
      widget.onLookup!(lookupWord);
      return;
    }

    final encoded = Uri.encodeComponent(lookupWord);
    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.PROCESS_TEXT',
          type: 'text/plain',
          arguments: {
            'android.intent.extra.PROCESS_TEXT': lookupWord,
            'android.intent.extra.PROCESS_TEXT_READONLY': true,
          },
        );
        await intent.launch();
        return;
      } catch (e) {
        debugPrint('Dictionary intent failed: $e');
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final dictUri = Uri.parse('x-dictionary:r:$encoded');
      if (await canLaunchUrl(dictUri)) {
        await launchUrl(dictUri);
        return;
      }
    }
    final searchUri = Uri.parse('https://www.google.com/search?q=define+$encoded');
    if (await canLaunchUrl(searchUri)) {
      await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    }
  }

  String _cleanHtml(String html) => cleanChapterHtml(html);

  TextAlign _convertTextAlign(TextAlign? textAlign) {
    switch (textAlign) {
      case TextAlign.left: return TextAlign.left;
      case TextAlign.center: return TextAlign.center;
      case TextAlign.right: return TextAlign.right;
      case TextAlign.justify: return TextAlign.justify;
      default: return TextAlign.left;
    }
  }

  String _hexToRgba(String hex, double alpha) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return 'rgba(255, 255, 255, $alpha)';
    final r = int.parse(clean.substring(0, 2), radix: 16);
    final g = int.parse(clean.substring(2, 4), radix: 16);
    final b = int.parse(clean.substring(4, 6), radix: 16);
    return 'rgba($r, $g, $b, $alpha)';
  }
}
