import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:pdfrx/pdfrx.dart' show PdfOutlineNode;

import '../../../models/book_model.dart';
import '../../../models/bookmark_model.dart';
import '../../../models/highlight_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../core/constants.dart';
import './note_editor.dart';
import './note_view.dart';

class NavigationSheet extends StatefulWidget {
  final Book book;
  final List<EpubChapter> chapters;
  final List<EpubChapter> tocChapters;
  final List<PdfOutlineNode> pdfOutline;
  final List<PdfOutlineNode> tocPdfOutline;
  final int currentChapterIndex;
  final PdfOutlineNode? currentPdfNode;
  final Function(int) onChapterTap;
  final Function(PdfOutlineNode) onPdfOutlineTap;
  final Future<List<Bookmark>> Function() getBookmarks;
  final Future<List<Highlight>> Function() getHighlights;
  final List<Highlight> highlights;
  final Function(Highlight) onHighlightTap;
  final Future<void> Function(int) onDeleteHighlight;
  final Future<void> Function(List<int>) onDeleteHighlights;
  final Future<void> Function(Bookmark) onDeleteBookmark;
  final Future<void> Function(List<Bookmark>) onDeleteBookmarks;
  final void Function(Bookmark) onBookmarkTap;
  final Future<void> Function(Highlight) onUpdateHighlight;
  final String Function(DateTime) formatDate;
  final void Function(int)? onJumpToPage;
  final void Function(double)? onJumpToPercent;
  final VoidCallback? onExport;
  final bool focusJump;
  final int totalPages;
  final ReaderSettings readerSettings;

  const NavigationSheet({
    super.key,
    required this.book,
    required this.chapters,
    required this.tocChapters,
    required this.pdfOutline,
    required this.tocPdfOutline,
    required this.currentChapterIndex,
    this.currentPdfNode,
    required this.onChapterTap,
    required this.onPdfOutlineTap,
    required this.getBookmarks,
    required this.getHighlights,
    required this.highlights,
    required this.onHighlightTap,
    required this.onDeleteHighlight,
    required this.onDeleteHighlights,
    required this.onDeleteBookmark,
    required this.onDeleteBookmarks,
    required this.onBookmarkTap,
    required this.onUpdateHighlight,
    required this.formatDate,
    this.onJumpToPage,
    this.onJumpToPercent,
    this.onExport,
    this.focusJump = false,
    this.totalPages = 0,
    required this.readerSettings,
  });

