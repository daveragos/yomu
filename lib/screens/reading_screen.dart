import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_view/epub_view.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/constants.dart';
import '../components/display_settings_sheet.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../models/book_model.dart';
import '../models/reader_settings_model.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'main_navigation.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
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
  bool _isSyncMode = false;
  double _playbackSpeed = 1.0;
  String _currentChapter = 'Chapter 1';
  List<EpubChapter> _chapters = [];
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

  @override
  void initState() {
    super.initState();
    _updateTime();
    _currentTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _initAudio();
  }

  void _initAudio() {
    _audioPlayer.positionStream.listen((pos) {
      _audioPositionNotifier.value = pos;
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
    super.dispose();
  }

  void _recordInteraction() {
    _lastInteractionTime = DateTime.now();
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
                children: [
                  _buildHeader(context, book, settings),
                  _buildModeToggle(settings),
                ],
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

  Widget _buildHeader(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    String pageInfo = '';
    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      pageInfo = 'Page ${_pdfCurrentPage + 1} of $_pdfPages';
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: settings.textColor),
                onPressed: () {
                  _syncFinalProgress(book);
                  ref.read(selectedIndexProvider.notifier).state = 1;
                },
              ),

              // Center content
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Page info
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: settings.textColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  pageInfo,
                  style: TextStyle(
                    color: settings.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(ReaderSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: settings.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: settings.textColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            label: 'Text Mode',
            isSelected: !_isSyncMode,
            settings: settings,
            onTap: () => setState(() => _isSyncMode = false),
          ),
          _buildModeButton(
            label: 'Sync Mode',
            icon: Icons.sync,
            isSelected: _isSyncMode,
            settings: settings,
            onTap: () => setState(() => _isSyncMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    IconData? icon,
    required bool isSelected,
    required ReaderSettings settings,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? YomuConstants.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : settings.secondaryTextColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : settings.secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
              onViewerReady: (document, controller) {
                setState(() {
                  _pdfPages = document.pages.length;
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

  Widget _buildBottomControls(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: settings.backgroundColor, // Use solid background for visibility
        border: Border(
          top: BorderSide(color: settings.textColor.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio Section (Optional)
            if (book.audioPath != null)
              _buildAudioSection(settings)
            else
              _buildNoAudioSection(book, settings),

            // Reading Controls Row (Always visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSpeedButton(settings),
                  _buildSkipButton(
                    icon: Icons.replay_10_rounded,
                    onTap: () {
                      final newPos =
                          _audioPlayer.position - const Duration(seconds: 10);
                      _audioPlayer.seek(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                    },
                    settings: settings,
                  ),
                  _buildPlayPauseButton(),
                  _buildSkipButton(
                    icon: Icons.forward_10_rounded,
                    onTap: () {
                      final newPos =
                          _audioPlayer.position + const Duration(seconds: 10);
                      _audioPlayer.seek(
                        newPos > (_audioPlayer.duration ?? Duration.zero)
                            ? (_audioPlayer.duration ?? Duration.zero)
                            : newPos,
                      );
                    },
                    settings: settings,
                  ),
                  _buildControlButton(
                    child: Icon(
                      Icons.text_fields_rounded,
                      color: settings.textColor,
                      size: 24,
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
          ValueListenableBuilder<Duration>(
            valueListenable: _audioPositionNotifier,
            builder: (context, pos, _) => Text(
              _formatDuration(pos),
              style: TextStyle(
                color: settings.secondaryTextColor,
                fontSize: 12,
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
                      value: pos.inMilliseconds.toDouble().clamp(
                        0,
                        dur.inMilliseconds.toDouble(),
                      ),
                      max: dur.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      onChanged: (value) {
                        _audioPlayer.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<Duration>(
            valueListenable: _audioDurationNotifier,
            builder: (context, dur, _) => Text(
              _formatDuration(dur),
              style: TextStyle(
                color: settings.secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAudioSection(Book book, ReaderSettings settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: TextButton.icon(
        onPressed: () => _pickAudio(book),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Audio File'),
        style: TextButton.styleFrom(
          foregroundColor: YomuConstants.accent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
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
  });

  @override
  State<_EpubChapterPage> createState() => _EpubChapterPageState();
}

class _EpubChapterPageState extends State<_EpubChapterPage> {
  late ScrollController _scrollController;
  bool _isNavigating = false;
  double _currentPeakOverscroll = 0.0;
  bool? _isPullingDown;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.shouldJumpToBottom) {
      _checkAndJump();
    } else if (widget.initialScrollProgress > 0) {
      _checkAndJumpToPosition();
    }
  }

  @override
  void didUpdateWidget(_EpubChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldJumpToBottom && !oldWidget.shouldJumpToBottom) {
      _checkAndJump();
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
          _scrollController.jumpTo(maxScroll * widget.initialScrollProgress);
          widget.onJumpedToPosition();
        } else {
          // If maxScroll is 0, layout might not be fully ready or content is small
          // Try again once more after a small delay if it's the first attempt
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _scrollController.hasClients) {
              final double newMaxScroll =
                  _scrollController.position.maxScrollExtent;
              if (newMaxScroll > 0) {
                _scrollController.jumpTo(
                  newMaxScroll * widget.initialScrollProgress,
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
                        data: widget.chapter.HtmlContent ?? '',
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
