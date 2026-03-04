import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:epub_view/epub_view.dart'
    show EpubChapter, EpubBook, EpubByteContentFile;
import 'package:flutter_html/flutter_html.dart';
import '../../../models/reader_settings_model.dart';
import '../../../models/highlight_model.dart';

class EpubChapterPage extends StatefulWidget {
  final int index;
  final bool isCurrentPage;
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
  final List<Highlight> highlights;
  final Function(Highlight) onHighlight;
  final Function(int) onDeleteHighlight;

  const EpubChapterPage({
    super.key,
    required this.index,
    required this.isCurrentPage,
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
    this.searchQuery,
    this.epubBook,
  });

  @override
  State<EpubChapterPage> createState() => _EpubChapterPageState();
}

class _EpubChapterPageState extends State<EpubChapterPage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isNavigating = false;
  bool _isInitialPositionRestored = false;
  double _currentPeakOverscroll = 0.0;
  bool? _isPullingDown;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  String _processedHtml = '';
  SelectedContent? _selectedContent;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.shouldJumpToBottom) {
      _checkAndJump();
      _isInitialPositionRestored = true;
    } else if (widget.initialScrollProgress > 0) {
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
    if (widget.shouldJumpToBottom && !oldWidget.shouldJumpToBottom) {
      _checkAndJump();
    } else if (widget.initialScrollProgress !=
            oldWidget.initialScrollProgress &&
        widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
    }

    final bool bookChanged = !identical(widget.epubBook, oldWidget.epubBook);

    if (widget.chapter != oldWidget.chapter ||
        widget.settings.usePublisherDefaults !=
            oldWidget.settings.usePublisherDefaults ||
        widget.searchQuery != oldWidget.searchQuery ||
        widget.highlights != oldWidget.highlights ||
        bookChanged) {
      _updateProcessedHtml();
    }
  }

  void _updateProcessedHtml() {
    final book = widget.epubBook;
    final settings = widget.settings;
    final chapter = widget.chapter;

    String content = _cleanHtml(chapter.HtmlContent ?? '');

    // Inject EPUB CSS if publisher defaults are on
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

    // Inject highlight spans for saved highlights
    final chapterHighlights = widget.highlights
        .where((h) => h.chapterIndex == widget.index)
        .toList();
    // Sort by text length descending so longer matches are applied first
    chapterHighlights.sort((a, b) => b.text.length.compareTo(a.text.length));
    for (final highlight in chapterHighlights) {
      final escapedText = RegExp.escape(highlight.text);
      final regex = RegExp('(?![^<]*>)$escapedText');
      final rgba = _hexToRgba(highlight.color, 0.35);
      content = content.replaceAllMapped(regex, (match) {
        return '<span style="background-color: $rgba; border-bottom: 2px solid ${highlight.color};">${match.group(0)}</span>';
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

    setState(() {
      _processedHtml = content;
    });
  }

  void _checkAndJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll);
          widget.onJumpedToBottom();
        } else {
          // If maxScroll is 0, the content might not be laid out yet.
          // Retry after a short delay.
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              final double newMaxScroll =
                  _scrollController.position.maxScrollExtent;
              if (newMaxScroll > 0) {
                _scrollController.jumpTo(newMaxScroll);
              }
              widget.onJumpedToBottom();
            }
          });
        }
      }
    });
  }

  void _checkAndJumpToPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll * widget.initialScrollProgress);
          setState(() => _isInitialPositionRestored = true);
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
              widget.onJumpedToPosition();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    widget.autoScrollSpeedNotifier.removeListener(_handleSpeedChange);
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _currentPeakOverscroll = 0.0;
        }

        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle &&
              widget.showControls) {
            widget.onHideControls();
          }

          if (notification.direction == ScrollDirection.idle &&
              !_isNavigating) {
            if (_currentPeakOverscroll > 40) {
              if (_isPullingDown == false &&
                  widget.index < widget.chapters.length - 1) {
                _isNavigating = true;
                HapticFeedback.mediumImpact();
                widget.pageController
                    ?.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutQuart,
                    )
                    .then((_) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) _isNavigating = false;
                      });
                    });
                _resetPullState();
              } else if (_isPullingDown == true && widget.index > 0) {
                _isNavigating = true;
                HapticFeedback.mediumImpact();
                widget.pageController
                    ?.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutQuart,
                    )
                    .then((_) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) _isNavigating = false;
                      });
                    });
                _resetPullState();
              }
            }
            _currentPeakOverscroll = 0.0;
          }
        }

        if (notification.metrics.axis == Axis.vertical) {
          final metrics = notification.metrics;
          final double progressValue = metrics.maxScrollExtent > 0
              ? (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0)
              : 1.0;

          // Only update progress if we're the current page AND initial position is restored
          if (widget.isCurrentPage && _isInitialPositionRestored) {
            if (progressValue != widget.scrollProgressNotifier.value) {
              widget.scrollProgressNotifier.value = progressValue;
              widget.onInteraction();
            }
          }

          if (metrics.pixels > metrics.maxScrollExtent) {
            final overscroll = metrics.pixels - metrics.maxScrollExtent;
            if (overscroll > _currentPeakOverscroll) {
              _currentPeakOverscroll = overscroll;
              _isPullingDown = false;
            }
          } else if (metrics.pixels < 0) {
            final overscroll = -metrics.pixels;
            if (overscroll > _currentPeakOverscroll) {
              _currentPeakOverscroll = overscroll;
              _isPullingDown = true;
            }
          }

          if (metrics.pixels != 0) {
            widget.onInteraction();
          }
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: SelectionArea(
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
                                widget.pageController == null)
                              return;

                            // Clean up url (e.g., ../Text/chapter2.xhtml#sec1 -> Text/chapter2.xhtml)
                            String targetUrl = url;
                            while (targetUrl.startsWith('../')) {
                              targetUrl = targetUrl.substring(3);
                            }

                            final parts = targetUrl.split('#');
                            final targetFile = parts[0];

                            final anchor = parts.length > 1 ? parts[1] : null;

                            if (targetFile.isEmpty && anchor != null) {
                              // Anchor-only link in the current file
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

                            // Find target chapter by file + anchor
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

                              // Prefer exact anchor match
                              if (anchor != null &&
                                  anchor.isNotEmpty &&
                                  ch.Anchor == anchor) {
                                targetIndex = i;
                                break;
                              }
                              // Track first file-only match as fallback
                              fileOnlyIndex ??= i;
                            }

                            targetIndex ??= fileOnlyIndex;
                            if (targetIndex != null) {
                              widget.pageController?.jumpToPage(targetIndex);
                            }
                          },
                          extensions: [
                            TagExtension(
                              tagsToExtend: {"img"},
                              builder: (extensionContext) {
                                final src = extensionContext.attributes['src'];

                                if (src == null || widget.epubBook == null) {
                                  return const SizedBox.shrink();
                                }

                                // Normalize path
                                String path = src;
                                while (path.startsWith('../')) {
                                  path = path.substring(3);
                                }
                                if (path.startsWith('/')) {
                                  path = path.substring(1);
                                }
                                // URL decode just in case
                                path = Uri.decodeFull(path);

                                final images = widget.epubBook?.Content?.Images;
                                if (images == null) {
                                  return const SizedBox.shrink();
                                }

                                // Try exact match first, then by filename
                                EpubByteContentFile? imageFile = images[path];

                                if (imageFile == null) {
                                  final fileName = path.split('/').last;
                                  for (final file in images.values) {
                                    if (file.FileName == fileName) {
                                      imageFile = file;
                                      break;
                                    }
                                  }
                                }

                                if (imageFile != null) {
                                  final content = imageFile.Content;
                                  if (content != null) {
                                    return Center(
                                      child: Image.memory(
                                        Uint8List.fromList(content),
                                        width:
                                            MediaQuery.of(context).size.width -
                                            40,
                                        fit: BoxFit.contain,
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
                              fontSize: FontSize(
                                widget.settings.textSize,
                                Unit.px,
                              ),
                              lineHeight: LineHeight(
                                widget.settings.lineHeight,
                                units: "",
                              ),
                              color: widget.settings.textColor,
                              textAlign: _convertTextAlign(
                                widget.settings.textAlign,
                              ),
                              fontFamily: widget.settings.typeface == 'System'
                                  ? null
                                  : widget.settings.typeface,
                            ),
                            "p": Style(
                              margin: Margins.only(bottom: 16),
                              lineHeight: LineHeight(
                                widget.settings.lineHeight,
                                units: "",
                              ),
                            ),
                            "h1": Style(
                              fontSize: FontSize(
                                widget.settings.textSize * 1.5,
                                Unit.px,
                              ),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 24, bottom: 12),
                            ),
                            "h2": Style(
                              fontSize: FontSize(
                                widget.settings.textSize * 1.3,
                                Unit.px,
                              ),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 20, bottom: 10),
                            ),
                            "h3": Style(
                              fontSize: FontSize(
                                widget.settings.textSize * 1.1,
                                Unit.px,
                              ),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 16, bottom: 8),
                            ),
                            "blockquote": Style(
                              margin: Margins.only(
                                left: 20,
                                right: 20,
                                bottom: 16,
                              ),
                              padding: HtmlPaddings.only(left: 12),
                              border: Border(
                                left: BorderSide(
                                  color: widget.settings.secondaryTextColor,
                                  width: 3,
                                ),
                              ),
                            ),
                            "code": Style(
                              fontFamily: "monospace",
                              backgroundColor: widget.settings.textColor
                                  .withValues(alpha: 0.1),
                              padding: HtmlPaddings.symmetric(horizontal: 4),
                            ),
                            "pre": Style(
                              margin: Margins.only(bottom: 16),
                              padding: HtmlPaddings.all(12),
                              backgroundColor: widget.settings.textColor
                                  .withValues(alpha: 0.1),
                              fontFamily: "monospace",
                              display: Display.block,
                            ),
                            "img": Style(
                              width: Width(
                                MediaQuery.of(context).size.width - 40,
                                Unit.px,
                              ),
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
      ),
    );
  }

  void _resetPullState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.pullDistanceNotifier.value = 0.0;
        widget.isPullingDownNotifier.value = false;
        widget.scrollProgressNotifier.value = 0.0;
      }
    });
  }

  Widget _buildHighlightMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final selectedText = _selectedContent?.plainText;
    if (selectedText == null || selectedText.isEmpty) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: selectableRegionState.contextMenuAnchors,
        buttonItems: selectableRegionState.contextMenuButtonItems,
      );
    }

    const highlightColors = [
      Color(0xFFE74C3C), // Red
      Color(0xFFF1C40F), // Yellow
      Color(0xFF2ECC71), // Green
      Color(0xFF3498DB), // Blue
      Color(0xFF9B59B6), // Purple
    ];

    // Check if this text is already highlighted
    final existingHighlight = widget.highlights
        .where((h) => h.chapterIndex == widget.index && h.text == selectedText)
        .firstOrNull;

    return AdaptiveTextSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...highlightColors.map(
              (color) => SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.circle, color: color, size: 22),
                  onPressed: () {
                    final hexColor =
                        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                    widget.onHighlight(
                      Highlight(
                        bookId: 0, // Set by ReadingScreen
                        chapterIndex: widget.index,
                        text: selectedText,
                        color: hexColor,
                        createdAt: DateTime.now(),
                      ),
                    );
                    selectableRegionState.hideToolbar();
                  },
                ),
              ),
            ),
            if (existingHighlight != null)
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.highlight_remove,
                    color: widget.settings.textColor,
                    size: 22,
                  ),
                  onPressed: () {
                    widget.onDeleteHighlight(existingHighlight.id!);
                    selectableRegionState.hideToolbar();
                  },
                ),
              ),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.copy,
                  color: widget.settings.textColor,
                  size: 22,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: selectedText));
                  selectableRegionState.hideToolbar();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return html;

    // Remove XML declarations
    html = html.replaceAll(RegExp(r'<\?xml[^>]*\?>'), '');

    // Remove DOCTYPE declarations
    html = html.replaceAll(RegExp(r'<!DOCTYPE[^>]*>'), '');

    final svgImageRegex = RegExp(
      r'<svg[^>]*>.*?(<image[^>]*>).*?</svg>',
      caseSensitive: false,
      dotAll: true,
    );

    html = html.replaceAllMapped(svgImageRegex, (match) {
      final imageTag = match.group(1);
      if (imageTag != null) {
        final hrefRegex = RegExp(
          r'''(?:xlink:)?href=["']([^"']*)["']''',
          caseSensitive: false,
        );
        final hrefMatch = hrefRegex.firstMatch(imageTag);
        if (hrefMatch != null) {
          final src = hrefMatch.group(1);
          return '<img src="$src" style="width:100%; object-fit: contain;" />';
        }
      }
      return match.group(0) ?? '';
    });

    final bodyRegex = RegExp(
      r'(<body[^>]*>.*?</body>)',
      caseSensitive: false,
      dotAll: true,
    );
    final bodyMatch = bodyRegex.firstMatch(html);
    if (bodyMatch != null) {
      final bodyContent = bodyMatch.group(1);
      if (bodyContent != null) {
        return bodyContent;
      }
    }

    if (!html.toLowerCase().contains('<body')) {
      return '<body>$html</body>';
    }

    return html;
  }

  TextAlign _convertTextAlign(TextAlign? textAlign) {
    switch (textAlign) {
      case TextAlign.left:
        return TextAlign.left;
      case TextAlign.center:
        return TextAlign.center;
      case TextAlign.right:
        return TextAlign.right;
      case TextAlign.justify:
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  String _hexToRgba(String hex, double alpha) {
    final clean = hex.replaceFirst('#', '');
    final r = int.parse(clean.substring(0, 2), radix: 16);
    final g = int.parse(clean.substring(2, 4), radix: 16);
    final b = int.parse(clean.substring(4, 6), radix: 16);
    return 'rgba($r, $g, $b, $alpha)';
  }
}
