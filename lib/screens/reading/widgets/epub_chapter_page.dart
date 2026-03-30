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
import '../../../core/constants.dart';
import 'share_quote_sheet.dart';
import 'note_editor.dart';

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
  final String? bookTitle;
  final String? bookAuthor;
  final List<Highlight> highlights;
  final Function(Highlight) onHighlight;
  final Function(int) onDeleteHighlight;
  final Function(String)? onLookup;

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
    this.onLookup,
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
  double _currentPeakOverscroll = 0.0;
  bool? _isPullingDown;
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

    // Inject highlight spans for saved highlights
    final chapterHighlights = widget.highlights
        .where((h) => h.chapterIndex == widget.index)
        .toList();
    chapterHighlights.sort((a, b) => b.text.length.compareTo(a.text.length));
    for (final highlight in chapterHighlights) {
      // Create a regex that is extremely lenient with HTML whitespace and nested tags
      final normalizedText = highlight.text.replaceAll(RegExp(r'\s+'), ' ');
      final wsPattern = r'(?:\s|&nbsp;|&zwj;|&#160;|&#xa0;|&#x20;|<[^>]+>)+';
      final escapedText = RegExp.escape(normalizedText).replaceAll(' ', wsPattern);
      
      // Lookahead ensures we don't start matching inside an HTML tag
      final regex = RegExp('(?![^<]*>)$escapedText', caseSensitive: false);
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

      int currentMatchIndex = 0;
      content = content.replaceAllMapped(regex, (match) {
        final result = currentMatchIndex == targetMatchIndex
            ? '<span style="background-color: $rgba; border-bottom: 2px solid ${highlight.color};">${match.group(0)}</span>'
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

    const highlightColors = [
      Color(0xFFE74C3C),
      Color(0xFFF1C40F),
      Color(0xFF2ECC71),
      Color(0xFF3498DB),
      Color(0xFF9B59B6),
    ];

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

    final textColor = widget.settings.menuIconColor;
    const btnSize = 36.0;
    const iconSize = 20.0;
    final screenWidth = MediaQuery.of(context).size.width;
    const toolbarWidth = 188.0;
    const toolbarHeight = 80.0;
    final left = (primaryAnchor.dx - toolbarWidth / 2).clamp(8.0, screenWidth - toolbarWidth - 8.0);
    final top = (primaryAnchor.dy - toolbarHeight - 8).clamp(8.0, double.infinity);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: widget.settings.menuBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...highlightColors.map((color) => SizedBox(
                        width: btnSize,
                        height: btnSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.circle, color: color, size: 22),
                          onPressed: () {
                            final hexColor = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                            widget.onHighlight(Highlight(
                              bookId: 0,
                              chapterIndex: widget.index,
                              text: selectedText,
                              color: hexColor,
                              createdAt: DateTime.now(),
                              position: '${widget.index}:${occurrenceIndex != null ? 'exact:$occurrenceIndex' : (_scrollController.hasClients ? (_scrollController.offset / _scrollController.position.maxScrollExtent) : 0.0)}',
                            ));
                            selectableRegionState.hideToolbar();
                            selectableRegionState.clearSelection();
                          },
                        ),
                      )),
                      if (existingHighlight != null)
                        SizedBox(
                          width: btnSize,
                          height: btnSize,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.highlight_remove, color: textColor, size: iconSize),
                            onPressed: () {
                              widget.onDeleteHighlight(existingHighlight!.id!);
                              selectableRegionState.hideToolbar();
                              selectableRegionState.clearSelection();
                            },
                          ),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: btnSize,
                        height: btnSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.sticky_note_2_rounded, color: YomuConstants.accent, size: iconSize),
                          onPressed: () {
                            selectableRegionState.hideToolbar();
                            _showNoteSheet(context, selectedText, existingHighlight);
                          },
                        ),
                      ),
                      SizedBox(
                        width: btnSize,
                        height: btnSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.copy_rounded, color: textColor, size: iconSize),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: selectedText));
                            selectableRegionState.hideToolbar();
                          },
                        ),
                      ),
                      SizedBox(
                        width: btnSize,
                        height: btnSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.menu_book_rounded, color: textColor, size: iconSize),
                          onPressed: () {
                            _lookupDictionary(selectedText);
                            selectableRegionState.hideToolbar();
                          },
                        ),
                      ),
                      SizedBox(
                        width: btnSize,
                        height: btnSize,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.share_rounded, color: textColor, size: iconSize),
                          onPressed: () {
                            selectableRegionState.hideToolbar();
                            ShareQuoteSheet.show(context, text: selectedText, bookTitle: widget.bookTitle, bookAuthor: widget.bookAuthor);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNoteSheet(BuildContext context, String text, Highlight? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NoteEditor(
          initialMarkdown: existing?.note ?? '',
          settings: widget.settings,
          title: existing != null ? 'Edit Note' : 'Add Note',
          onSave: (newNote) {
            final hexColor = existing?.color ?? '#${const Color(0xFFF1C40F).toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            widget.onHighlight(Highlight(
              id: existing?.id,
              bookId: 0,
              chapterIndex: widget.index,
              text: text,
              note: newNote,
              color: hexColor,
              createdAt: existing?.createdAt ?? DateTime.now(),
              position: existing?.position ?? '${widget.index}:${_scrollController.offset / _scrollController.position.maxScrollExtent}',
            ));
          },
        );
      },
    );
  }

  Future<void> _lookupDictionary(String word) async {
    final lookupWord = word.trim().split(RegExp(r'\s+')).first;
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
        widget.onLookup?.call(lookupWord);
        return;
      } catch (e) {
        debugPrint('Dictionary intent failed: $e');
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final dictUri = Uri.parse('x-dictionary:r:$encoded');
      if (await canLaunchUrl(dictUri)) {
        await launchUrl(dictUri);
        widget.onLookup?.call(lookupWord);
        return;
      }
    }
    final searchUri = Uri.parse('https://www.google.com/search?q=define+$encoded');
    if (await canLaunchUrl(searchUri)) {
      await launchUrl(searchUri, mode: LaunchMode.externalApplication);
      widget.onLookup?.call(lookupWord);
    }
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return html;
    html = html.replaceAll(RegExp(r'<\?xml[^>]*\?>'), '');
    html = html.replaceAll(RegExp(r'<!DOCTYPE[^>]*>'), '');
    html = html.replaceAll(RegExp(r'<svg', caseSensitive: false), '<div');
    html = html.replaceAll(RegExp(r'</svg>', caseSensitive: false), '</div>');
    final bodyRegex = RegExp(r'(<body[^>]*>.*?</body>)', caseSensitive: false, dotAll: true);
    final bodyMatch = bodyRegex.firstMatch(html);
    if (bodyMatch != null) return bodyMatch.group(1) ?? html;
    if (!html.toLowerCase().contains('<body')) return '<body>$html</body>';
    return html;
  }

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
