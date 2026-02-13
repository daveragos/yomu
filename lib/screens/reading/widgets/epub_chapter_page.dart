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
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class EpubChapterPage extends StatefulWidget {
  final int index;
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
    required this.pullTriggerDistance,
    required this.pullDeadzone,
    required this.chapters,
    required this.pageController,
    required this.autoScrollSpeedNotifier,
    this.searchQuery,
    this.epubBook,
    required this.highlights,
    required this.onHighlight,
    required this.onDeleteHighlight,
  });

  @override
  State<EpubChapterPage> createState() => _EpubChapterPageState();
}

class _EpubChapterPageState extends State<EpubChapterPage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isNavigating = false;
  double _currentPeakOverscroll = 0.0;
  bool? _isPullingDown;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  SelectedContent? _selectedContent;
  String _processedHtml = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.shouldJumpToBottom) {
      _checkAndJump();
    } else if (widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
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

    if (widget.chapter != oldWidget.chapter ||
        widget.highlights != oldWidget.highlights ||
        widget.searchQuery != oldWidget.searchQuery ||
        widget.settings.usePublisherDefaults !=
            oldWidget.settings.usePublisherDefaults) {
      _updateProcessedHtml();
    }
  }

  void _checkAndJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll);
          widget.onJumpedToBottom();
        } else {
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
          _scrollController.animateTo(
            maxScroll * widget.initialScrollProgress,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
          widget.onJumpedToPosition();
        } else {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _scrollController.hasClients) {
              final double newMaxScroll =
                  _scrollController.position.maxScrollExtent;
              if (newMaxScroll > 0) {
                _scrollController.animateTo(
                  newMaxScroll * widget.initialScrollProgress,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
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
          final double currentProgress = metrics.maxScrollExtent > 0
              ? (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0)
              : 1.0;

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

          if (widget.scrollProgressNotifier.value != currentProgress) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.scrollProgressNotifier.value = currentProgress;
              }
            });
          }
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: () {
              if (widget.showControls) {
                widget.onHideControls();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SelectionArea(
                  onSelectionChanged: (content) {
                    setState(() {
                      _selectedContent = content;
                    });
                  },
                  contextMenuBuilder: (context, selectableRegionState) {
                    return _buildHighlightContextMenu(
                      context,
                      selectableRegionState,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 100),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.chapter.Title != null) ...[
                            Text(
                              widget.chapter.Title!.toUpperCase(),
                              style: TextStyle(
                                color: widget.settings.secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Html(
                            data: _processedHtml,
                            extensions: [
                              TagExtension(
                                tagsToExtend: {"img"},
                                builder: (extensionContext) {
                                  final src =
                                      extensionContext.attributes['src'];

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

                                  final images =
                                      widget.epubBook!.Content?.Images;
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

                                  if (imageFile != null &&
                                      imageFile.Content != null) {
                                    return Center(
                                      child: Image.memory(
                                        Uint8List.fromList(imageFile.Content!),
                                        width:
                                            MediaQuery.of(context).size.width -
                                            40,
                                        fit: BoxFit.contain,
                                      ),
                                    );
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final selectedText = _selectedContent?.plainText;
    if (selectedText == null || selectedText.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Color> colors = [
      const Color(0xFFE74C3C), // Red
      const Color(0xFFF1C40F), // Yellow
      const Color(0xFF2ECC71), // Green
      const Color(0xFF3498DB), // Blue
      const Color(0xFF9B59B6), // Purple
    ];

    return AdaptiveTextSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      children: [
        ...colors.map(
          (color) => IconButton(
            icon: Icon(Icons.circle, color: color),
            onPressed: () {
              final hexColor =
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              widget.onHighlight(
                Highlight(
                  bookId: 0, // Will be set in ReadingScreen
                  text: selectedText,
                  color: hexColor,
                  createdAt: DateTime.now(),
                  position: '', // TODO: Position string for EPUB if needed
                  chapterTitle: widget.chapter.Title,
                ),
              );
              selectableRegionState.hideToolbar();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: selectedText));
            selectableRegionState.hideToolbar();
          },
        ),
      ],
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

  String _processContent() {
    String content = widget.chapter.HtmlContent ?? '';
    // 1. Basic string cleanup (XML, DOCTYPE, SVG)
    content = _cleanHtml(content);

    // 2. Parse to DOM
    var document = html_parser.parseFragment(content);

    // 3. Inject CSS
    if (widget.settings.usePublisherDefaults && widget.epubBook != null) {
      final cssFiles = widget.epubBook!.Content?.Css;
      if (cssFiles != null && cssFiles.isNotEmpty) {
        final buffer = StringBuffer();
        for (final cssFile in cssFiles.values) {
          if (cssFile.Content != null) {
            buffer.write(cssFile.Content!);
          }
        }
        if (buffer.isNotEmpty) {
          final styleElement = dom.Element.tag('style');
          styleElement.text = buffer.toString();
          document.insertBefore(styleElement, document.nodes.firstOrNull);
        }
      }
    }

    // 4. Handle Highlights
    final chapterHighlights = widget.highlights.where(
      (h) => h.chapterTitle == widget.chapter.Title,
    );
    // Sort highlights by length (descending) to prefer longer matches if they overlap?
    // Or just apply them.
    for (final highlight in chapterHighlights) {
      _highlightTextInDom(document, highlight.text, highlight.color);
    }

    // 5. Handle Search Query
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _highlightTextInDom(
        document,
        widget.searchQuery!,
        '#2ECC71',
        isSearch: true,
      );
    }

    return document.outerHtml;
  }

  void _updateProcessedHtml() {
    _processedHtml = _processContent();
  }

  void _highlightTextInDom(
    dom.Node node,
    String text,
    String color, {
    bool isSearch = false,
  }) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final nodeText = node.text!;
      if (nodeText.isEmpty) return;

      // Simple case-sensitive check for now, can make it cleaner.
      // Search query is currently case-insensitive in the old code, so let's support that.
      final matches = isSearch
          ? RegExp(
              RegExp.escape(text),
              caseSensitive: false,
            ).allMatches(nodeText)
          : RegExp(RegExp.escape(text)).allMatches(nodeText);

      if (matches.isEmpty) return;

      // We found matches. We need to split this text node.

      List<dom.Node> newNodes = [];
      int lastIndex = 0;

      for (final match in matches) {
        if (match.start > lastIndex) {
          newNodes.add(dom.Text(nodeText.substring(lastIndex, match.start)));
        }

        final span = dom.Element.tag('span');
        if (isSearch) {
          span.attributes['style'] =
              "background-color: $color; color: #000000; border-radius: 2px; padding: 0 2px;";
        } else {
          span.attributes['style'] =
              "background-color: ${color}B3; border-bottom: 2px solid $color;";
        }
        span.text = match.group(0)!;
        newNodes.add(span);

        lastIndex = match.end;
      }

      if (lastIndex < nodeText.length) {
        newNodes.add(dom.Text(nodeText.substring(lastIndex)));
      }

      // Replace the old text node with the new nodes
      final parent = node.parentNode;
      if (parent != null) {
        final index = parent.nodes.indexOf(node);
        if (index != -1) {
          parent.nodes.removeAt(index);
          parent.nodes.insertAll(index, newNodes);
        }
      }
    } else if (node.hasChildNodes()) {
      for (var child in List<dom.Node>.from(node.nodes)) {
        _highlightTextInDom(child, text, color, isSearch: isSearch);
      }
    }
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
      return match.group(0)!;
    });

    final bodyRegex = RegExp(
      r'(<body[^>]*>.*?</body>)',
      caseSensitive: false,
      dotAll: true,
    );
    final match = bodyRegex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
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
}