  @override
  State<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<NavigationSheet> {
  final TextEditingController _jumpController = TextEditingController();
  final FocusNode _jumpFocusNode = FocusNode();
  
  bool _isSelectionMode = false;
  final Set<int> _selectedHighlightIds = {};
  final Set<Bookmark> _selectedBookmarks = {};
  String? _selectedFilterColor;

  @override
  void initState() {
    super.initState();
    if (widget.focusJump) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _jumpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: YomuConstants.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const TabBar(
              indicatorColor: YomuConstants.accent,
              labelColor: YomuConstants.accent,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'CHAPTERS'),
                Tab(text: 'ANNOTATIONS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildChaptersTab(), _buildBookmarksList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersTab() {
    return Column(
      children: [
        _buildJumpToSection(),
        Expanded(child: _buildChaptersList()),
      ],
    );
  }

  Widget _buildJumpToSection() {
    final isEpub = widget.book.filePath.toLowerCase().endsWith('.epub');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _jumpController,
              focusNode: _jumpFocusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: isEpub
                    ? 'Jump to %'
                    : 'Jump to page${widget.totalPages > 0 ? " (1 - ${widget.totalPages})" : ""}',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixText: isEpub
                    ? '%'
                    : (widget.totalPages > 0 ? "/ ${widget.totalPages}" : null),
                suffixStyle: const TextStyle(color: Colors.white38),
              ),
              onSubmitted: (value) => _handleJump(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: YomuConstants.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _handleJump,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: YomuConstants.accent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleJump() {
    final value = _jumpController.text;
    final numValue = double.tryParse(value);
    if (numValue != null) {
      final isEpub = widget.book.filePath.toLowerCase().endsWith('.epub');
      if (isEpub) {
        if (widget.onJumpToPercent != null) {
          widget.onJumpToPercent!(numValue / 100.0);
        }
      } else {
        if (widget.onJumpToPage != null) {
          widget.onJumpToPage!(numValue.toInt());
        }
      }
    }
  }

  Future<void> _shareSelectedAsMarkdown(List<Bookmark> bookmarks, List<Highlight> highlights) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${widget.book.title} - Selected Annotations');
    buffer.writeln('*Exported with Yomu — ${DateTime.now().year}*');
    buffer.writeln();
    if (widget.book.author.isNotEmpty) buffer.writeln('**Author:** ${widget.book.author}');
    buffer.writeln('**Shared on:** ${widget.formatDate(DateTime.now())}');
    buffer.writeln();

    if (bookmarks.isNotEmpty) {
      buffer.writeln('## Bookmarks');
      for (final b in bookmarks) {
        buffer.writeln('- ${b.title} (${(b.progress * 100).toStringAsFixed(1)}%) — ${widget.formatDate(b.createdAt)}');
      }
      buffer.writeln();
    }

    if (highlights.isNotEmpty) {
      buffer.writeln('## Highlights & Notes');
      for (final h in highlights) {
        buffer.writeln('> ${h.text}');
        buffer.writeln();
        if (h.note != null && h.note!.isNotEmpty) {
          buffer.writeln('**Note:** ${h.note}');
          buffer.writeln();
        }
        final pos = h.position.contains(':')
            ? 'Chapter ${int.parse(h.position.split(':')[0]) + 1}'
            : 'Page ${h.chapterIndex + 1}';
        buffer.writeln('*Position: $pos — ${widget.formatDate(h.createdAt)}*');
        buffer.writeln('---');
      }
    }

    buffer.writeln();
    buffer.writeln('*Exported with Yomu*');

    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'yomu_selection_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = io.File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${widget.book.title} - Selections',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  void _showNoteDetailSheet(BuildContext context, Highlight h, StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: YomuConstants.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: YomuConstants.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HIGHLIGHT',
                            style: TextStyle(
                              color: YomuConstants.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: YomuConstants.accent),
                          onPressed: () {
                            Navigator.pop(context); // Close detail sheet
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => NoteEditor(
                                initialMarkdown: h.note ?? '',
                                initialColor: h.color,
                                settings: widget.readerSettings,
                                onSave: (newNote) => widget.onUpdateHighlight(h.copyWith(note: newNote)),
                                onSaveWithColor: (newNote, newColor) async {
                                  final updatedHighlight = h.copyWith(
                                    note: newNote,
                                    color: newColor,
                                  );
                                  await widget.onUpdateHighlight(updatedHighlight);
                                },
                              ),
                            ).then((_) {
                              setSheetState(() {});
                            });
                          },
                        ),
                        Text(
                          widget.formatDate(h.createdAt),
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        h.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Serif',
                        ),
                      ),
                    ),
                    if (h.note != null && h.note!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Icon(Icons.notes_rounded, color: YomuConstants.accent, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            'MY NOTE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      NoteView(
                        markdown: h.note!,
                        settings: widget.readerSettings,
                        fontSize: 16,
                        textColor: Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    if (widget.book.filePath.toLowerCase().endsWith('.epub')) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.tocChapters.map((chapter) {
            return _ChapterTreeItem(
              chapter: chapter,
              depth: 0,
              currentChapterIndex: widget.currentChapterIndex,
              flattenedChapters: widget.chapters,
              onTap: widget.onChapterTap,
            );
          }).toList(),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.tocPdfOutline.map((node) {
            return _PdfTreeItem(
              node: node,
              depth: 0,
              onTap: widget.onPdfOutlineTap,
              currentPdfNode: widget.currentPdfNode,
              flattenedOutline: widget.pdfOutline,
            );
          }).toList(),
        ),
      );
    }
  }

  Widget _buildBookmarksList() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            widget.getBookmarks(),
            widget.getHighlights(),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bookmarks = snapshot.data![0] as List<Bookmark>;
            final highlights = snapshot.data![1] as List<Highlight>;

            if (bookmarks.isEmpty && highlights.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.note_alt_outlined, size: 64, color: Colors.white10),
                    const SizedBox(height: 16),
                    const Text(
                      'No annotations found yet',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    if (widget.onExport != null) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: widget.onExport,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Export Current Book'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YomuConstants.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            // Combine and sort by date or context if needed, 
            // for now let's keep them in sections but with the new header
            final filteredHighlights = _selectedFilterColor == null
                ? highlights
                : highlights.where((h) => h.color == _selectedFilterColor).toList();
            
            final highlightsCount = highlights.length;
            final filteredHighlightsCount = filteredHighlights.length;

            return Column(
              children: [
                _AnnotationHeader(
                  count: _selectedFilterColor == null ? bookmarks.length + highlightsCount : bookmarks.length + filteredHighlightsCount,
                  isSelectionMode: _isSelectionMode,
                  selectedCount: _selectedHighlightIds.length + _selectedBookmarks.length,
                  onToggleSelection: () => setSheetState(() => _isSelectionMode = true),
                  onCloseSelection: () => setSheetState(() {
                    _isSelectionMode = false;
                    _selectedHighlightIds.clear();
                    _selectedBookmarks.clear();
                  }),
                  onDeleteSelected: () async {
                    if (_selectedHighlightIds.isNotEmpty) {
                      await widget.onDeleteHighlights(_selectedHighlightIds.toList());
                    }
                    if (_selectedBookmarks.isNotEmpty) {
                      await widget.onDeleteBookmarks(_selectedBookmarks.toList());
                    }
                    setSheetState(() {
                      _isSelectionMode = false;
                      _selectedHighlightIds.clear();
                      _selectedBookmarks.clear();
                    });
                  },
                  onExport: widget.onExport,
                  onShareSelected: () {
                    final selectedHighlights = highlights.where((h) => _selectedHighlightIds.contains(h.id)).toList();
                    _shareSelectedAsMarkdown(_selectedBookmarks.toList(), selectedHighlights);
                  },
                ),
                if (!_isSelectionMode && highlights.isNotEmpty)
                  _ColorFilterBar(
                    selectedColor: _selectedFilterColor,
                    onColorTap: (color) {
                      setSheetState(() {
                        if (_selectedFilterColor == color) {
                          _selectedFilterColor = null;
                        } else {
                          _selectedFilterColor = color;
                        }
                      });
                    },
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      if (bookmarks.isNotEmpty && _selectedFilterColor == null) ...[
                        ...bookmarks.map((bookmark) {
                          final isSelected = _selectedBookmarks.contains(bookmark);
                          return _AnnotationCard(
                            readerSettings: widget.readerSettings,
                            title: bookmark.title,
                            text: '${(bookmark.progress * 100).toStringAsFixed(1)}%',
                            date: widget.formatDate(bookmark.createdAt),
                            isHighlight: false,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onSelectedChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  _selectedBookmarks.add(bookmark);
                                } else {
                                  _selectedBookmarks.remove(bookmark);
                                }
                              });
                            },
                            onDelete: () async {
                              await widget.onDeleteBookmark(bookmark);
                              setSheetState(() {});
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                setSheetState(() {
                                  if (isSelected) {
                                    _selectedBookmarks.remove(bookmark);
                                  } else {
                                    _selectedBookmarks.add(bookmark);
                                  }
                                });
                              } else {
                                widget.onBookmarkTap(bookmark);
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setSheetState(() {
                                  _isSelectionMode = true;
                                  _selectedBookmarks.add(bookmark);
                                });
                              }
                            },
                          );
                        }),
                      ],
                      if (filteredHighlights.isNotEmpty) ...[
                        ...filteredHighlights.map((h) {
                          final isSelected = _selectedHighlightIds.contains(h.id);
                          return _AnnotationCard(
                            readerSettings: widget.readerSettings,
                            text: h.text,
                            note: h.note,
                            date: widget.formatDate(h.createdAt),
                            isHighlight: true,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onSelectedChanged: (val) {
                              setSheetState(() {
                                if (val == true && h.id != null) {
                                  _selectedHighlightIds.add(h.id!);
                                } else if (h.id != null) {
                                  _selectedHighlightIds.remove(h.id!);
                                }
                              });
                            },
                            onDelete: () async {
                              if (h.id != null) {
                                await widget.onDeleteHighlight(h.id!);
                                setSheetState(() {});
                              }
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                setSheetState(() {
                                  if (h.id != null) {
                                    if (isSelected) {
                                      _selectedHighlightIds.remove(h.id!);
                                    } else {
                                      _selectedHighlightIds.add(h.id!);
                                    }
                                  }
                                });
                              } else {
                                _showNoteDetailSheet(context, h, setSheetState);
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode && h.id != null) {
                                setSheetState(() {
                                  _isSelectionMode = true;
                                  _selectedHighlightIds.add(h.id!);
                                });
                              }
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChapterTreeItem extends StatefulWidget {
  final EpubChapter chapter;
  final int depth;
  final int currentChapterIndex;
  final List<EpubChapter> flattenedChapters;
  final Function(int) onTap;

  const _ChapterTreeItem({
    required this.chapter,
    required this.depth,
    required this.currentChapterIndex,
    required this.flattenedChapters,
    required this.onTap,
  });

  @override
  State<_ChapterTreeItem> createState() => _ChapterTreeItemState();
}

class _ChapterTreeItemState extends State<_ChapterTreeItem> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final index = widget.flattenedChapters.indexOf(widget.chapter);
        if (index == widget.currentChapterIndex) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSubChapters =
        widget.chapter.SubChapters != null &&
        widget.chapter.SubChapters!.isNotEmpty;
    final index = widget.flattenedChapters.indexOf(widget.chapter);
    final isCurrent = widget.currentChapterIndex == index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (index != -1) {
                widget.onTap(index);
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.0 + (widget.depth * 16.0),
                top: 12,
                bottom: 12,
                right: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.chapter.Title?.trim() ?? 'Chapter',
                      style: TextStyle(
                        color: isCurrent ? YomuConstants.accent : Colors.white,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (hasSubChapters)
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded && hasSubChapters)
          Column(
            children: widget.chapter.SubChapters!.map((subChapter) {
              return _ChapterTreeItem(
                chapter: subChapter,
                depth: widget.depth + 1,
                currentChapterIndex: widget.currentChapterIndex,
                flattenedChapters: widget.flattenedChapters,
                onTap: widget.onTap,
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _PdfTreeItem extends StatefulWidget {
  final PdfOutlineNode node;
  final int depth;
  final Function(PdfOutlineNode) onTap;
  final PdfOutlineNode? currentPdfNode;
  final List<PdfOutlineNode> flattenedOutline;

  const _PdfTreeItem({
    required this.node,
    required this.depth,
    required this.onTap,
    this.currentPdfNode,
    this.flattenedOutline = const [],
  });

  @override
  State<_PdfTreeItem> createState() => _PdfTreeItemState();
}

class _PdfTreeItemState extends State<_PdfTreeItem> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.node == widget.currentPdfNode) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.node.children.isNotEmpty;
    final isCurrent = widget.currentPdfNode == widget.node;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onTap(widget.node),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.0 + (widget.depth * 16.0),
                top: 12,
                bottom: 12,
                right: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.node.title,
                      style: TextStyle(
                        color: isCurrent ? YomuConstants.accent : Colors.white,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (hasChildren)
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded && hasChildren)
          Column(
            children: widget.node.children.map((child) {
              return _PdfTreeItem(
                node: child,
                depth: widget.depth + 1,
                onTap: widget.onTap,
                currentPdfNode: widget.currentPdfNode,
                flattenedOutline: widget.flattenedOutline,
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _AnnotationHeader extends StatelessWidget {
  final int count;
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onToggleSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onCloseSelection;
  final VoidCallback onShareSelected;
  final VoidCallback? onExport;

  const _AnnotationHeader({
    required this.count,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onToggleSelection,
    required this.onDeleteSelected,
    required this.onCloseSelection,
    required this.onShareSelected,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSelectionMode ? '$selectedCount SELECTED' : 'ANNOTATIONS',
                  style: const TextStyle(
                    color: YomuConstants.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (!isSelectionMode)
                  Text(
                    '$count items',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: YomuConstants.accent, size: 20),
              onPressed: selectedCount > 0 ? onShareSelected : null,
              tooltip: 'Share selected',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: selectedCount > 0 ? onDeleteSelected : null,
              tooltip: 'Delete selected',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              onPressed: onCloseSelection,
              tooltip: 'Cancel selection',
            ),
          ] else ...[
            if (onExport != null)
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, color: YomuConstants.accent, size: 18),
                onPressed: onExport,
                tooltip: 'Export',
              ),
            TextButton(
              onPressed: onToggleSelection,
              child: const Text(
                'SELECT',
                style: TextStyle(color: YomuConstants.accent, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorFilterBar extends StatelessWidget {
  final String? selectedColor;
  final Function(String?) onColorTap;

  const _ColorFilterBar({
    required this.selectedColor,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        border: const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilterChip(
              label: const Text('ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              selected: selectedColor == null,
              onSelected: (_) => onColorTap(null),
              backgroundColor: Colors.transparent,
              selectedColor: YomuConstants.accent.withValues(alpha: 0.2),
              checkmarkColor: YomuConstants.accent,
              side: BorderSide(color: selectedColor == null ? YomuConstants.accent : Colors.white10),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          ...YomuConstants.highlightColors.map((color) {
            final hexColor = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            final isSelected = selectedColor == hexColor;
            return Padding(
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: FilterChip(
                label: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => onColorTap(hexColor),
                backgroundColor: color.withValues(alpha: 0.1),
                selectedColor: color.withValues(alpha: 0.3),
                checkmarkColor: Colors.white,
                side: BorderSide(color: isSelected ? color : Colors.transparent),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AnnotationCard extends StatelessWidget {
  final String? title;
  final String text;
  final String? note;
  final String date;
  final bool isHighlight;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ReaderSettings readerSettings;

  const _AnnotationCard({
    this.title,
    required this.text,
    this.note,
    required this.date,
    required this.isHighlight,
    required this.isSelectionMode,
    required this.isSelected,
    this.onSelectedChanged,
    this.onDelete,
    required this.onTap,
    required this.onLongPress,
    required this.readerSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: isSelected 
            ? YomuConstants.accent.withValues(alpha: 0.1) 
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: YomuConstants.accent,
                    onChanged: onSelectedChanged,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHighlight) ...[
                        Container(
                          padding: const EdgeInsets.only(left: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: YomuConstants.accent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        Text(
                          title ?? 'Bookmark',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (text.isNotEmpty && text != title)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      if (note != null && note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.notes_rounded, 
                                    color: YomuConstants.accent.withValues(alpha: 0.7), 
                                    size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'NOTE',
                                    style: TextStyle(
                                      color: YomuConstants.accent.withValues(alpha: 0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              NoteView(
                                markdown: note!,
                                settings: readerSettings,
                                fontSize: 13,
                                textColor: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                          if (!isSelectionMode && onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, 
                                color: Colors.white24, size: 20),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              style: const ButtonStyle(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
