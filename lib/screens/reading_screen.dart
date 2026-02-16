import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import './reading/widgets/reading_header.dart';
import './reading/widgets/reading_search_overlay.dart';
import './reading/widgets/reading_audio_section.dart';
import './reading/widgets/play_pause_button.dart';
import './reading/widgets/reading_bottom_controls.dart';
import './reading/widgets/navigation_sheet.dart';
import './reading/widgets/epub_view.dart';
import './reading/widgets/pdf_view.dart';
import './reading/widgets/reading_footer.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen>
    with TickerProviderStateMixin {
  EpubController? _epubController;
  EpubBook? _epubBook;
  int _pdfPages = 0;
  int _pdfCurrentPage = 0;
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _isPullingDownNotifier = ValueNotifier(false);
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier(0.0);
  bool _shouldJumpToBottom = false;
  double _initialScrollProgress = 0.0;

  Timer? _heartbeatTimer;
  Timer? _debounceTimer;
  bool _isPdfReady = false;
  final String _pdfErrorMessage = '';
  DateTime _lastSyncTime = DateTime.now();
  bool _initialized = false;
  int _accumulatedSeconds = 0;
  DateTime _lastInteractionTime = DateTime.now();
  PdfViewerController? _pdfController;
  final Duration _idlenessTimeout = const Duration(minutes: 2);
  final Duration _readThreshold = const Duration(seconds: 5);
  DateTime? _pageEntryTime;
  final Set<int> _pagesReadThisSession = {};
  DateTime? _epubPageEntryTime;
  final Set<int> _epubChaptersReadThisSession = {};

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
  List<PdfOutlineNode> _tocPdfOutline = [];
  PageController? _pageController;
  int _currentChapterIndex = 0;

  // UI state
  bool _showControls = true;
  final ValueNotifier<String> _currentTimeNotifier = ValueNotifier('');
  Timer? _currentTimeTimer;
  Timer? _audioDebounceTimer;
  String? _loadedAudioBookId;
  DateTime _lastAudioSaveTime = DateTime.now();
  int _lastSavedAudioMs = -1;
  bool _isAudioControlsExpanded = false;
  bool _isAutoScrolling = false;
  final ValueNotifier<double> _autoScrollSpeedNotifier = ValueNotifier(0.0);
  Ticker? _pdfAutoScrollTicker;
  Duration _lastPdfElapsed = Duration.zero;
  bool _isNavigationSheetOpen = false;
  bool _isDraggingSlider = false;
  double _sliderDragValue = 0.0;
  bool _isSearching = false;
  PdfTextSearcher? _pdfSearcher;
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearchLoading = false;
  final FocusNode _searchFocusNode = FocusNode();
  String? _activeSearchQuery;
  bool _isSearchResultsCollapsed = false;
  bool _isOrientationLandscape = false;
  bool _isJumpingFromToc = false;

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
        final speed = _autoScrollSpeedNotifier.value;
        if (speed <= 0) return;

        final deltaTime = (elapsed - _lastPdfElapsed).inMilliseconds / 1000.0;
        _lastPdfElapsed = elapsed;
        if (deltaTime <= 0) return;

        // In pdfrx, we scroll by manipulating the matrix
        final currentMatrix = _pdfController!.value;
        final dy = speed * 30.0 * deltaTime;

        // Content moves UP, so we translate by -dy in Y
        final nextMatrix = currentMatrix.clone()
          ..translateByDouble(0.0, -dy, 0.0, 1.0);
        _pdfController!.value = nextMatrix;
      } else {
        _lastPdfElapsed = elapsed;
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
    if (_currentTimeNotifier.value != timeStr) {
      _currentTimeNotifier.value = timeStr;
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
    _currentTimeNotifier.dispose();
    _autoScrollSpeedNotifier.removeListener(_handleGlobalSpeedChange);
    _pdfAutoScrollTicker?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();

    // Reset orientation to portrait-only when leaving reading screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isOrientationLandscape = !_isOrientationLandscape;
      if (_isOrientationLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
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
        _epubBook = document;
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
        _epubPageEntryTime = DateTime.now();
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

    final now = DateTime.now();
    final int previousChapter = _currentChapterIndex;

    // Check if the chapter we are LEAVING was read
    if (_epubPageEntryTime != null) {
      final timeOnChapter = now.difference(_epubPageEntryTime!);
      if (timeOnChapter >= _readThreshold &&
          !_isJumpingFromToc &&
          !_epubChaptersReadThisSession.contains(previousChapter)) {
        _epubChaptersReadThisSession.add(previousChapter);
      }
    }

    // Reset entry time for the new chapter
    _epubPageEntryTime = now;

    setState(() {
      _shouldJumpToBottom = !_isJumpingFromToc && index < _currentChapterIndex;
      _currentChapterIndex = index;
      _currentChapter = _chapters[index].Title ?? 'Chapter ${index + 1}';
      // Reset scroll progress for new chapter
      _scrollProgressNotifier.value = 0.0;
      _isJumpingFromToc = false; // Reset flag after use
    });

    _recordInteraction();

    final progress = _calculateCurrentProgress(book);
    final int pagesRead = _epubChaptersReadThisSession.length;

    // Report pages read if any were accumulated
    ref
        .read(libraryProvider.notifier)
        .updateBookProgress(
          book.id!,
          progress,
          pagesRead: pagesRead > 0 ? pagesRead : 0,
          durationMinutes: 0,
          estimateReadingTime: false,
        );

    if (pagesRead > 0) {
      _epubChaptersReadThisSession.clear();
    }
  }

  void _startHeartbeat(Book book) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isIdle()) return;

      _accumulatedSeconds++;
      if (_accumulatedSeconds >= 60) {
        _accumulatedSeconds = 0;
        final progress = _calculateCurrentProgress(book);

        // Update last sync time so we don't double count on exit/pause
        _lastSyncTime = DateTime.now();

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
      _lastSyncTime = DateTime.now();
      _pageEntryTime = DateTime.now();
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
            estimateReadingTime: false,
          );
      return;
    }

    final now = DateTime.now();
    final int previousPage = _pdfCurrentPage;

    // Check if the page we are LEAVING was read
    if (_pageEntryTime != null) {
      final timeOnPage = now.difference(_pageEntryTime!);
      if (timeOnPage >= _readThreshold &&
          previousPage != page &&
          !_pagesReadThisSession.contains(previousPage)) {
        _pagesReadThisSession.add(previousPage);
      }
    }

    // Reset entry time for the new page
    _pageEntryTime = now;

    setState(() {
      _pdfCurrentPage = page;
      _pdfPages = total;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Use _pagesReadThisSession to determine actual pages read since last sync
      final int pagesRead = _pagesReadThisSession.length;
      final progress = _calculateCurrentProgress(book);

      if (pagesRead > 0) {
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book.id!,
              progress,
              pagesRead: pagesRead,
              durationMinutes: 0,
              currentPage: page,
              totalPages: total,
              estimateReadingTime: false,
            );
        _pagesReadThisSession.clear();
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
              estimateReadingTime: false,
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

    // Check if the CURRENT page/chapter was read before exiting
    if (_pageEntryTime != null) {
      final timeOnPage = now.difference(_pageEntryTime!);
      if (timeOnPage >= _readThreshold &&
          !_pagesReadThisSession.contains(_pdfCurrentPage)) {
        _pagesReadThisSession.add(_pdfCurrentPage);
      }
    }

    if (_epubPageEntryTime != null) {
      final timeOnChapter = now.difference(_epubPageEntryTime!);
      if (timeOnChapter >= _readThreshold &&
          !_epubChaptersReadThisSession.contains(_currentChapterIndex)) {
        _epubChaptersReadThisSession.add(_currentChapterIndex);
      }
    }

    int pagesRead = 0;
    double progress = _calculateCurrentProgress(book);
    int currentPage = book.currentPage;
    int totalPages = book.totalPages;

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (_pdfPages > 0) {
        pagesRead = _pagesReadThisSession.length;
        currentPage = _pdfCurrentPage;
        totalPages = _pdfPages;
      }
    } else if (book.filePath.toLowerCase().endsWith('.epub')) {
      pagesRead = _epubChaptersReadThisSession.length;
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
            estimateReadingTime: false,
          );
      _pagesReadThisSession.clear();
      _epubChaptersReadThisSession.clear();
      _lastSyncTime = now;
    }
    _accumulatedSeconds = 0;
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(currentlyReadingProvider);
    final settings = ref.watch(readerSettingsProvider);

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
                        ReadingEpubView(
                          book: book,
                          settings: settings,
                          chapters: _chapters,
                          pageController: _pageController,
                          currentChapterIndex: _currentChapterIndex,
                          shouldJumpToBottom: _shouldJumpToBottom,
                          initialScrollProgress: _initialScrollProgress,
                          pullDistanceNotifier: _pullDistanceNotifier,
                          isPullingDownNotifier: _isPullingDownNotifier,
                          scrollProgressNotifier: _scrollProgressNotifier,
                          autoScrollSpeedNotifier: _autoScrollSpeedNotifier,
                          showControls: _showControls,
                          onPageChanged: (index) =>
                              _handleChapterPageChange(index, book),
                          onJumpedToBottom: () =>
                              setState(() => _shouldJumpToBottom = false),
                          onJumpedToPosition: () =>
                              setState(() => _initialScrollProgress = 0.0),
                          onHideControls: () {
                            if (_showControls) {
                              setState(() => _showControls = false);
                            }
                          },
                          searchQuery: _activeSearchQuery,
                          epubBook: _epubBook,
                        )
                      else
                        ReadingPdfView(
                          book: book,
                          settings: settings,
                          controller: _pdfController ??= PdfViewerController(),
                          searcher: _pdfSearcher,
                          onViewerReady: (document, controller) async {
                            _pdfSearcher = PdfTextSearcher(controller);
                            _pdfSearcher!.addListener(() => setState(() {}));
                            final outline = await document.loadOutline();
                            if (mounted) {
                              setState(() {
                                _pdfPages = document.pages.length;
                                _tocPdfOutline = outline;
                                _pdfOutline = _flattenPdfOutline(outline);
                                _isPdfReady = true;
                              });
                            }
                            if (!_initialized) {
                              final initialPage =
                                  (book.progress * (_pdfPages - 1)).toInt();
                              controller.goToPage(pageNumber: initialPage + 1);
                              _startHeartbeat(book);
                              _initialized = true;
                            }
                          },
                          onPageChanged: (pageNumber) {
                            _recordInteraction();
                            if (pageNumber != null) {
                              _handlePdfPageChange(
                                pageNumber - 1,
                                _pdfPages,
                                book,
                              );
                            }
                          },
                          onInteraction: _recordInteraction,
                          onHideControls: () {
                            if (_showControls) {
                              setState(() => _showControls = false);
                            }
                          },
                          showControls: _showControls,
                        ),
                      _buildAnimatedControlsOverlay(context, book, settings),
                      if (_pdfErrorMessage.isNotEmpty)
                        Center(
                          child: Text(
                            _pdfErrorMessage,
                            style: TextStyle(color: settings.textColor),
                          ),
                        )
                      else if (!isEpub && !_isPdfReady)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _currentTimeNotifier,
                builder: (context, currentTime, _) {
                  return ReadingFooter(
                    book: book,
                    settings: settings,
                    currentTime: currentTime,
                    currentChapter: _currentChapter,
                    scrollProgressNotifier: _scrollProgressNotifier,
                    totalChapters: _chapters.length,
                    currentChapterIndex: _currentChapterIndex,
                  );
                },
              ),
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
    final isEpub = book.filePath.toLowerCase().endsWith('.epub');

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: _showControls ? 0 : -100,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<String>(
            valueListenable: _currentTimeNotifier,
            builder: (context, currentTime, _) {
              return ReadingHeader(
                book: book,
                settings: settings,
                currentChapter: _currentChapter,
                pageInfo: isEpub
                    ? '${(book.progress * 100).toStringAsFixed(0)}%'
                    : '${_pdfCurrentPage + 1} / $_pdfPages',
                isSearching: _isSearching,
                isSearchLoading: _isSearchLoading,
                isSearchResultsCollapsed: _isSearchResultsCollapsed,
                searchResultsCount: _searchResults.length,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onBackPressed: () {
                  _syncFinalProgress(book);
                  Navigator.of(context).pop();
                },
                onToggleSearch: () {
                  setState(() {
                    _isSearching = true;
                    _showControls = true;
                  });
                  _searchFocusNode.requestFocus();
                },
                onClearSearch: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults = [];
                    _activeSearchQuery = null;
                  });
                },
                onSearchSubmitted: (value) => _handleSearch(value, book),
                onToggleSearchResultsCollapse: () => setState(
                  () => _isSearchResultsCollapsed = !_isSearchResultsCollapsed,
                ),
                searchResultsOverlay: ReadingSearchOverlay(
                  book: book,
                  settings: settings,
                  searchResults: _searchResults,
                  onResultTap: (result) => _goToSearchResult(result, book),
                ),
              );
            },
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _showControls ? 0 : -200,
          left: 0,
          right: 0,
          child: ReadingBottomControls(
            book: book,
            settings: settings,
            isAudioControlsExpanded: _isAudioControlsExpanded,
            isNavigationSheetOpen: _isNavigationSheetOpen,
            isAutoScrolling: _isAutoScrolling,
            playbackSpeed: _playbackSpeed,
            isOrientationLandscape: _isOrientationLandscape,
            audioSection: ReadingAudioSection(
              settings: settings,
              isLoading: _isAudioLoading,
              positionNotifier: _audioPositionNotifier,
              durationNotifier: _audioDurationNotifier,
              isDraggingSlider: _isDraggingSlider,
              sliderDragValue: _sliderDragValue,
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
                _audioPositionNotifier.value = Duration(
                  milliseconds: value.toInt(),
                );
              },
              onChangeEnd: (value) async {
                await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                setState(() => _isDraggingSlider = false);
              },
              formatDuration: _formatDuration,
            ),
            playPauseButton: PlayPauseButton(
              isPlayingNotifier: _isAudioPlayingNotifier,
              onTap: () {
                if (_isAudioPlayingNotifier.value) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.play();
                }
              },
            ),
            onToggleAudioControls: () => setState(
              () => _isAudioControlsExpanded = !_isAudioControlsExpanded,
            ),
            onPickAudio: () => _pickAudio(book),
            onShowNavigationSheet: () =>
                _showNavigationSheet(context, book, settings),
            onAddBookmark: () => _addBookmark(book),
            onToggleAutoScroll: () {
              setState(() {
                _isAutoScrolling = !_isAutoScrolling;
                final activeSpeed = settings.autoScrollSpeed < 0.5
                    ? 2.0
                    : settings.autoScrollSpeed;
                _autoScrollSpeedNotifier.value = _isAutoScrolling
                    ? activeSpeed
                    : 0.0;
              });
            },
            onToggleOrientation: _toggleOrientation,
            onShowDisplaySettings: () => showDisplaySettingsSheet(context),
            onIncrementPlaybackSpeed: () {
              setState(() {
                if (_playbackSpeed >= 2.0) {
                  _playbackSpeed = 0.5;
                } else {
                  _playbackSpeed += 0.25;
                }
                _audioPlayer.setSpeed(_playbackSpeed);
              });
            },
            onSkip: (delta) {
              final newPos = _audioPlayer.position + delta;
              final duration = _audioPlayer.duration ?? Duration.zero;
              _audioPlayer.seek(
                newPos < Duration.zero
                    ? Duration.zero
                    : (newPos > duration ? duration : newPos),
              );
            },
          ),
        ),
      ],
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
        // PDF Search mirroring EPUB behavior
        final doc = _pdfController?.document;
        if (doc != null && _pdfSearcher != null) {
          // Track the query for highlighting in the PDF view
          _pdfSearcher!.startTextSearch(
            query,
            goToFirstMatch: false,
            searchImmediately: true,
          );

          for (int i = 0; i < doc.pages.length; i++) {
            final page = doc.pages[i];
            final pageText = await page.loadText();
            final plainText = pageText.fullText;
            final lowerText = plainText.toLowerCase();
            final lowerQuery = query.toLowerCase();

            int startIndex = 0;
            while (true) {
              final index = lowerText.indexOf(lowerQuery, startIndex);
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

              // Create a match object for precise navigation later
              final match = PdfTextRangeWithFragments.fromTextRange(
                pageText,
                index,
                index + query.length,
              );

              results.add(
                SearchResult(
                  pageIndex: i,
                  title: 'Page ${i + 1}',
                  snippet: '...$snippet...',
                  query: query,
                  metadata: match,
                ),
              );

              startIndex = index + query.length;
              if (results.length >= 30) break;
            }
            if (results.length >= 30) break;
          }
        }
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

  void _goToSearchResult(SearchResult result, Book book) {
    setState(() {
      _activeSearchQuery = result.query; // Track the query for highlighting
      _isSearchResultsCollapsed = true; // Collapse overlay on selection
      if (result.scrollProgress != null) {
        _initialScrollProgress = result.scrollProgress!;
      }
    });

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (result.metadata is PdfTextMatch) {
        _pdfSearcher?.goToMatch(result.metadata as PdfTextMatch);
      } else {
        _pdfController?.goToPage(pageNumber: result.pageIndex + 1);
      }
    } else {
      _pageController?.jumpToPage(result.pageIndex);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
        return NavigationSheet(
          book: book,
          chapters: _chapters,
          tocChapters: _epubBook?.Chapters ?? [],
          pdfOutline: _pdfOutline,
          tocPdfOutline: _tocPdfOutline,
          currentChapterIndex: _currentChapterIndex,
          onChapterTap: (index) {
            Navigator.pop(context);
            setState(() {
              _isJumpingFromToc = true;
            });
            _pageController?.jumpToPage(index);
          },
          onPdfOutlineTap: (node) {
            if (node.dest?.pageNumber != null) {
              Navigator.pop(context);
              _pdfController?.goToPage(pageNumber: node.dest!.pageNumber);
            }
          },
          getBookmarks: () =>
              ref.read(libraryProvider.notifier).getBookmarks(book.id!),
          onDeleteBookmark: (bookmark) =>
              ref.read(libraryProvider.notifier).deleteBookmark(bookmark.id!),
          onBookmarkTap: (bookmark) {
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
                final index = int.tryParse(bookmark.position);
                if (index != null && index >= 0 && index < _chapters.length) {
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
          formatDate: _formatDate,
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isNavigationSheetOpen = false);
    });
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
