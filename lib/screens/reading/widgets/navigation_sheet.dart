import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:epub_view/epub_view.dart' show EpubChapter;
import 'package:pdfrx/pdfrx.dart' show PdfOutlineNode;

import '../../../models/book_model.dart';
import '../../../models/bookmark_model.dart';
import '../../../models/highlight_model.dart';
import '../../../models/vocabulary_model.dart';
import '../../../models/reader_settings_model.dart';
import '../../../core/constants.dart';
import '../../../models/annotation_reply_model.dart';
import '../../../services/database_service.dart';
import '../../../utils/annotation_order.dart';
import './note_author_avatar.dart';
import './note_card_sheet.dart';
import './note_view.dart';
import './voice_note_player.dart';
import './share_quote_sheet.dart';

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
  final Future<List<VocabularyLookup>> Function() getVocabulary;
  final List<Highlight> highlights;
  final Function(Highlight) onHighlightTap;
  final Future<void> Function(int) onDeleteHighlight;
  final Future<void> Function(List<int>) onDeleteHighlights;
  final Future<void> Function(Bookmark) onDeleteBookmark;
  final Future<void> Function(List<Bookmark>) onDeleteBookmarks;
  final void Function(Bookmark) onBookmarkTap;
  final Future<void> Function(Highlight) onUpdateHighlight;
  final Function(String)? onLookup;
  final String Function(DateTime) formatDate;
  final void Function(int)? onJumpToPage;
  final void Function(double)? onJumpToPercent;
  final VoidCallback? onExport;
  final VoidCallback? onShareAnnotated;

  /// Readers whose notes are hidden in the text ('' is the reader's own).
  final Set<String> hiddenAuthors;
  final Future<void> Function(String? author, bool hidden)? onSetAuthorHidden;

  /// Starts stepping through these notes in the text.
  final void Function(List<Highlight> notes)? onWalkThrough;
  final bool focusJump;
  final int totalPages;

  /// From the [DraggableScrollableSheet] hosting this sheet: the lists use
  /// it so that scrolling them resizes the sheet first.
  final ScrollController? scrollController;

  /// Resizes the hosting sheet when its handle is dragged.
  final DraggableScrollableController? sheetController;

  /// Sizes of the hosting sheet, as a share of the screen height.
  static const initialSize = 0.7;
  static const minSize = 0.3;
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
    required this.getVocabulary,
    required this.highlights,
    required this.onHighlightTap,
    required this.onDeleteHighlight,
    required this.onDeleteHighlights,
    required this.onDeleteBookmark,
    required this.onDeleteBookmarks,
    required this.onBookmarkTap,
    required this.onUpdateHighlight,
    this.onLookup,
    required this.formatDate,
    this.onJumpToPage,
    this.onJumpToPercent,
    this.onExport,
    this.onShareAnnotated,
    this.hiddenAuthors = const {},
    this.onSetAuthorHidden,
    this.onWalkThrough,
    this.focusJump = false,
    this.totalPages = 0,
    this.scrollController,
    this.sheetController,
    required this.readerSettings,
  });

  @override
  State<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<NavigationSheet> {
  bool get _isPdf => widget.book.filePath.toLowerCase().endsWith('.pdf');

  final TextEditingController _jumpController = TextEditingController();
  final FocusNode _jumpFocusNode = FocusNode();

  bool _isSelectionMode = false;
  final Set<int> _selectedHighlightIds = {};
  final Set<int> _selectedBookmarkIds = {};
  final Set<int> _selectedVocabularyIds = {};
  Future<List<dynamic>>? _annotationsFuture;
  String? _selectedFilterColor;

  /// Filters for the notes list.
  String _search = '';
  String? _authorFilter; // null: everyone; '': the reader's own
  bool _voiceOnly = false;
  late final Set<String> _hiddenAuthors = {...widget.hiddenAuthors};

  List<String?> get _chapterTitles => [for (final c in widget.chapters) c.Title];

  /// Notes matching the filters, in reading order.
  List<Highlight> _filterNotes(
    List<Highlight> highlights,
    List<AnnotationReply> replies,
  ) {
    final query = _search.trim().toLowerCase();
    final replyText = <String, String>{};
    if (query.isNotEmpty) {
      for (final r in replies) {
        replyText[r.highlightUid] =
            '${replyText[r.highlightUid] ?? ''} ${r.text} ${r.author ?? ''}'
                .toLowerCase();
      }
    }
    final filtered = highlights.where((h) {
      if (_selectedFilterColor != null && h.color != _selectedFilterColor) {
        return false;
      }
      if (_authorFilter != null && (h.sharedBy ?? '') != _authorFilter) {
        return false;
      }
      if (_voiceOnly && !h.hasAudio) return false;
      if (query.isEmpty) return true;
      return h.text.toLowerCase().contains(query) ||
          (h.note?.toLowerCase().contains(query) ?? false) ||
          (h.sharedBy?.toLowerCase().contains(query) ?? false) ||
          (replyText[h.uid]?.contains(query) ?? false);
    });
    return AnnotationOrder.sorted(filtered, isPdf: _isPdf);
  }

  /// Cards for [notes] with a heading wherever the chapter (or page) changes.
  List<Widget> _withSectionHeaders(
    List<Highlight> notes,
    Widget Function(Highlight h) card,
  ) {
    final widgets = <Widget>[];
    int? section;
    for (final h in notes) {
      if (h.chapterIndex != section) {
        section = h.chapterIndex;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              AnnotationOrder.location(
                h,
                isPdf: _isPdf,
                chapterTitles: _chapterTitles,
              ).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }
      widgets.add(card(h));
    }
    return widgets;
  }

  void _openNoteCard(Highlight h, StateSetter setSheetState) {
    showNoteCard(
      context,
      highlight: h,
      settings: widget.readerSettings,
      location: AnnotationOrder.location(
        h,
        isPdf: _isPdf,
        chapterTitles: _chapterTitles,
      ),
      onUpdate: widget.onUpdateHighlight,
      onDelete: widget.onDeleteHighlight,
      onGoTo: () => widget.onHighlightTap(h),
    ).then((_) {
      if (!mounted) return;
      setState(_refreshAnnotations);
      setSheetState(() {});
    });
  }

  Future<void> _toggleHidden(String key) async {
    final hidden = !_hiddenAuthors.contains(key);
    setState(() {
      hidden ? _hiddenAuthors.add(key) : _hiddenAuthors.remove(key);
    });
    await widget.onSetAuthorHidden?.call(key.isEmpty ? null : key, hidden);
  }

  @override
  void initState() {
    super.initState();
    _refreshAnnotations();
    if (widget.focusJump) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpFocusNode.requestFocus();
      });
    }
  }

  void _refreshAnnotations() {
    _annotationsFuture = Future.wait([
      widget.getBookmarks(),
      widget.getHighlights(),
      widget.getVocabulary(),
      if (widget.book.id != null)
        DatabaseService().getRepliesForBook(widget.book.id!)
      else
        Future.value(<AnnotationReply>[]),
    ]);
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _jumpFocusNode.dispose();
    super.dispose();
  }

  /// Dragging the handle resizes the sheet like dragging a list does; the
  /// smallest size closes it.
  void _onHandleDragUpdate(DragUpdateDetails details) {
    final controller = widget.sheetController;
    final height = MediaQuery.of(context).size.height;
    if (controller == null || !controller.isAttached || height <= 0) return;
    try {
      controller.jumpTo(
        (controller.size - (details.primaryDelta ?? 0) / height).clamp(
          NavigationSheet.minSize,
          1.0,
        ),
      );
    } catch (e) {
      // Both tabs' lists are attached mid tab-swipe; skip that frame.
      debugPrint('Sheet drag skipped: $e');
    }
  }

  /// A fling on the handle opens the sheet fully or closes it; otherwise it
  /// stays where it was let go.
  void _onHandleDragEnd(DragEndDetails details) {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 1200) return;
    final media = MediaQuery.of(context);
    final max = ((media.size.height - media.padding.top - 8) /
            media.size.height)
        .clamp(NavigationSheet.initialSize, 1.0);
    try {
      controller.animateTo(
        velocity < 0 ? max : NavigationSheet.minSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      debugPrint('Sheet fling skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        // Inside a DraggableScrollableSheet the sheet sets the height.
        height: widget.scrollController == null
            ? MediaQuery.of(context).size.height * NavigationSheet.initialSize
            : null,
        decoration: const BoxDecoration(
          color: YomuConstants.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onHandleDragUpdate,
              onVerticalDragEnd: _onHandleDragEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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

  Future<void> _shareSelectedAsMarkdown(
    List<Bookmark> bookmarks,
    List<Highlight> highlights,
    List<VocabularyLookup> allVocabulary,
  ) async {
    bool includeVocabulary = false;

    if (allVocabulary.isNotEmpty) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          bool includeVocab = true;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: YomuConstants.surface,
                title: const Text(
                  'Export Annotations',
                  style: TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ready to export your selections as Markdown.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text(
                        'Include Vocabulary List',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Add words you looked up in this book',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      value: includeVocab,
                      activeColor: YomuConstants.accent,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setDialogState(() => includeVocab = val ?? true),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, includeVocab),
                    child: const Text(
                      'SHARE',
                      style: TextStyle(color: YomuConstants.accent),
                    ),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            },
          );
        },
      );
      if (result == null) return; // Cancelled
      includeVocabulary = result;
    }

    final buffer = StringBuffer();
    buffer.writeln('# ${widget.book.title} - Selected Annotations');
    buffer.writeln('*Exported with Yomu — ${DateTime.now().year}*');
    buffer.writeln();
    if (widget.book.author.isNotEmpty) {
      buffer.writeln('**Author:** ${widget.book.author}');
    }
    buffer.writeln('**Shared on:** ${widget.formatDate(DateTime.now())}');
    buffer.writeln();

    if (bookmarks.isNotEmpty) {
      buffer.writeln('## Bookmarks');
      for (final b in bookmarks) {
        buffer.writeln(
          '- ${b.title} (${(b.progress * 100).toStringAsFixed(1)}%) — ${widget.formatDate(b.createdAt)}',
        );
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
        final pos = !_isPdf && h.position.contains(':')
            ? 'Chapter ${(int.tryParse(h.position.split(':')[0]) ?? h.chapterIndex) + 1}'
            : 'Page ${h.chapterIndex + 1}';
        buffer.writeln('*Position: $pos — ${widget.formatDate(h.createdAt)}*');
        buffer.writeln('---');
      }
    }

    if (includeVocabulary && allVocabulary.isNotEmpty) {
      buffer.writeln('## Vocabulary List');
      buffer.writeln(allVocabulary.map((v) => v.word).join(', '));
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln('*Exported with Yomu*');

    try {
      final directory = await getTemporaryDirectory();
      final fileName =
          'yomu_selection_${DateTime.now().millisecondsSinceEpoch}.md';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<void> _shareQuotes(List<Highlight> highlights) async {
    if (highlights.isEmpty) return;

    final quoteText = highlights.map((h) => h.text).join(' ... ');

    if (mounted) {
      ShareQuoteSheet.show(
        context,
        text: quoteText,
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
      );
    }
  }

  Widget _buildChaptersList() {
    if (widget.book.filePath.toLowerCase().endsWith('.epub')) {
      return SingleChildScrollView(
        controller: widget.scrollController,
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
        controller: widget.scrollController,
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
          future: _annotationsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bookmarks = snapshot.data![0] as List<Bookmark>;
            final highlights = snapshot.data![1] as List<Highlight>;
            final vocabulary = snapshot.data![2] as List<VocabularyLookup>;
            final replies = snapshot.data![3] as List<AnnotationReply>;
            final replyCounts = <String, int>{};
            for (final r in replies) {
              replyCounts[r.highlightUid] =
                  (replyCounts[r.highlightUid] ?? 0) + 1;
            }

            if (bookmarks.isEmpty && highlights.isEmpty && vocabulary.isEmpty) {
              // Scrollable, so dragging here resizes the sheet too.
              return SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 64,
                      color: Colors.white10,
                    ),
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
                ),
              );
            }

            final filteredHighlights = _filterNotes(highlights, replies);
            final filtersActive =
                _selectedFilterColor != null ||
                _authorFilter != null ||
                _voiceOnly ||
                _search.trim().isNotEmpty;

            return Column(
              children: [
                _AnnotationHeader(
                  count: filtersActive
                      ? filteredHighlights.length
                      : bookmarks.length + highlights.length + vocabulary.length,
                  isSelectionMode: _isSelectionMode,
                  selectedCount:
                      _selectedHighlightIds.length +
                      _selectedBookmarkIds.length +
                      _selectedVocabularyIds.length,
                  onToggleSelection: () =>
                      setSheetState(() => _isSelectionMode = true),
                  onCloseSelection: () => setSheetState(() {
                    _isSelectionMode = false;
                    _selectedHighlightIds.clear();
                    _selectedBookmarkIds.clear();
                    _selectedVocabularyIds.clear();
                  }),
                  onDeleteSelected: () async {
                    if (_selectedHighlightIds.isNotEmpty) {
                      await widget.onDeleteHighlights(
                        _selectedHighlightIds.toList(),
                      );
                    }
                    if (_selectedBookmarkIds.isNotEmpty) {
                      final toDelete = bookmarks
                          .where((b) => _selectedBookmarkIds.contains(b.id))
                          .toList();
                      await widget.onDeleteBookmarks(toDelete);
                    }
                    
                    setState(() {
                      _refreshAnnotations();
                      _isSelectionMode = false;
                      _selectedHighlightIds.clear();
                      _selectedBookmarkIds.clear();
                      _selectedVocabularyIds.clear();
                    });
                    setSheetState(() {});
                  },
                  onExport: widget.onExport,
                  onShareAnnotated: widget.onShareAnnotated,
                  onShareSelected: () {
                    final selectedHighlights = highlights
                        .where((h) => _selectedHighlightIds.contains(h.id))
                        .toList();
                    final selectedBookmarks = bookmarks
                        .where((b) => _selectedBookmarkIds.contains(b.id))
                        .toList();
                    final selectedVocabulary = vocabulary
                        .where((v) => _selectedVocabularyIds.contains(v.id))
                        .toList();
                    _shareSelectedAsMarkdown(
                      selectedBookmarks,
                      selectedHighlights,
                      _isSelectionMode ? selectedVocabulary : vocabulary,
                    );
                  },
                  onShareQuote: () {
                    final selectedHighlights = highlights
                        .where((h) => _selectedHighlightIds.contains(h.id))
                        .toList();
                    _shareQuotes(selectedHighlights);
                  },
                ),
                Expanded(
                  child: ListView(
                    // Scrolling the notes resizes the sheet first.
                    controller: widget.scrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      // The filters scroll away with the notes, leaving the
                      // whole sheet to them.
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
                      if (!_isSelectionMode && highlights.isNotEmpty)
                        _NoteFiltersBar(
                          highlights: highlights,
                          search: _search,
                          authorFilter: _authorFilter,
                          voiceOnly: _voiceOnly,
                          hiddenAuthors: _hiddenAuthors,
                          canHide: widget.onSetAuthorHidden != null,
                          onSearch: (q) => setSheetState(() => _search = q),
                          onAuthor: (a) => setSheetState(() => _authorFilter = a),
                          onVoiceOnly: (v) => setSheetState(() => _voiceOnly = v),
                          onToggleHidden: (key) async {
                            await _toggleHidden(key);
                            setSheetState(() {});
                          },
                          onWalkThrough:
                              widget.onWalkThrough == null ||
                                  !filteredHighlights.any(
                                    (h) => h.hasNote || h.hasAudio,
                                  )
                              ? null
                              : () => widget.onWalkThrough!(
                                  filteredHighlights
                                      .where((h) => h.hasNote || h.hasAudio)
                                      .toList(),
                                ),
                        ),

                      if (bookmarks.isNotEmpty && !filtersActive) ...[
                        ...bookmarks.map((bookmark) {
                          final isSelected =
                              bookmark.id != null &&
                              _selectedBookmarkIds.contains(bookmark.id!);
                          return _AnnotationCard(
                            readerSettings: widget.readerSettings,
                            title: bookmark.title,
                            text:
                                '${(bookmark.progress * 100).toStringAsFixed(1)}%',
                            date: widget.formatDate(bookmark.createdAt),
                            isHighlight: false,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onSelectedChanged: (val) {
                              setSheetState(() {
                                if (val == true && bookmark.id != null) {
                                  _selectedBookmarkIds.add(bookmark.id!);
                                } else if (bookmark.id != null) {
                                  _selectedBookmarkIds.remove(bookmark.id!);
                                }
                              });
                            },
                            onDelete: () async {
                              await widget.onDeleteBookmark(bookmark);
                              setState(() {
                                _refreshAnnotations();
                              });
                              setSheetState(() {});
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                setSheetState(() {
                                  if (bookmark.id != null) {
                                    if (isSelected) {
                                      _selectedBookmarkIds.remove(bookmark.id!);
                                    } else {
                                      _selectedBookmarkIds.add(bookmark.id!);
                                    }
                                  }
                                });
                              } else {
                                widget.onBookmarkTap(bookmark);
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode && bookmark.id != null) {
                                setSheetState(() {
                                  _isSelectionMode = true;
                                  _selectedBookmarkIds.add(bookmark.id!);
                                });
                              }
                            },
                          );
                        }),
                      ],
                      if (filtersActive && filteredHighlights.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No notes match.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                      if (filteredHighlights.isNotEmpty) ...[
                        ..._withSectionHeaders(filteredHighlights, (h) {
                          final isSelected = _selectedHighlightIds.contains(
                            h.id,
                          );
                          return _AnnotationCard(
                            readerSettings: widget.readerSettings,
                            text: h.text,
                            note: h.note,
                            audioFile: h.audioFile,
                            audioDurationMs: h.audioDurationMs,
                            audioWaveform: h.audioWaveform,
                            sharedBy: h.sharedBy,
                            replyCount: replyCounts[h.uid] ?? 0,
                            isPrivate: h.isPrivate,
                            isUnplaced: h.isUnplaced,
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
                                setState(() {
                                  _refreshAnnotations();
                                });
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
                                widget.onHighlightTap(h);
                              }
                            },
                            onNoteTap: () {
                              if (!_isSelectionMode) {
                                _openNoteCard(h, setSheetState);
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
                      if (vocabulary.isNotEmpty && !filtersActive) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Text(
                            'VOCABULARY',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: vocabulary.map((v) {
                              final isSelected = v.id != null && _selectedVocabularyIds.contains(v.id!);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: FilterChip(
                                  label: Text(
                                    v.word,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isSelected && _isSelectionMode,
                                  onSelected: (selected) {
                                    if (_isSelectionMode && v.id != null) {
                                      setSheetState(() {
                                        if (selected) {
                                          _selectedVocabularyIds.add(v.id!);
                                        } else {
                                          _selectedVocabularyIds.remove(v.id!);
                                        }
                                      });
                                    } else {
                                      widget.onLookup?.call(v.word);
                                    }
                                  },
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  selectedColor: YomuConstants.accent,
                                  checkmarkColor: Colors.black,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
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
  final VoidCallback onShareQuote;
  final VoidCallback? onExport;
  final VoidCallback? onShareAnnotated;

  const _AnnotationHeader({
    required this.count,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onToggleSelection,
    required this.onDeleteSelected,
    required this.onCloseSelection,
    required this.onShareSelected,
    required this.onShareQuote,
    this.onExport,
    this.onShareAnnotated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSelectionMode ? "$selectedCount SELECTED" : "ANNOTATIONS",
                  style: const TextStyle(
                    color: YomuConstants.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (!isSelectionMode)
                  Text(
                    "$count items",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(
                Icons.format_quote_rounded,
                color: YomuConstants.accent,
                size: 20,
              ),
              onPressed: selectedCount > 0 ? onShareQuote : null,
              tooltip: 'Share as Quote',
            ),
            IconButton(
              icon: const Icon(
                Icons.ios_share_rounded,
                color: YomuConstants.accent,
                size: 20,
              ),
              onPressed: selectedCount > 0 ? onShareSelected : null,
              tooltip: 'Share Markdown',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: selectedCount > 0 ? onDeleteSelected : null,
              tooltip: 'Delete selected',
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: onCloseSelection,
              tooltip: 'Cancel selection',
            ),
          ] else ...[
            if (onShareAnnotated != null)
              IconButton(
                icon: const Icon(
                  Icons.group_add_outlined,
                  color: YomuConstants.accent,
                  size: 20,
                ),
                onPressed: onShareAnnotated,
                tooltip: 'Share book with annotations',
              ),
            if (onExport != null)
              IconButton(
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: YomuConstants.accent,
                  size: 18,
                ),
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
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilterChip(
              label: const Text(
                'ALL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              selected: selectedColor == null,
              onSelected: (_) => onColorTap(null),
              backgroundColor: Colors.transparent,
              selectedColor: YomuConstants.accent.withValues(alpha: 0.2),
              checkmarkColor: YomuConstants.accent,
              side: BorderSide(
                color: selectedColor == null
                    ? YomuConstants.accent
                    : Colors.white10,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          ...YomuConstants.highlightColors.map((color) {
            final hexColor =
                '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
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
                side: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                ),
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
  final String? audioFile;
  final int? audioDurationMs;
  final String? audioWaveform;
  final String? sharedBy;
  final int replyCount;
  final bool isPrivate;
  final bool isUnplaced;
  final String date;
  final bool isHighlight;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onDelete;
  final VoidCallback onTap;
  final VoidCallback? onNoteTap;
  final VoidCallback onLongPress;
  final ReaderSettings readerSettings;

  const _AnnotationCard({
    this.title,
    required this.text,
    this.note,
    this.audioFile,
    this.audioDurationMs,
    this.audioWaveform,
    this.sharedBy,
    this.replyCount = 0,
    this.isPrivate = false,
    this.isUnplaced = false,
    required this.date,
    required this.isHighlight,
    required this.isSelectionMode,
    required this.isSelected,
    this.onSelectedChanged,
    this.onDelete,
    required this.onTap,
    this.onNoteTap,
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
                      if (sharedBy != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: YomuConstants.accent.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Shared by $sharedBy',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: YomuConstants.accent.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
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
                                  Icon(
                                    Icons.notes_rounded,
                                    color: YomuConstants.accent.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'NOTE',
                                    style: TextStyle(
                                      color: YomuConstants.accent.withValues(
                                        alpha: 0.7,
                                      ),
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
                      if (audioFile != null && audioFile!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        VoiceNotePlayer(
                          fileName: audioFile!,
                          durationMs: audioDurationMs,
                          waveform: audioWaveform,
                          dense: true,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isUnplaced
                                        ? 'Not found in your copy · $date'
                                        : date,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUnplaced
                                          ? Colors.amberAccent.withValues(
                                              alpha: 0.7,
                                            )
                                          : Colors.white24,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                if (isPrivate) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 13,
                                    color: Colors.white38,
                                  ),
                                ],
                                if (replyCount > 0) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 13,
                                    color: Colors.white38,
                                  ),
                                  Text(
                                    ' $replyCount',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (!isSelectionMode &&
                                  onNoteTap != null &&
                                  isHighlight)
                                IconButton(
                                  icon: Icon(
                                    (note != null && note!.isNotEmpty) ||
                                            (audioFile != null &&
                                                audioFile!.isNotEmpty)
                                        ? Icons.sticky_note_2_outlined
                                        : Icons.add_comment_outlined,
                                    color: YomuConstants.accent,
                                    size: 20,
                                  ),
                                  onPressed: onNoteTap,
                                  padding: const EdgeInsets.only(right: 8),
                                  constraints: const BoxConstraints(),
                                  style: const ButtonStyle(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  tooltip: 'View/Edit Note',
                                ),
                              if (!isSelectionMode && onDelete != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white24,
                                    size: 20,
                                  ),
                                  onPressed: onDelete,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: const ButtonStyle(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
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

/// Search, people and voice filters for the notes list. Each person chip
/// also has an eye to show or hide that reader's notes in the text.
class _NoteFiltersBar extends StatefulWidget {
  final List<Highlight> highlights;
  final String search;
  final String? authorFilter;
  final bool voiceOnly;
  final Set<String> hiddenAuthors;
  final bool canHide;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onAuthor;
  final ValueChanged<bool> onVoiceOnly;
  final ValueChanged<String> onToggleHidden;
  final VoidCallback? onWalkThrough;

  const _NoteFiltersBar({
    required this.highlights,
    required this.search,
    required this.authorFilter,
    required this.voiceOnly,
    required this.hiddenAuthors,
    required this.canHide,
    required this.onSearch,
    required this.onAuthor,
    required this.onVoiceOnly,
    required this.onToggleHidden,
    required this.onWalkThrough,
  });

  @override
  State<_NoteFiltersBar> createState() => _NoteFiltersBarState();
}

class _NoteFiltersBarState extends State<_NoteFiltersBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.search,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// '' for the reader's own notes, then the other readers by name.
  List<String> get _authors {
    final names = <String>{};
    var mine = false;
    for (final h in widget.highlights) {
      if (h.sharedBy == null) {
        mine = true;
      } else {
        names.add(h.sharedBy!);
      }
    }
    return [if (mine) '', ...names.toList()..sort()];
  }

  Widget _chip({
    required bool selected,
    required VoidCallback onTap,
    required Widget label,
    Widget? leading,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? YomuConstants.accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? YomuConstants.accent : Colors.white10,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 6)],
                label,
                if (trailing != null) trailing else const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authors = _authors;
    final showPeople = authors.length > 1 || authors.any((a) => a.isNotEmpty);
    const labelStyle = TextStyle(color: Colors.white70, fontSize: 12);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _controller,
              onChanged: widget.onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search notes, replies, names',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                suffixIcon: widget.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () {
                          _controller.clear();
                          widget.onSearch('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (widget.onWalkThrough != null)
                  _chip(
                    selected: false,
                    onTap: widget.onWalkThrough!,
                    leading: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: YomuConstants.accent,
                    ),
                    label: const Text(
                      'Walk through',
                      style: TextStyle(
                        color: YomuConstants.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (showPeople) ...[
                  _chip(
                    selected: widget.authorFilter == null,
                    onTap: () => widget.onAuthor(null),
                    label: const Text('Everyone', style: labelStyle),
                  ),
                  for (final key in authors)
                    _chip(
                      selected: widget.authorFilter == key,
                      onTap: () => widget.onAuthor(
                        widget.authorFilter == key ? null : key,
                      ),
                      leading: NoteAuthorAvatar(
                        name: key.isEmpty ? null : key,
                        size: 20,
                      ),
                      label: Text(
                        noteAuthorName(key.isEmpty ? null : key),
                        style: labelStyle.copyWith(
                          decoration: widget.hiddenAuthors.contains(key)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: widget.canHide
                          ? Tooltip(
                              message: widget.hiddenAuthors.contains(key)
                                  ? 'Show in the text'
                                  : 'Hide in the text',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => widget.onToggleHidden(key),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    widget.hiddenAuthors.contains(key)
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                ],
                _chip(
                  selected: widget.voiceOnly,
                  onTap: () => widget.onVoiceOnly(!widget.voiceOnly),
                  leading: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: const Text('With voice', style: labelStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
