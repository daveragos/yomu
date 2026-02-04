import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_view/epub_view.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/constants.dart';
import '../components/display_settings_sheet.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../models/book_model.dart';
import '../models/reader_settings_model.dart';
import '../models/bookmark_model.dart';
import '../models/search_result_model.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen>
    with TickerProviderStateMixin {
  EpubController? _epubController;
  int _pdfPages = 0;
  int _pdfCurrentPage = 0;
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _isPullingDownNotifier = ValueNotifier(false);
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier(0.0);
  bool _shouldJumpToBottom = false;
  double _initialScrollProgress = 0.0;

  final double _pullTriggerDistance = 80.0;
  final double _pullDeadzone = 8.0; // Slightly more sensitive
  Timer? _heartbeatTimer;
  Timer? _debounceTimer;
  bool _isPdfReady = false;
  final String _pdfErrorMessage = '';
  DateTime _lastSyncTime = DateTime.now();
  int _lastSyncPage = 0;
  bool _initialized = false;
  int _accumulatedSeconds = 0;
  DateTime _lastInteractionTime = DateTime.now();
  PdfViewerController? _pdfController;
  final Duration _idlenessTimeout = const Duration(minutes: 2);

  // Audio state
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<Duration> _audioPositionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _audioDurationNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<bool> _isAudioPlayingNotifier = ValueNotifier(false);
  bool _isAudioLoading = false;

  // Reading mode state
  double _playbackSpeed = 1.0;
  String _currentChapter = 'Chapter 1';
  List<EpubChapter> _chapters = [];
  List<PdfOutlineNode> _pdfOutline = [];
  PageController? _pageController;
  int _currentChapterIndex = 0;

  // UI state
  bool _showControls = true;
  String _currentTime = '';
  Timer? _currentTimeTimer;
  Timer? _audioDebounceTimer;
  String? _loadedAudioBookId;
  DateTime _lastAudioSaveTime = DateTime.now();
  int _lastSavedAudioMs = -1;
  bool _isAudioControlsExpanded = false;
  bool _isAutoScrolling = false;
  final ValueNotifier<double> _autoScrollSpeedNotifier = ValueNotifier(0.0);
  Ticker? _pdfAutoScrollTicker;
  bool _isNavigationSheetOpen = false;
  bool _isDraggingSlider = false;
  double _sliderDragValue = 0.0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearchLoading = false;
  final FocusNode _searchFocusNode = FocusNode();
  String? _activeSearchQuery;
  bool _isSearchResultsCollapsed = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _currentTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _initAudio();

    _pdfAutoScrollTicker = createTicker((elapsed) {
      if (_isAutoScrolling && _pdfController != null) {
        // NOTE: PdfViewerController API varies across versions.
        // We'll implement smooth scrolling once we verify the standard scroll controller access.
        // For now, auto-scroll is primarily optimized for EPUBS.
      }
    });
    _autoScrollSpeedNotifier.addListener(_handleGlobalSpeedChange);
  }

  void _handleGlobalSpeedChange() {
    final book = ref.read(currentlyReadingProvider);
    if (book != null && !book.filePath.toLowerCase().endsWith('.epub')) {
      if (_autoScrollSpeedNotifier.value > 0) {
        if (!(_pdfAutoScrollTicker?.isActive ?? false)) {
          _pdfAutoScrollTicker?.start();
        }
      } else {
        _pdfAutoScrollTicker?.stop();
      }
    }
  }

  void _initAudio() {
    _audioPlayer.positionStream.listen((pos) {
      if (!_isDraggingSlider) {
        _audioPositionNotifier.value = pos;
      }
      _maybeSaveAudioPosition(pos);
    });
    _audioPlayer.durationStream.listen((dur) {
      _audioDurationNotifier.value = dur ?? Duration.zero;
    });
    _audioPlayer.playerStateStream.listen((state) {
      _isAudioPlayingNotifier.value = state.playing;
    });
  }

  void _maybeSaveAudioPosition(Duration pos) {
    if (_loadedAudioBookId == null || _isAudioLoading) return;

    final now = DateTime.now();
    final currentMs = pos.inMilliseconds;

    // save at most every 10 seconds OR if seek is large (> 5s)
    final diff = (currentMs - _lastSavedAudioMs).abs();
    final timeSinceLastSave = now.difference(_lastAudioSaveTime);

    if (timeSinceLastSave > const Duration(seconds: 10) || diff > 5000) {
      _performAudioSave(currentMs);
    }
  }

  void _performAudioSave(int ms) {
    final book = ref.read(currentlyReadingProvider);
    if (book != null && book.id.toString() == _loadedAudioBookId) {
      _lastAudioSaveTime = DateTime.now();
      _lastSavedAudioMs = ms;
      ref
          .read(libraryProvider.notifier)
          .updateBookAudio(book.id!, audioLastPosition: ms);
    }
  }

  Future<void> _loadAudio(
    String path, {
    int? initialPositionMs,
    required String bookId,
  }) async {
    try {
      _loadedAudioBookId = bookId;
      setState(() => _isAudioLoading = true);
      await _audioPlayer.setFilePath(path);
      if (initialPositionMs != null && initialPositionMs > 0) {
        await _audioPlayer.seek(Duration(milliseconds: initialPositionMs));
      }
      setState(() => _isAudioLoading = false);
    } catch (e) {
      _loadedAudioBookId = null;
      setState(() => _isAudioLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
  }

  Future<void> _pickAudio(Book book) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await ref
          .read(libraryProvider.notifier)
          .updateBookAudio(book.id!, audioPath: path);
      _loadAudio(path, bookId: book.id.toString());
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (_currentTime != timeStr) {
      setState(() {
        _currentTime = timeStr;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _epubController?.dispose();
    _pageController?.dispose();
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();
    _currentTimeTimer?.cancel();
    _audioDebounceTimer?.cancel();
    _pullDistanceNotifier.dispose();
    _isPullingDownNotifier.dispose();
    _scrollProgressNotifier.dispose();
    _audioPositionNotifier.dispose();
    _audioDurationNotifier.dispose();
    _isAudioPlayingNotifier.dispose();
    _autoScrollSpeedNotifier.removeListener(_handleGlobalSpeedChange);
    _pdfAutoScrollTicker?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _recordInteraction() {
    _lastInteractionTime = DateTime.now();
  }

  void _addBookmark(Book book) async {
    final progress = _calculateCurrentProgress(book);
    String position = '0';

    if (book.filePath.toLowerCase().endsWith('.epub')) {
      // Save chapter index and personal scroll progress for precision
      position = '$_currentChapterIndex:${_scrollProgressNotifier.value}';
    } else if (book.filePath.toLowerCase().endsWith('.pdf')) {
      position = (_pdfController?.pageNumber ?? 1).toString();
    }

    String title = 'Bookmark';
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length) {
        title = _chapters[_currentChapterIndex].Title ?? 'Bookmark';
      }
    } else if (_isPdfReady) {
      title = 'Page ${_pdfController?.pageNumber ?? 1}';
    }

    final bookmark = Bookmark(
      bookId: book.id!,
      title: title,
      progress: progress,
      createdAt: DateTime.now(),
      position: position,
    );

    await ref.read(libraryProvider.notifier).addBookmark(bookmark);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Position bookmarked'),
          backgroundColor: YomuConstants.accent,
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
    }
  }

  bool _isIdle() {
    return DateTime.now().difference(_lastInteractionTime) > _idlenessTimeout;
  }

  void _initEpub(Book book) {
    if (_epubController != null) return;
    final controller = EpubController(
      document: EpubDocument.openFile(File(book.filePath)),
      epubCfi: book.lastPosition,
    );
    _epubController = controller;

    // Extract chapters when document is loaded
    controller.document.then((document) {
      final flattenedChapters = _flattenChapters(document.Chapters ?? []);
      setState(() {
        _chapters = flattenedChapters;

        // Find initial chapter index and scroll progress from overall progress
        double totalProgress = book.progress * flattenedChapters.length;
        _currentChapterIndex = totalProgress.floor().clamp(
          0,
          flattenedChapters.length - 1,
        );
        _initialScrollProgress = totalProgress - _currentChapterIndex;

        _pageController = PageController(initialPage: _currentChapterIndex);
        _currentChapter =
            flattenedChapters[_currentChapterIndex].Title ??
            'Chapter ${_currentChapterIndex + 1}';
        _initialized = true;
      });
    });

    _startHeartbeat(book);
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final List<EpubChapter> flattened = [];
    for (final chapter in chapters) {
      flattened.add(chapter);
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        flattened.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return flattened;
  }

  double _calculateCurrentProgress(Book book) {
    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (_pdfPages > 0) {
        return _pdfCurrentPage / (_pdfPages - 1).clamp(1, 1000000);
      }
      return book.progress;
    } else if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (_chapters.isNotEmpty) {
        return (_currentChapterIndex + _scrollProgressNotifier.value) /
            _chapters.length;
      }
    }
    return book.progress;
  }

  void _handleChapterPageChange(int index, Book book) {
    if (index == _currentChapterIndex) return;

    setState(() {
      _shouldJumpToBottom = index < _currentChapterIndex;
      _currentChapterIndex = index;
      _currentChapter = _chapters[index].Title ?? 'Chapter ${index + 1}';
      // Reset scroll progress for new chapter
      _scrollProgressNotifier.value = 0.0;
    });

    _recordInteraction();

    final progress = _calculateCurrentProgress(book);
    final now = DateTime.now();
    final duration = now.difference(_lastSyncTime).inMinutes;

    ref
        .read(libraryProvider.notifier)
        .updateBookProgress(
          book.id!,
          progress,
          pagesRead: 0,
          durationMinutes: duration > 0 ? duration : 0,
        );
    _lastSyncTime = now;
  }

  void _startHeartbeat(Book book) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isIdle()) return;

      _accumulatedSeconds++;
      if (_accumulatedSeconds >= 60) {
        _accumulatedSeconds = 0;
        final progress = _calculateCurrentProgress(book);
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book.id!,
              progress,
              pagesRead: 0,
              durationMinutes: 1,
            );

        // Also save audio position in heartbeat
        if (_loadedAudioBookId == book.id.toString()) {
          _performAudioSave(_audioPlayer.position.inMilliseconds);
        }
      }
    });
  }

  void _handlePdfPageChange(int? page, int? total, Book book) {
    if (page == null || total == null || total == 0) return;

    if (!_initialized) {
      _lastSyncPage = (book.progress * (total - 1)).toInt();
      _lastSyncTime = DateTime.now();
      _initialized = true;
      setState(() {
        _pdfCurrentPage = page;
        _pdfPages = total;
      });

      ref
          .read(libraryProvider.notifier)
          .updateBookProgress(
            book.id!,
            book.progress,
            pagesRead: 0,
            durationMinutes: 0,
            currentPage: page,
            totalPages: total,
          );
      return;
    }

    setState(() {
      _pdfCurrentPage = page;
      _pdfPages = total;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final int pagesRead = (page - _lastSyncPage).clamp(0, 1000);
      final int duration = DateTime.now().difference(_lastSyncTime).inMinutes;
      final progress = _calculateCurrentProgress(book);

      if (pagesRead > 0 || duration >= 1) {
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book.id!,
              progress,
              pagesRead: pagesRead,
              durationMinutes: duration,
              currentPage: page,
              totalPages: total,
            );
        _lastSyncPage = page;
        _lastSyncTime = DateTime.now();
      } else {
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book.id!,
              progress,
              pagesRead: 0,
              durationMinutes: 0,
              currentPage: page,
              totalPages: total,
            );
      }
    });
  }

  void _syncFinalProgress(Book book) {
    // Save audio position early as it doesn't depend on reader initialization
    if (book.audioPath != null) {
      ref
          .read(libraryProvider.notifier)
          .updateBookAudio(
            book.id!,
            audioLastPosition: _audioPlayer.position.inMilliseconds,
          );
    }

    if (!_initialized) return;

    _debounceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _audioDebounceTimer?.cancel();

    final now = DateTime.now();
    int duration = now.difference(_lastSyncTime).inMinutes;

    if (_accumulatedSeconds >= 30) {
      duration += 1;
    }

    int pagesRead = 0;
    double progress = _calculateCurrentProgress(book);
    int currentPage = book.currentPage;
    int totalPages = book.totalPages;

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (_pdfPages > 0) {
        pagesRead = (_pdfCurrentPage - _lastSyncPage).clamp(0, 1000);
        currentPage = _pdfCurrentPage;
        totalPages = _pdfPages;
      }
    }

    if (pagesRead > 0 || duration > 0 || progress != book.progress) {
      ref
          .read(libraryProvider.notifier)
          .updateBookProgress(
            book.id!,
            progress,
            pagesRead: pagesRead,
            durationMinutes: duration,
            currentPage: currentPage,
            totalPages: totalPages,
          );
      _lastSyncTime = now;
      if (book.filePath.toLowerCase().endsWith('.pdf')) {
        _lastSyncPage = _pdfCurrentPage;
      }
    }
    _accumulatedSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(currentlyReadingProvider);
    final settings = ref.watch(readerSettingsProvider);

    // Sync auto-scroll speed if active
    if (_isAutoScrolling &&
        _autoScrollSpeedNotifier.value != settings.autoScrollSpeed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _autoScrollSpeedNotifier.value = settings.autoScrollSpeed;
        }
      });
    }

    if (book == null) {
      return Scaffold(
        backgroundColor: settings.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: settings.textColor.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a book from your library to start reading',
                style: TextStyle(color: settings.secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    final isEpub = book.filePath.toLowerCase().endsWith('.epub');

    if (isEpub) {
      _initEpub(book);
    }

    // Load audio if available and not already loaded for this book
    final hasAudio = book.audioPath != null;
    if (hasAudio && _loadedAudioBookId != book.id.toString()) {
      _loadAudio(
        book.audioPath!,
        initialPositionMs: book.audioLastPosition,
        bookId: book.id.toString(),
      );
    }

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _syncFinalProgress(book);
          }
        },
        child: Container(
          color: settings.backgroundColor,
          child: Column(
            children: [
              // Content Area
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      if (isEpub)
                        _buildEpubContent(book, settings)
                      else
                        _buildPdfContent(book, settings),

                      // Animated Overlay Controls
                      _buildAnimatedControlsOverlay(context, book, settings),

                      if (_pdfErrorMessage.isNotEmpty)
                        Center(
                          child: Text(
                            _pdfErrorMessage,
                            style: TextStyle(color: settings.textColor),
                          ),
                        )
                      else if (!isEpub && !_isPdfReady)
                        Center(
                          child: CircularProgressIndicator(
                            color: YomuConstants.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Minimal Footer (Persistent or animated)
              _buildMinimalFooter(book, settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedControlsOverlay(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    return Stack(
      children: [
        // Top Header
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: _showControls ? 0 : -100,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  settings.backgroundColor,
                  settings.backgroundColor.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildHeader(book, settings)],
              ),
            ),
          ),
        ),

        // Bottom Controls
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _showControls ? 0 : -200,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  settings.backgroundColor,
                  settings.backgroundColor.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: _buildBottomControls(context, book, settings),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Book book, ReaderSettings settings) {
    String pageInfo = '';
    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      pageInfo = '${_pdfCurrentPage + 1} / $_pdfPages';
    } else {
      pageInfo = '${(book.progress * 100).toStringAsFixed(0)}%';
    }

    return Container(
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: settings.textColor,
                    ),
                    onPressed: () {
                      _syncFinalProgress(book);
                      Navigator.of(context).pop();
                    },
                  ),
                  if (_isSearching)
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(color: settings.textColor),
                        decoration: InputDecoration(
                          hintText: 'Search book...',
                          hintStyle: TextStyle(
                            color: settings.secondaryTextColor,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close, color: settings.textColor),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _searchResults = [];
                                _activeSearchQuery = null;
                              });
                            },
                          ),
                        ),
                        onTap: () {
                          if (_isSearchResultsCollapsed) {
                            setState(() => _isSearchResultsCollapsed = false);
                          }
                        },
                        onSubmitted: (value) => _handleSearch(value, book),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentChapter.toUpperCase(),
                            style: TextStyle(
                              color: settings.secondaryTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            book.title,
                            style: TextStyle(
                              color: settings.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.search_rounded,
                        color: settings.textColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                          _showControls = true;
                        });
                        _searchFocusNode.requestFocus();
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: settings.textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pageInfo,
                        style: TextStyle(
                          color: settings.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_isSearching &&
                  _searchResults.isNotEmpty &&
                  !_isSearchResultsCollapsed)
                _buildSearchResultsOverlay(book, settings),
              if (_isSearchResultsCollapsed && _searchResults.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _isSearchResultsCollapsed = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: YomuConstants.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: YomuConstants.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: YomuConstants.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Show ${_searchResults.length} results',
                            style: TextStyle(
                              color: YomuConstants.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isSearchLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  Future<void> _handleSearch(String query, Book book) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _searchResults = [];
    });

    try {
      final List<SearchResult> results = [];
      if (book.filePath.toLowerCase().endsWith('.pdf')) {
        // PDF Search is partially handled by built-in pdfrx features
        // but we can add basic results if needed. For now, EPUB is priority.
      } else {
        // EPUB Search
        for (int i = 0; i < _chapters.length; i++) {
          final chapter = _chapters[i];
          final content = chapter.HtmlContent ?? '';
          final plainText = stripHtml(content);

          int startIndex = 0;
          while (true) {
            final index = plainText.toLowerCase().indexOf(
              query.toLowerCase(),
              startIndex,
            );
            if (index == -1) break;

            final snippetStart = (index - 40).clamp(0, plainText.length);
            final snippetEnd = (index + query.length + 60).clamp(
              0,
              plainText.length,
            );
            final snippet = plainText
                .substring(snippetStart, snippetEnd)
                .replaceAll('\n', ' ')
                .trim();

            results.add(
              SearchResult(
                pageIndex: i,
                title: chapter.Title ?? 'Chapter ${i + 1}',
                snippet: '...$snippet...',
                query: query,
                scrollProgress: index / plainText.length,
              ),
            );

            startIndex = index + query.length;
            if (results.length > 30) break;
          }
          if (results.length > 30) break;
        }
      }
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isSearchLoading = false;
        _isSearchResultsCollapsed = false; // Show results on new search
      });
    }
  }

  Widget _buildSearchResultsOverlay(Book book, ReaderSettings settings) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: settings.textColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          separatorBuilder: (context, index) => Divider(
            color: settings.textColor.withValues(alpha: 0.05),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                result.title,
                style: TextStyle(
                  color: YomuConstants.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                result.snippet,
                style: TextStyle(color: settings.textColor, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _goToSearchResult(result, book),
            );
          },
        ),
      ),
    );
  }

  void _goToSearchResult(SearchResult result, Book book) {
    setState(() {
      _activeSearchQuery = result.query; // Track the query for highlighting
      _isSearchResultsCollapsed = true; // Collapse overlay on selection
      if (result.scrollProgress != null) {
        _initialScrollProgress = result.scrollProgress!;
      }
    });

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      _pdfController?.goToPage(pageNumber: result.pageIndex + 1);
    } else {
      _pageController?.jumpToPage(result.pageIndex);
    }
  }

  Widget _buildEpubContent(Book book, ReaderSettings settings) {
    if (_chapters.isEmpty || _pageController == null) {
      return Center(
        child: CircularProgressIndicator(color: YomuConstants.accent),
      );
    }

    return Container(
      color: settings.backgroundColor,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _chapters.length,
        onPageChanged: (index) => _handleChapterPageChange(index, book),
        physics: const PageScrollPhysics(), // Ensure snapping
        itemBuilder: (context, index) {
          return _EpubChapterPage(
            index: index,
            chapter: _chapters[index],
            settings: settings,
            shouldJumpToBottom:
                _shouldJumpToBottom && index == _currentChapterIndex,
            initialScrollProgress: index == _currentChapterIndex
                ? _initialScrollProgress
                : 0.0,
            onJumpedToBottom: () {
              setState(() {
                _shouldJumpToBottom = false;
              });
            },
            onJumpedToPosition: () {
              if (index == _currentChapterIndex) {
                setState(() {
                  _initialScrollProgress = 0.0;
                });
              }
            },
            pullDistanceNotifier: _pullDistanceNotifier,
            isPullingDownNotifier: _isPullingDownNotifier,
            scrollProgressNotifier: _scrollProgressNotifier,
            showControls: _showControls,
            onHideControls: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _showControls = false;
                  });
                }
              });
            },
            pullTriggerDistance: _pullTriggerDistance,
            pullDeadzone: _pullDeadzone,
            chapters: _chapters,
            pageController: _pageController,
            autoScrollSpeedNotifier: _autoScrollSpeedNotifier,
            searchQuery: _activeSearchQuery,
          );
        },
      ),
    );
  }

  Widget _buildPdfContent(Book book, ReaderSettings settings) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle &&
            _showControls) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _showControls = false;
              });
            }
          });
        }
        return false;
      },
      child: Listener(
        onPointerDown: (_) => _recordInteraction(),
        child: Container(
          color: settings.backgroundColor,
          child: PdfViewer.file(
            book.filePath,
            controller: _pdfController ??= PdfViewerController(),
            params: PdfViewerParams(
              backgroundColor: settings.backgroundColor,
              onViewerReady: (document, controller) async {
                final outline = await document.loadOutline();
                setState(() {
                  _pdfPages = document.pages.length;
                  _pdfOutline = _flattenPdfOutline(outline);
                  _isPdfReady = true;
                });
                if (!_initialized) {
                  final initialPage = (book.progress * (_pdfPages - 1)).toInt();
                  controller.goToPage(pageNumber: initialPage + 1);
                  _startHeartbeat(book);
                  _initialized = true;
                }
              },
              onPageChanged: (pageNumber) {
                _recordInteraction();
                if (pageNumber != null) {
                  _handlePdfPageChange(pageNumber - 1, _pdfPages, book);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  List<PdfOutlineNode> _flattenPdfOutline(List<PdfOutlineNode> nodes) {
    final List<PdfOutlineNode> flattened = [];
    for (final node in nodes) {
      flattened.add(node);
      if (node.children.isNotEmpty) {
        flattened.addAll(_flattenPdfOutline(node.children));
      }
    }
    return flattened;
  }

  Widget _buildBottomControls(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        border: Border(
          top: BorderSide(color: settings.textColor.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier 1: Audio/Progress Slider
            if (book.audioPath != null)
              _buildAudioSection(settings)
            else
              const SizedBox(height: 12),

            // Tier 2: Secondary Audio Controls (Collapsible)
            if (book.audioPath != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    SizeTransition(sizeFactor: animation, child: child),
                child: _isAudioControlsExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSpeedButton(settings),
                            const SizedBox(width: 24),
                            _buildSkipButton(
                              icon: Icons.replay_10_rounded,
                              onTap: () {
                                final newPos =
                                    _audioPlayer.position -
                                    const Duration(seconds: 10);
                                _audioPlayer.seek(
                                  newPos < Duration.zero
                                      ? Duration.zero
                                      : newPos,
                                );
                              },
                              settings: settings,
                            ),
                            const SizedBox(width: 24),
                            _buildSkipButton(
                              icon: Icons.forward_10_rounded,
                              onTap: () {
                                final newPos =
                                    _audioPlayer.position +
                                    const Duration(seconds: 10);
                                _audioPlayer.seek(
                                  newPos >
                                          (_audioPlayer.duration ??
                                              Duration.zero)
                                      ? (_audioPlayer.duration ?? Duration.zero)
                                      : newPos,
                                );
                              },
                              settings: settings,
                            ),
                            const SizedBox(width: 24),
                            // Replace Audio Button
                            _buildControlButton(
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                color: settings.textColor,
                                size: 20,
                              ),
                              settings: settings,
                              onTap: () => _pickAudio(book),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

            const SizedBox(height: 16),

            // Tier 3: Main Navigation & Reader Utilities
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Navigation (Chapters & Bookmarks)
                  _buildControlButton(
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: _isNavigationSheetOpen
                          ? YomuConstants.accent
                          : settings.textColor,
                      size: 22,
                    ),
                    settings: settings,
                    onTap: () => _showNavigationSheet(context, book, settings),
                  ),

                  // Bookmark
                  _buildControlButton(
                    child: Icon(
                      Icons.bookmark_outline_rounded,
                      color: settings.textColor,
                      size: 22,
                    ),
                    settings: settings,
                    onTap: () => _addBookmark(book),
                  ),

                  // Main Audio Play/Pause (Central)
                  if (book.audioPath != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPlayPauseButton(),
                        const SizedBox(width: 8),
                        _buildControlButton(
                          child: Icon(
                            _isAudioControlsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.tune_rounded,
                            color: settings.textColor,
                            size: 20,
                          ),
                          settings: settings,
                          onTap: () => setState(
                            () => _isAudioControlsExpanded =
                                !_isAudioControlsExpanded,
                          ),
                        ),
                      ],
                    )
                  else
                    _buildControlButton(
                      child: Icon(
                        Icons.add_rounded,
                        color: YomuConstants.accent,
                        size: 24,
                      ),
                      settings: settings,
                      onTap: () => _pickAudio(book),
                    ),
                  // Auto Scroll Toggle
                  _buildControlButton(
                    child: Icon(
                      _isAutoScrolling
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      color: _isAutoScrolling
                          ? YomuConstants.accent
                          : settings.textColor,
                      size: 22,
                    ),
                    settings: settings,
                    onTap: () {
                      setState(() {
                        _isAutoScrolling = !_isAutoScrolling;
                        // Ensure it's never 0 if active
                        final activeSpeed = settings.autoScrollSpeed < 0.5
                            ? 2.0
                            : settings.autoScrollSpeed;
                        _autoScrollSpeedNotifier.value = _isAutoScrolling
                            ? activeSpeed
                            : 0.0;
                      });
                    },
                  ),

                  // Display Settings
                  _buildControlButton(
                    child: Icon(
                      Icons.text_fields_rounded,
                      color: settings.textColor,
                      size: 22,
                    ),
                    settings: settings,
                    onTap: () => showDisplaySettingsSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNavigationSheet(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    if (_isNavigationSheetOpen) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isNavigationSheetOpen = true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: YomuConstants.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
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
                    TabBar(
                      indicatorColor: YomuConstants.accent,
                      labelColor: YomuConstants.accent,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [
                        Tab(text: 'CHAPTERS'),
                        Tab(text: 'BOOKMARKS'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Chapters Tab
                          _buildChaptersList(book, settings),
                          // Bookmarks Tab
                          _buildBookmarksList(book, settings, setSheetState),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isNavigationSheetOpen = false);
    });
  }

  Widget _buildChaptersList(Book book, ReaderSettings settings) {
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chapters.length,
        itemBuilder: (context, index) {
          final chapter = _chapters[index];
          final isCurrent = _currentChapterIndex == index;

          return ListTile(
            title: Text(
              chapter.Title ?? 'Chapter ${index + 1}',
              style: TextStyle(
                color: isCurrent ? YomuConstants.accent : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _pageController?.jumpToPage(index);
            },
          );
        },
      );
    } else {
      // PDF Outline
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pdfOutline.length,
        itemBuilder: (context, index) {
          final node = _pdfOutline[index];
          return ListTile(
            contentPadding: EdgeInsets.only(
              left: 16.0 + (node.dest?.pageNumber != null ? 0 : 16),
              right: 16,
            ),
            title: Text(
              node.title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              if (node.dest?.pageNumber != null) {
                Navigator.pop(context);
                _pdfController?.goToPage(pageNumber: node.dest!.pageNumber);
              }
            },
          );
        },
      );
    }
  }

  Widget _buildBookmarksList(
    Book book,
    ReaderSettings settings,
    StateSetter setSheetState,
  ) {
    return FutureBuilder<List<Bookmark>>(
      future: ref.read(libraryProvider.notifier).getBookmarks(book.id!),
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
                '${(bookmark.progress * 100).toStringAsFixed(1)}% • ${_formatDate(bookmark.createdAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                onPressed: () async {
                  await ref
                      .read(libraryProvider.notifier)
                      .deleteBookmark(bookmark.id!);
                  setSheetState(() {});
                },
              ),
              onTap: () {
                Navigator.pop(context);
                if (book.filePath.toLowerCase().endsWith('.epub')) {
                  if (bookmark.position.contains(':')) {
                    final parts = bookmark.position.split(':');
                    final index = int.tryParse(parts[0]) ?? 0;
                    final progress = double.tryParse(parts[1]) ?? 0.0;
                    if (index >= 0 && index < _chapters.length) {
                      setState(() {
                        _currentChapterIndex = index;
                        _initialScrollProgress = progress;
                        _currentChapter =
                            _chapters[index].Title ?? 'Chapter ${index + 1}';
                      });
                      _pageController?.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  } else {
                    // Fallback for old integer positions or CFI
                    final index = int.tryParse(bookmark.position);
                    if (index != null &&
                        index >= 0 &&
                        index < _chapters.length) {
                      setState(() {
                        _currentChapterIndex = index;
                        _initialScrollProgress = 0.0;
                        _currentChapter =
                            _chapters[index].Title ?? 'Chapter ${index + 1}';
                      });
                      _pageController?.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _epubController?.gotoEpubCfi(bookmark.position);
                    }
                  }
                } else {
                  final targetPage = int.tryParse(bookmark.position) ?? 1;
                  _pdfController?.goToPage(pageNumber: targetPage);
                }
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAudioSection(ReaderSettings settings) {
    if (_isAudioLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: ValueListenableBuilder<Duration>(
              valueListenable: _audioPositionNotifier,
              builder: (context, pos, _) => Text(
                _formatDuration(pos),
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: _audioPositionNotifier,
              builder: (context, pos, _) => ValueListenableBuilder<Duration>(
                valueListenable: _audioDurationNotifier,
                builder: (context, dur, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: YomuConstants.accent,
                      inactiveTrackColor: settings.textColor.withValues(
                        alpha: 0.1,
                      ),
                      thumbColor: YomuConstants.accent,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _isDraggingSlider
                          ? _sliderDragValue.clamp(
                              0,
                              dur.inMilliseconds.toDouble(),
                            )
                          : pos.inMilliseconds.toDouble().clamp(
                              0,
                              dur.inMilliseconds.toDouble(),
                            ),
                      max: dur.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      onChangeStart: (value) {
                        setState(() {
                          _isDraggingSlider = true;
                          _sliderDragValue = value;
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _sliderDragValue = value;
                        });
                        // Update the time label during drag
                        _audioPositionNotifier.value = Duration(
                          milliseconds: value.toInt(),
                        );
                      },
                      onChangeEnd: (value) async {
                        await _audioPlayer.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                        setState(() {
                          _isDraggingSlider = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: ValueListenableBuilder<Duration>(
              valueListenable: _audioDurationNotifier,
              builder: (context, dur, _) => Text(
                _formatDuration(dur),
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(ReaderSettings settings) {
    return _buildControlButton(
      child: Text(
        '${_playbackSpeed}x',
        style: TextStyle(
          color: settings.textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      settings: settings,
      onTap: () {
        setState(() {
          if (_playbackSpeed >= 2.0) {
            _playbackSpeed = 0.5;
          } else {
            _playbackSpeed += 0.25;
          }
          _audioPlayer.setSpeed(_playbackSpeed);
        });
      },
    );
  }

  Widget _buildSkipButton({
    required IconData icon,
    required VoidCallback onTap,
    required ReaderSettings settings,
  }) {
    return _buildControlButton(
      child: Icon(icon, color: settings.textColor, size: 28),
      settings: settings,
      onTap: onTap,
    );
  }

  Widget _buildPlayPauseButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isAudioPlayingNotifier,
      builder: (context, isPlaying, _) => GestureDetector(
        onTap: () {
          if (isPlaying) {
            _audioPlayer.pause();
          } else {
            _audioPlayer.play();
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: YomuConstants.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Widget _buildControlButton({
    required Widget child,
    required ReaderSettings settings,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: settings.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildMinimalFooter(Book book, ReaderSettings settings) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Battery and Time (Left)
            Row(
              children: [
                Icon(
                  Icons.battery_6_bar_rounded,
                  size: 14,
                  color: settings.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentTime,
                  style: TextStyle(
                    color: settings.secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Chapter and Page info (Center)
            Expanded(
              flex: 4,
              child: Text(
                _currentChapter,
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Spacer(),

            // Progress percentage (Right)
            ValueListenableBuilder<double>(
              valueListenable: _scrollProgressNotifier,
              builder: (context, scrollProgress, _) {
                if (book.filePath.toLowerCase().endsWith('.epub') &&
                    _chapters.isNotEmpty) {
                  final totalChapters = _chapters.length;
                  final overallProgress =
                      ((_currentChapterIndex + scrollProgress) /
                      totalChapters *
                      100);
                  return Text(
                    '${overallProgress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: settings.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return Text(
                  '${(book.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: settings.secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;
  final Widget? child;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) {
            return builder(context, a, b, child);
          },
        );
      },
    );
  }
}

class _EpubChapterPage extends StatefulWidget {
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

  const _EpubChapterPage({
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
  });

  @override
  State<_EpubChapterPage> createState() => _EpubChapterPageState();
}

class _EpubChapterPageState extends State<_EpubChapterPage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isNavigating = false;
  double _currentPeakOverscroll = 0.0;
  bool? _isPullingDown;
  Timer? _debounceTimer;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

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
          // Speed is in pixels per second.
          // settings.autoScrollSpeed (e.g. 2.0) * multiplier
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
  void didUpdateWidget(_EpubChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldJumpToBottom && !oldWidget.shouldJumpToBottom) {
      _checkAndJump();
    } else if (widget.initialScrollProgress !=
            oldWidget.initialScrollProgress &&
        widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
    }
  }

  void _checkAndJump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        widget.onJumpedToBottom();
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
          // If maxScroll is 0, layout might not be fully ready or content is small
          // Try again once more after a small delay if it's the first attempt
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
    _debounceTimer?.cancel();
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

          // Trigger navigation on FINGER RELEASE (Direction transitions to idle)
          if (notification.direction == ScrollDirection.idle &&
              !_isNavigating) {
            if (_currentPeakOverscroll > 40) {
              if (_isPullingDown == false &&
                  widget.index < widget.chapters.length - 1) {
                // Reached bottom
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
                // Reached top
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

          // Track the maximum overscroll reached during this gesture
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
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 100), // Top padding
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
                        data: () {
                          String content = widget.chapter.HtmlContent ?? '';
                          if (widget.searchQuery != null &&
                              widget.searchQuery!.isNotEmpty) {
                            final escapedQuery = RegExp.escape(
                              widget.searchQuery!,
                            );
                            // Highlight while avoiding matching inside HTML tags
                            final regex = RegExp(
                              '(?![^<]*>)$escapedQuery',
                              caseSensitive: false,
                            );
                            content = content.replaceAllMapped(regex, (match) {
                              return '<span style="background-color: #2ECC71; color: #000000; border-radius: 2px; padding: 0 2px;">${match.group(0)}</span>';
                            });
                          }
                          return content;
                        }(),
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
                          "p": Style(margin: Margins.only(bottom: 16)),
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
                  const SizedBox(height: 100), // Bottom padding
                ],
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
