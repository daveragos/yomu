import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:pdfrx/pdfrx.dart' show PdfOutlineNode;
import '../../../models/book_model.dart';
import '../../../models/bookmark_model.dart';
import '../../../core/constants.dart';

class NavigationSheet extends StatefulWidget {
  final Book book;
  final List<EpubChapter> chapters;
  final List<EpubChapter> tocChapters;
  final List<PdfOutlineNode> pdfOutline;
  final List<PdfOutlineNode> tocPdfOutline;
  final int currentChapterIndex;
  final Function(int) onChapterTap;
  final Function(PdfOutlineNode) onPdfOutlineTap;
  final Future<List<Bookmark>> Function() getBookmarks;
  final Function(Bookmark) onDeleteBookmark;
  final Function(Bookmark) onBookmarkTap;
  final String Function(DateTime) formatDate;
  final Function(int)? onJumpToPage;
  final Function(double)? onJumpToPercent;
  final bool focusJump;
  final int totalPages;

  const NavigationSheet({
    super.key,
    required this.book,
    required this.chapters,
    required this.tocChapters,
    required this.pdfOutline,
    required this.tocPdfOutline,
    required this.currentChapterIndex,
    required this.onChapterTap,
    required this.onPdfOutlineTap,
    required this.getBookmarks,
    required this.onDeleteBookmark,
    required this.onBookmarkTap,
    required this.formatDate,
    this.onJumpToPage,
    this.onJumpToPercent,
    this.focusJump = false,
    this.totalPages = 0,
  });

  @override
  State<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<NavigationSheet> {
  final TextEditingController _jumpController = TextEditingController();
  final FocusNode _jumpFocusNode = FocusNode();

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
                Tab(text: 'BOOKMARKS'),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
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

  Widget _buildChaptersList() {
    if (widget.book.filePath.toLowerCase().endsWith('.epub')) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: widget.tocChapters.map((chapter) {
          return _ChapterTreeItem(
            chapter: chapter,
            depth: 0,
            currentChapterIndex: widget.currentChapterIndex,
            flattenedChapters: widget.chapters,
            onTap: widget.onChapterTap,
          );
        }).toList(),
      );
    } else {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: widget.tocPdfOutline.map((node) {
          return _PdfTreeItem(
            node: node,
            depth: 0,
            onTap: widget.onPdfOutlineTap,
          );
        }).toList(),
      );
    }
  }

  Widget _buildBookmarksList() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return FutureBuilder<List<Bookmark>>(
          future: widget.getBookmarks(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No bookmarks found',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            final bookmarks = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  title: Text(
                    bookmark.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${(bookmark.progress * 100).toStringAsFixed(1)}% • ${widget.formatDate(bookmark.createdAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white38,
                    ),
                    onPressed: () async {
                      await widget.onDeleteBookmark(bookmark);
                      setSheetState(() {});
                    },
                  ),
                  onTap: () => widget.onBookmarkTap(bookmark),
                );
              },
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

  const _PdfTreeItem({
    required this.node,
    required this.depth,
    required this.onTap,
  });

  @override
  State<_PdfTreeItem> createState() => _PdfTreeItemState();
}

class _PdfTreeItemState extends State<_PdfTreeItem> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.node.children.isNotEmpty;

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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
              );
            }).toList(),
          ),
      ],
    );
  }
}
