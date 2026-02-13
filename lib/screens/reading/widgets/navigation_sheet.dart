import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:pdfrx/pdfrx.dart' show PdfOutlineNode;
import '../../../models/book_model.dart';
import '../../../models/bookmark_model.dart';
import '../../../models/highlight_model.dart';
import '../../../core/constants.dart';

class NavigationSheet extends StatelessWidget {
  final Book book;
  final List<EpubChapter> chapters;
  final List<PdfOutlineNode> pdfOutline;
  final int currentChapterIndex;
  final Function(int) onChapterTap;
  final Function(PdfOutlineNode) onPdfOutlineTap;
  final Future<List<Bookmark>> Function() getBookmarks;
  final Function(Bookmark) onDeleteBookmark;
  final Function(Bookmark) onBookmarkTap;
  final List<Highlight> highlights;
  final Function(int) onDeleteHighlight;
  final Function(Highlight) onHighlightTap;
  final String Function(DateTime) formatDate;

  const NavigationSheet({
    super.key,
    required this.book,
    required this.chapters,
    required this.pdfOutline,
    required this.currentChapterIndex,
    required this.onChapterTap,
    required this.onPdfOutlineTap,
    required this.getBookmarks,
    required this.onDeleteBookmark,
    required this.onBookmarkTap,
    required this.highlights,
    required this.onDeleteHighlight,
    required this.onHighlightTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                Tab(text: 'HIGHLIGHTS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildChaptersList(),
                  _buildBookmarksList(),
                  _buildHighlightsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          final isCurrent = currentChapterIndex == index;

          return ListTile(
            title: Text(
              chapter.Title ?? 'Chapter ${index + 1}',
              style: TextStyle(
                color: isCurrent ? YomuConstants.accent : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => onChapterTap(index),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pdfOutline.length,
        itemBuilder: (context, index) {
          final node = pdfOutline[index];
          return ListTile(
            contentPadding: EdgeInsets.only(
              left: 16.0 + (node.dest?.pageNumber != null ? 0 : 16),
              right: 16,
            ),
            title: Text(
              node.title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () => onPdfOutlineTap(node),
          );
        },
      );
    }
  }

  Widget _buildBookmarksList() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return FutureBuilder<List<Bookmark>>(
          future: getBookmarks(),
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
                    '${(bookmark.progress * 100).toStringAsFixed(1)}% • ${formatDate(bookmark.createdAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white38,
                    ),
                    onPressed: () async {
                      await onDeleteBookmark(bookmark);
                      setSheetState(() {});
                    },
                  ),
                  onTap: () => onBookmarkTap(bookmark),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHighlightsList() {
    if (highlights.isEmpty) {
      return const Center(
        child: Text(
          'No highlights found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Sort highlights by date descending
    final sortedHighlights = List<Highlight>.from(highlights)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedHighlights.length,
      itemBuilder: (context, index) {
        final highlight = sortedHighlights[index];
        final color = Color(
          int.parse(highlight.color.replaceFirst('#', '0xFF')),
        );

        return ListTile(
          leading: Icon(Icons.circle, color: color, size: 16),
          title: Text(
            highlight.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            '${highlight.chapterTitle ?? "Unknown Chapter"} • ${formatDate(highlight.createdAt)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () => onDeleteHighlight(highlight.id!),
          ),
          onTap: () => onHighlightTap(highlight),
        );
      },
    );
  }
}
