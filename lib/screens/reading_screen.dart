import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:epub_view/epub_view.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/constants.dart';
import '../components/display_settings_sheet.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../models/book_model.dart';
import '../models/reader_settings_model.dart';
import '../models/bookmark_model.dart';
import '../models/search_result_model.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../utils/tutorial_helper.dart';
import '../models/highlight_model.dart';
import '../services/database_service.dart';

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
  final ValueNotifier<int> _audioIndexNotifier = ValueNotifier(0);
  bool _isAudioLoading = false;

  // Reading mode state
  double _playbackSpeed = 1.0;
  String _currentChapter = 'Chapter 1';
  List<EpubChapter> _chapters = [];
  List<PdfOutlineNode> _pdfOutline = [];
  List<PdfOutlineNode> _tocPdfOutline = [];
  PdfOutlineNode? _currentPdfNode;
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
  List<Bookmark> _bookmarks = [];
  List<Highlight> _highlights = [];

  final GlobalKey _audioKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _lockKey = GlobalKey();
  final GlobalKey _tocKey = GlobalKey();
  final GlobalKey _autoScrollKey = GlobalKey();
  final GlobalKey _displaySettingsKey = GlobalKey();

  DateTime? _epubPointerDownTime;
  Offset? _epubPointerDownPosition;
  int? _lastBookId;

  void _resetReadingViewState() {
    _epubController?.dispose();
    _epubController = null;
    _epubBook = null;
    _pdfController = null;
    _pdfPages = 0;
    _pdfCurrentPage = 0;
    _isPdfReady = false;
    _initialized = false;
    _pdfOutline = [];
    _tocPdfOutline = [];
    _currentPdfNode = null;
    _currentChapter = 'Chapter 1';
    _currentChapterIndex = 0;
    _pageController?.dispose();
    _pageController = null;
    _pagesReadThisSession.clear();
    _epubChaptersReadThisSession.clear();
    _isAutoScrolling = false;
    _pdfAutoScrollTicker?.stop();
    _pdfSearcher?.dispose();
    _pdfSearcher = null;
    _searchResults = [];
    _isSearching = false;
    _activeSearchQuery = null;
    _isSearchLoading = false;
    _searchController.clear();
    _bookmarks = [];
    _highlights = [];
    // Force reload bookmarks/highlights for the NEW book
    _loadBookmarks();
  }

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

    _checkFirstLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookmarks();
    });
  }

  Future<void> _loadBookmarks() async {
    final book = ref.read(currentlyReadingProvider);
    if (book != null) {
      final bookmarks = await ref
          .read(libraryProvider.notifier)
          .getBookmarks(book.id!);
      final dbService = DatabaseService();
      final highlights = await dbService.getHighlightsForBook(book.id!);
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _highlights = highlights;
        });
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();

    final isMainFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (isMainFirstLaunch) return;

    final isFirstLaunch = prefs.getBool('is_first_launch_reading') ?? true;

    if (isFirstLaunch && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    final book = ref.read(currentlyReadingProvider);
    if (book == null) return;

    final isPdf = book.filePath.toLowerCase().endsWith('.pdf');

    final targets = <TargetFocus>[
      TutorialHelper.createTarget(
        identify: "toc_target",
        keyTarget: _tocKey,
        alignSkip: Alignment.topRight,
        title: "Navigation",
        description:
            "Access the Table of Contents, outlines, and your bookmarks.",
        contentAlign: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        identify: "search_target",
        keyTarget: _searchKey,
        alignSkip: Alignment.bottomLeft,
        title: "Search",
        description: "Find specific phrases or words quickly within the book.",
        contentAlign: ContentAlign.bottom,
        crossAxisAlignment: CrossAxisAlignment.end,
        textAlign: TextAlign.right,
      ),
      if (isPdf)
        TutorialHelper.createTarget(
          identify: "lock_target",
          keyTarget: _lockKey,
          alignSkip: Alignment.bottomRight,
          title: "Scroll Lock",
          description:
              "Lock the PDF to horizontal scrolling, vertical scrolling, or lock the zoom level.",
          contentAlign: ContentAlign.bottom,
        ),
      TutorialHelper.createTarget(
        identify: "audio_target",
        keyTarget: _audioKey,
        alignSkip: Alignment.topRight,
        title: "Immersive Audio",
        description:
            "Tap the + icon to attach an audiobook file. If one is attached, tap here to open the audio controls.",
        contentAlign: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        identify: "autoscroll_target",
        keyTarget: _autoScrollKey,
        alignSkip: Alignment.topLeft,
        title: "Auto-Scroll",
        description:
            "Sit back and let the app scroll for you. Adjust the speed in the settings.",
        contentAlign: ContentAlign.top,
        crossAxisAlignment: CrossAxisAlignment.end,
        textAlign: TextAlign.right,
      ),
      TutorialHelper.createTarget(
        identify: "display_target",
        keyTarget: _displaySettingsKey,
        alignSkip: Alignment.topLeft,
        title: "Display Settings",
        description:
            "Customize fonts, themes, margins, and more to suit your reading style.",
        contentAlign: ContentAlign.top,
        crossAxisAlignment: CrossAxisAlignment.end,
        textAlign: TextAlign.right,
      ),
    ];

    TutorialHelper.showTutorial(
      context: context,
      targets: targets,
      colorShadow: YomuConstants.accent,
      onFinish: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_first_launch_reading', false);
        });
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_first_launch_reading', false);
        });
        return true;
      },
    );
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
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        _audioIndexNotifier.value = index;
        if (_isAudioPlayingNotifier.value) {
          // Track changed, save position
          _performAudioSave(0, index: index);
        }
        if (mounted) setState(() {});
      }
    });
  }

  void _maybeSaveAudioPosition(Duration pos) {
    if (_loadedAudioBookId == null || _isAudioLoading) return;

    final now = DateTime.now();
    final currentMs = pos.inMilliseconds;
    final currentIndex = _audioPlayer.currentIndex ?? 0;

    // save at most every 10 seconds OR if seek is large (> 5s) OR if index changed
    final diff = (currentMs - _lastSavedAudioMs).abs();
    final timeSinceLastSave = now.difference(_lastAudioSaveTime);

    if (timeSinceLastSave > const Duration(seconds: 10) || diff > 5000) {
      _performAudioSave(currentMs, index: currentIndex);
    }
  }

  void _performAudioSave(int ms, {int? index}) {
    final book = ref.read(currentlyReadingProvider);
    if (book != null && book.id.toString() == _loadedAudioBookId) {
      _lastAudioSaveTime = DateTime.now();
      _lastSavedAudioMs = ms;
      final targetIndex = index ?? _audioPlayer.currentIndex ?? 0;
      ref
          .read(libraryProvider.notifier)
          .updateBookAudio(
            book.id!,
            audioLastPosition: ms,
            audioLastIndex: targetIndex,
          );
    }
  }

  Future<void> _loadAudio(
    List<AudioTrack> tracks, {
    int? initialPositionMs,
    int? initialIndex,
    String? bookId,
  }) async {
    if (tracks.isEmpty || bookId == null) {
      await _audioPlayer.stop();
      _loadedAudioBookId = null;
      _audioIndexNotifier.value = 0;
      return;
    }
    try {
      _loadedAudioBookId = bookId;
      setState(() => _isAudioLoading = true);

      final playlist = ConcatenatingAudioSource(
        children: tracks
            .map((t) => AudioSource.file(t.path, tag: t.title))
            .toList(),
      );

      await _audioPlayer.setAudioSource(
        playlist,
        initialIndex: initialIndex,
        initialPosition: initialPositionMs != null
            ? Duration(milliseconds: initialPositionMs)
            : null,
      );

      setState(() => _isAudioLoading = false);
    } catch (e) {
      _loadedAudioBookId = null;
      setState(() => _isAudioLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
  }

  Future<void> _pickAudio(Book book) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      final List<AudioTrack> newTracks = List.from(book.audioTracks);
      int duplicatesCount = 0;
      for (final path in result.paths) {
        if (path != null) {
          if (!newTracks.any((t) => t.path == path)) {
            newTracks.add(AudioTrack(path: path, title: p.basename(path)));
          } else {
            duplicatesCount++;
          }
        }
      }

      if (duplicatesCount > 0 && mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                duplicatesCount == result.paths.length
                    ? 'All selected files are already in this book.'
                    : 'Skipped $duplicatesCount duplicate files.',
              ),
            ),
          );
      }

      if (newTracks.length == book.audioTracks.length) return;

      // Update the book with new tracks and update the audio path
      await ref
          .read(libraryProvider.notifier)
          .updateBook(
            book.copyWith(
              audioTracks: newTracks,
              audioPath: newTracks.first.path,
            ),
          );

      _loadAudio(newTracks, bookId: book.id.toString());
    }
  }

  void _skip(Duration duration) {
    final newPos = _audioPlayer.position + duration;
    final totalDur = _audioPlayer.duration ?? Duration.zero;
    if (newPos < Duration.zero) {
      _audioPlayer.seek(Duration.zero);
    } else if (newPos > totalDur) {
      if (_audioPlayer.hasNext) {
        _audioPlayer.seekToNext();
      } else {
        _audioPlayer.seek(totalDur);
      }
    } else {
      _audioPlayer.seek(newPos);
    }
  }

  Future<void> _removeTrack(Book book, int index) async {
    final tracks = List<AudioTrack>.from(book.audioTracks);
    if (tracks.length > index) {
      tracks.removeAt(index);

      // If we removed the currently playing track, or one before it, adjust
      final currentIndex = _audioPlayer.currentIndex;
      if (currentIndex != null) {
        if (currentIndex == index) {
          // Playing track removed, move to next or stop
          if (tracks.isEmpty) {
            await _audioPlayer.stop();
          }
        }
      }

      final updatedBook = book.copyWith(
        audioTracks: tracks,
        audioPath: tracks.isNotEmpty ? tracks.first.path : null,
      );

      await ref.read(libraryProvider.notifier).updateBook(updatedBook);

      // Re-load audio to ensure the player's source matches the new tracks list
      await _loadAudio(tracks, bookId: book.id.toString());
      if (tracks.isNotEmpty && currentIndex != null) {
        final newIndex = currentIndex >= tracks.length
            ? tracks.length - 1
            : currentIndex;
        await _audioPlayer.seek(Duration.zero, index: newIndex);
      }
    }
  }

  Future<void> _reorderTracks(Book book, int oldIndex, int newIndex) async {
    final tracks = List<AudioTrack>.from(book.audioTracks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final track = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, track);

    await ref
        .read(libraryProvider.notifier)
        .updateBook(
          book.copyWith(
            audioTracks: tracks,
            audioPath: tracks.isNotEmpty ? tracks.first.path : null,
          ),
        );

    // Update player without losing position
    final currentPos = _audioPlayer.position;
    final currentIndex = _audioPlayer.currentIndex;

    int? nextIndex;
    if (currentIndex == oldIndex) {
      nextIndex = newIndex;
    } else if (currentIndex != null) {
      // Adjust index if affected by move
      if (oldIndex < currentIndex && newIndex >= currentIndex) {
        nextIndex = currentIndex - 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        nextIndex = currentIndex + 1;
      } else {
        nextIndex = currentIndex;
      }
    }

    await _loadAudio(
      tracks,
      bookId: book.id.toString(),
      initialIndex: nextIndex,
      initialPositionMs: currentPos.inMilliseconds,
    );
    // After reloading the audio source, seek to the correct position and index
    if (nextIndex != null) {
      _audioPlayer.seek(currentPos, index: nextIndex);
    }
  }

  void _showTrackListSheet(Book book) {
    final settings = ref.read(readerSettingsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: settings.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final latestBook = ref.watch(currentlyReadingProvider);
          if (latestBook == null) return const SizedBox.shrink();

          final tracks =
              latestBook.audioTracks.isEmpty && latestBook.audioPath != null
              ? [
                  AudioTrack(
                    path: latestBook.audioPath!,
                    title: p.basename(latestBook.audioPath!),
                  ),
                ]
              : latestBook.audioTracks;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    'Audiobook Parts',
                    style: TextStyle(
                      color: settings.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    onReorder: (oldIndex, newIndex) async {
                      await _reorderTracks(latestBook, oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return ValueListenableBuilder<int>(
                        key: ValueKey(track.path + index.toString()),
                        valueListenable: _audioIndexNotifier,
                        builder: (context, currentIndex, _) {
                          final isCurrent = currentIndex == index;
                          return ListTile(
                            leading: Icon(
                              isCurrent
                                  ? Icons.play_circle_fill_rounded
                                  : Icons.play_circle_outline_rounded,
                              color: isCurrent
                                  ? YomuConstants.accent
                                  : settings.secondaryTextColor,
                            ),
                            title: Text(
                              track.title,
                              style: TextStyle(
                                color: isCurrent
                                    ? YomuConstants.accent
                                    : settings.textColor,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              'Part ${index + 1}',
                              style: TextStyle(
                                color: settings.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: settings.secondaryTextColor
                                        .withOpacity(0.5),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _removeTrack(latestBook, index);
                                  },
                                ),
                                Icon(
                                  Icons.drag_handle,
                                  color: settings.secondaryTextColor
                                      .withOpacity(0.3),
                                  size: 20,
                                ),
                              ],
                            ),
                            onTap: () {
                              _audioPlayer.seek(Duration.zero, index: index);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
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

  void _toggleLock() {
    ref.read(readerSettingsProvider.notifier).toggleLockState();
    _recordInteraction();
  }

  void _jumpToPdfPage(int pageNumber) {
    if (_pdfController == null || !_isPdfReady || _pdfPages <= 0) return;

    final targetPage = pageNumber.clamp(1, _pdfPages);

    if (targetPage - 1 != _pdfCurrentPage) {
      setState(() {
        _isJumpingFromToc = true;
        _setPdfPage(targetPage - 1);
      });
    }

    _pdfController!.goToPage(
      pageNumber: targetPage,
      // duration: const Duration(milliseconds: 300),
      anchor: PdfPageAnchor.top,
    );
    _recordInteraction();
  }

  void _jumpToPercent(double percent, Book book) {
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (_chapters.isEmpty) return;

      final double targetTotalProgress = percent * _chapters.length;
      final int chapterIndex = targetTotalProgress.floor().clamp(
        0,
        _chapters.length - 1,
      );
      final double chapterScrollProgress = (targetTotalProgress - chapterIndex)
          .clamp(0.0, 1.0);

      setState(() {
        _currentChapterIndex = chapterIndex;
        _initialScrollProgress = chapterScrollProgress;
        _currentChapter =
            _chapters[chapterIndex].Title ?? 'Chapter ${chapterIndex + 1}';
        _pageController?.jumpToPage(chapterIndex);
      });
      _recordInteraction();
    } else {
      if (!_isPdfReady || _pdfPages <= 0) return;
      final targetPage = (percent * (_pdfPages - 1)).toInt() + 1;
      _jumpToPdfPage(targetPage);
    }
  }

  void _recordInteraction() {
    _lastInteractionTime = DateTime.now();
  }

  Bookmark? _getCurrentBookmark() {
    if (_bookmarks.isEmpty) return null;

    final book = ref.read(currentlyReadingProvider);
    if (book == null) return null;

    if (book.filePath.toLowerCase().endsWith('.epub')) {
      final chapterPosStr = '$_currentChapterIndex:';
      for (final b in _bookmarks) {
        if (b.position.startsWith(chapterPosStr)) {
          final parts = b.position.split(':');
          if (parts.length > 1) {
            final double bookmarkProgress = double.tryParse(parts[1]) ?? 0.0;
            if ((_scrollProgressNotifier.value - bookmarkProgress).abs() <
                0.5) {
              return b;
            }
          }
        } else if (b.position == _currentChapterIndex.toString()) {
          return b;
        }
      }
    } else {
      if (!_isPdfReady) return null;
      final pageStr = (_pdfCurrentPage + 1).toString();
      for (final b in _bookmarks) {
        if (b.position == pageStr) {
          return b;
        }
      }
    }
    return null;
  }

  void _toggleBookmark(Book book) async {
    final currentBookmark = _getCurrentBookmark();
    if (currentBookmark != null) {
      await ref
          .read(libraryProvider.notifier)
          .deleteBookmark(currentBookmark.id!);
      await _loadBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Bookmark removed'),
              backgroundColor: YomuConstants.accent,
              behavior: SnackBarBehavior.floating,
              width: 200,
            ),
          );
      }
    } else {
      final progress = _calculateCurrentProgress(book);
      String position = '0';

      if (book.filePath.toLowerCase().endsWith('.epub')) {
        position = '$_currentChapterIndex:${_scrollProgressNotifier.value}';
      } else if (book.filePath.toLowerCase().endsWith('.pdf')) {
        position = (_pdfCurrentPage + 1).toString();
      }

      String title = 'Bookmark';
      if (book.filePath.toLowerCase().endsWith('.epub')) {
        if (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length) {
          title = _chapters[_currentChapterIndex].Title ?? 'Bookmark';
        }
      } else if (_isPdfReady) {
        title = 'Page ${_pdfCurrentPage + 1}';
      }

      final bookmark = Bookmark(
        bookId: book.id!,
        title: title,
        progress: progress,
        createdAt: DateTime.now(),
        position: position,
      );

      await ref.read(libraryProvider.notifier).addBookmark(bookmark);
      await _loadBookmarks();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Position bookmarked'),
              backgroundColor: YomuConstants.accent,
              behavior: SnackBarBehavior.floating,
              width: 200,
            ),
          );
      }
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
        if (_pdfPages == 1) return 1.0;
        return _pdfCurrentPage / (_pdfPages - 1);
      }
      return book.progress;
    } else if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (_chapters.isNotEmpty) {
        final double progress =
            (_currentChapterIndex + _scrollProgressNotifier.value) /
            _chapters.length;
        // If we are in the last chapter and very close to the end, snap to 1.0
        if (_currentChapterIndex == _chapters.length - 1 &&
            _scrollProgressNotifier.value > 0.99) {
          return 1.0;
        }
        return progress.clamp(0.0, 1.0);
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
    });

    _recordInteraction();

    final progress = _calculateCurrentProgress(book);
    final int pagesRead = _epubChaptersReadThisSession.fold(
      0,
      (sum, idx) => sum + _getEpubChapterWeight(idx),
    );

    // Report pages read if any were accumulated
    ref
        .read(libraryProvider.notifier)
        .updateBookProgress(
          book.id!,
          progress,
          pagesRead: pagesRead > 0 ? pagesRead : 0,
          durationMinutes: 0,
          currentPage: _currentChapterIndex,
          totalPages: _chapters.length,
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

    // Caller already passes 0-indexed page
    final int zeroIndexedPage = page;

    if (_isJumpingFromToc) {
      if (zeroIndexedPage == _pdfCurrentPage) {
        setState(() => _isJumpingFromToc = false);
        // Let it fall through to update entry time and sync
      } else {
        return; // Ignore intermediate page changes during a jump
      }
    }

    if (zeroIndexedPage == _pdfCurrentPage && total == _pdfPages) {
      return;
    }

    if (!_initialized) {
      _lastSyncTime = DateTime.now();
      _pageEntryTime = DateTime.now();
      _initialized = true;
      setState(() {
        _pdfPages = total;
        _setPdfPage(zeroIndexedPage);
      });

      ref
          .read(libraryProvider.notifier)
          .updateBookProgress(
            book.id!,
            book.progress,
            pagesRead: 0,
            durationMinutes: 0,
            currentPage: zeroIndexedPage,
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
          previousPage != zeroIndexedPage &&
          !_pagesReadThisSession.contains(previousPage)) {
        _pagesReadThisSession.add(previousPage);
      }
    }

    // Reset entry time for the new page
    _pageEntryTime = now;

    setState(() {
      _pdfPages = total;
      _setPdfPage(zeroIndexedPage);
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
              currentPage: zeroIndexedPage,
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
              currentPage: zeroIndexedPage,
              totalPages: total,
              estimateReadingTime: false,
            );
      }
    });
  }

  void _setPdfPage(int page) {
    _pdfCurrentPage = page;
    if (_pdfPages > 1) {
      _scrollProgressNotifier.value = (page / (_pdfPages - 1)).clamp(0.0, 1.0);
    } else {
      _scrollProgressNotifier.value = 1.0;
    }
    _updatePdfCurrentChapter();
  }

  void _updatePdfCurrentChapter() {
    if (_pdfOutline.isEmpty) {
      final book = ref.read(currentlyReadingProvider);
      if (book != null && !book.filePath.toLowerCase().endsWith('.epub')) {
        _currentChapter = 'Page ${_pdfCurrentPage + 1}';
      }
      return;
    }

    PdfOutlineNode? current;
    for (final node in _pdfOutline) {
      if (node.dest?.pageNumber != null) {
        if (node.dest!.pageNumber <= _pdfCurrentPage + 1) {
          if (current == null ||
              (current.dest?.pageNumber ?? 0) <= node.dest!.pageNumber) {
            current = node;
          }
        }
      }
    }

    _currentPdfNode = current;
    if (current != null) {
      _currentChapter = current.title;
    } else {
      _currentChapter = 'Page ${_pdfCurrentPage + 1}';
    }
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
      // Use weights instead of simple counts
      for (var chapterIndex in _epubChaptersReadThisSession) {
        pagesRead += _getEpubChapterWeight(chapterIndex);
      }
      currentPage = _currentChapterIndex;
      totalPages = _chapters.length;
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

  int _getEpubChapterWeight(int index) {
    if (index < 0 || index >= _chapters.length) return 0;
    final chapter = _chapters[index];
    final contentLength = chapter.HtmlContent?.length ?? 0;
    return contentLength < 1000 ? 1 : 10;
  }

  Future<void> _addHighlight(Highlight highlight) async {
    final book = ref.read(currentlyReadingProvider);
    if (book?.id == null) return;

    // Check if this exact text+chapter already has a highlight
    final existing = _highlights
        .where(
          (h) =>
              h.chapterIndex == highlight.chapterIndex &&
              h.text == highlight.text,
        )
        .firstOrNull;

    final dbService = DatabaseService();

    if (existing != null) {
      // Update color of existing highlight
      final updated = existing.copyWith(color: highlight.color);
      await dbService.updateHighlight(updated);
    } else {
      // Insert new highlight with correct bookId
      final withBookId = highlight.copyWith(bookId: book!.id!);
      await dbService.insertHighlight(withBookId);
    }

    // Reload from DB to get correct IDs
    final highlights = await dbService.getHighlightsForBook(book!.id!);
    if (mounted) {
      setState(() => _highlights = highlights);
    }
  }

  Future<void> _deleteHighlight(int highlightId) async {
    final book = ref.read(currentlyReadingProvider);
    if (book?.id == null) return;

    final dbService = DatabaseService();
    await dbService.deleteHighlight(highlightId);

    final highlights = await dbService.getHighlightsForBook(book!.id!);
    if (mounted) {
      setState(() => _highlights = highlights);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(currentlyReadingProvider);
    final settings = ref.watch(readerSettingsProvider);

    if (book != null && _lastBookId != book.id) {
      _lastBookId = book.id;
      _resetReadingViewState();
    }

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

    final currentTracks = book.audioTracks.isEmpty && book.audioPath != null
        ? [
            AudioTrack(
              path: book.audioPath!,
              title: p.basename(book.audioPath!),
            ),
          ]
        : book.audioTracks;

    final hasAudio = currentTracks.isNotEmpty;

    // Detect if tracks have changed (different length or different paths/order)
    bool tracksChanged = false;
    if (hasAudio && _loadedAudioBookId == book.id.toString()) {
      // Logic to check if the current player source matches the tracks
      // For simplicity, we can compare with a stored hash or just length/first path
      // but here we can just check if the player's sequence length matches
      final source = _audioPlayer.audioSource;
      if (source is ConcatenatingAudioSource) {
        if (source.length != currentTracks.length) {
          tracksChanged = true;
        } else {
          // Check if any path changed
          // This is a bit expensive but necessary for reorders
          // For now, let's just use length and the fact that we'll reload if needed
        }
      }
    }

    if (hasAudio &&
        (_loadedAudioBookId != book.id.toString() || tracksChanged)) {
      _loadAudio(
        currentTracks,
        bookId: book.id.toString(),
        initialIndex: book.audioLastIndex ?? 0,
        initialPositionMs: book.audioLastPosition ?? 0,
      );
    } else if (!hasAudio && _loadedAudioBookId != null) {
      // Audio was removed, stop player
      _loadAudio([], bookId: null);
    }

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      resizeToAvoidBottomInset: false,
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
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      if (isEpub)
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) {
                            _epubPointerDownTime = DateTime.now();
                            _epubPointerDownPosition = event.position;
                          },
                          onPointerUp: (event) {
                            if (_epubPointerDownTime == null ||
                                _epubPointerDownPosition == null)
                              return;
                            final elapsed = DateTime.now().difference(
                              _epubPointerDownTime!,
                            );
                            final distance =
                                (event.position - _epubPointerDownPosition!)
                                    .distance;

                            // Short tap: under 300ms and minimal movement
                            if (elapsed < const Duration(milliseconds: 300) &&
                                distance < 20) {
                              _recordInteraction();
                              setState(() => _showControls = !_showControls);
                            }
                            _epubPointerDownTime = null;
                            _epubPointerDownPosition = null;
                          },
                          child: ReadingEpubView(
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
                            onToggleControls: () {
                              _recordInteraction();
                              setState(() => _showControls = !_showControls);
                            },
                            onInteraction: _recordInteraction,
                            searchQuery: _activeSearchQuery,
                            epubBook: _epubBook,
                            highlights: _highlights,
                            onHighlight: _addHighlight,
                            onDeleteHighlight: _deleteHighlight,
                          ),
                        )
                      else
                        ReadingPdfView(
                          key: ValueKey('pdf_${book.id}'),
                          book: book,
                          settings: settings,

                          controller: _pdfController ??= PdfViewerController(),
                          searcher: _pdfSearcher,
                          highlights: _highlights,
                          onHighlight: _addHighlight,
                          onDeleteHighlight: _deleteHighlight,
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
                                _updatePdfCurrentChapter();
                              });
                            }
                            if (!_initialized) {
                              _pageEntryTime = DateTime.now();
                              final initialPage =
                                  (book.progress * (_pdfPages - 1)).toInt();
                              _pdfCurrentPage = initialPage;
                              _scrollProgressNotifier.value = book.progress;
                              if (mounted) {
                                setState(() {
                                  _updatePdfCurrentChapter();
                                });
                              }
                              controller.goToPage(
                                pageNumber: initialPage + 1,
                                anchor: PdfPageAnchor.top,
                              );
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
                          onInteraction: () {
                            _recordInteraction();
                          },
                          onHideControls: () {
                            _recordInteraction();
                            setState(() => _showControls = !_showControls);
                          },
                          showControls: _showControls,
                          scrollProgressNotifier: _scrollProgressNotifier,
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
          top: _showControls ? 0 : -200,
          left: 0,

          right: 0,
          child: ValueListenableBuilder<String>(
            valueListenable: _currentTimeNotifier,
            builder: (context, currentTime, _) {
              return ReadingHeader(
                searchKey: _searchKey,
                lockKey: _lockKey,
                book: book,
                settings: settings,
                currentChapter: _currentChapter,
                pageInfo: isEpub
                    ? ValueListenableBuilder<double>(
                        valueListenable: _scrollProgressNotifier,
                        builder: (context, scrollProgress, _) {
                          final overallProgress =
                              (_currentChapterIndex + scrollProgress) /
                              _chapters.length;
                          // Use the refined calculation logic for consistency
                          double displayProgress = overallProgress;
                          if (_currentChapterIndex == _chapters.length - 1 &&
                              scrollProgress > 0.99) {
                            displayProgress = 1.0;
                          }
                          return Text(
                            '${(displayProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: settings.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      )
                    : Text(
                        '${_pdfCurrentPage + 1} / $_pdfPages',
                        style: TextStyle(
                          color: settings.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                onToggleLock: _toggleLock,
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
          bottom: _showControls ? 0 : -800,
          left: 0,

          right: 0,
          child: ReadingBottomControls(
            tocKey: _tocKey,
            audioKey: _audioKey,
            autoScrollKey: _autoScrollKey,
            displaySettingsKey: _displaySettingsKey,
            book: book,
            settings: settings,
            isAudioControlsExpanded: _isAudioControlsExpanded,
            isNavigationSheetOpen: _isNavigationSheetOpen,
            isAutoScrolling: _isAutoScrolling,
            isBookmarked: _getCurrentBookmark() != null,
            playbackSpeed: _playbackSpeed,
            isOrientationLandscape: _isOrientationLandscape,
            audioSection: ReadingAudioSection(
              settings: settings,
              isLoading: _isAudioLoading,
              positionNotifier: _audioPositionNotifier,
              durationNotifier: _audioDurationNotifier,
              currentIndexNotifier: _audioIndexNotifier,
              audioTracks: book.audioTracks.isEmpty && book.audioPath != null
                  ? [
                      AudioTrack(
                        path: book.audioPath!,
                        title: p.basename(book.audioPath!),
                      ),
                    ]
                  : book.audioTracks,
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
              isOrientationLandscape: _isOrientationLandscape,
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
                _showNavigationSheet(book: book, settings: settings),
            onToggleBookmark: () => _toggleBookmark(book),
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
            onSkip: _skip,
            onNextTrack: _audioPlayer.hasNext
                ? () => _audioPlayer.seekToNext()
                : null,
            onPrevTrack: _audioPlayer.hasPrevious
                ? () => _audioPlayer.seekToPrevious()
                : null,
            onShowTrackList: () => _showTrackListSheet(book),
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

      if (book.filePath.toLowerCase().endsWith('.pdf')) {
        if (result.pageIndex != _pdfCurrentPage) {
          _isJumpingFromToc = true;
          _setPdfPage(result.pageIndex);
        }
      } else {
        if (result.pageIndex != _currentChapterIndex) {
          _isJumpingFromToc = true;
          _currentChapterIndex = result.pageIndex;
          _currentChapter =
              _chapters[result.pageIndex].Title ??
              'Chapter ${result.pageIndex + 1}';
        }
      }

      if (result.scrollProgress != null) {
        _initialScrollProgress = result.scrollProgress!;
      }
    });

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (result.metadata is PdfTextMatch) {
        _pdfSearcher?.goToMatch(result.metadata as PdfTextMatch);
      } else {
        _jumpToPdfPage(result.pageIndex + 1);
      }
    } else {
      _pageController?.jumpToPage(result.pageIndex);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showNavigationSheet({
    required Book book,
    required ReaderSettings settings,
    bool focusJump = false,
  }) {
    if (!mounted) return;

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
          currentPdfNode: _currentPdfNode,
          totalPages: _pdfPages,
          focusJump: focusJump,
          onChapterTap: (index) {
            Navigator.pop(context);
            if (index != _currentChapterIndex) {
              setState(() {
                _currentChapterIndex = index;
                _currentChapter =
                    _chapters[index].Title ?? 'Chapter ${index + 1}';
              });
              _pageController?.jumpToPage(index);
            }
          },
          onPdfOutlineTap: (node) {
            if (node.dest?.pageNumber != null) {
              Navigator.pop(context);
              final targetPage = node.dest!.pageNumber;
              if (targetPage - 1 != _pdfCurrentPage) {
                _jumpToPdfPage(targetPage);
              }
            }
          },
          onJumpToPage: (page) {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context);
            if (page - 1 != _pdfCurrentPage) {
              _jumpToPdfPage(page);
            }
          },
          onJumpToPercent: (percent) {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _jumpToPercent(percent, book);
            });
          },
          getBookmarks: () =>
              ref.read(libraryProvider.notifier).getBookmarks(book.id!),
          onDeleteBookmark: (bookmark) async {
            await ref
                .read(libraryProvider.notifier)
                .deleteBookmark(bookmark.id!);
            await _loadBookmarks();
          },
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
              if (targetPage - 1 != _pdfCurrentPage) {
                _jumpToPdfPage(targetPage);
              }
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
