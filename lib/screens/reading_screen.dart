import 'dart:io' as io;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:epub_view/epub_view.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/constants.dart';
import '../core/yomu_colors.dart';
import '../core/theme.dart';
import '../components/display_settings_sheet.dart';
import '../providers/library_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../models/book_model.dart';
import '../models/reader_settings_model.dart';
import '../models/bookmark_model.dart';
import '../models/search_result_model.dart';
import '../utils/epub_page_weight.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:battery_plus/battery_plus.dart';

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
import '../utils/pdf_highlight_anchor.dart';
import '../services/database_service.dart';
import '../services/annotation_audio_service.dart';
import '../services/voice_note_playback.dart';
import '../utils/annotation_order.dart';
import '../utils/epub_text_match.dart';
import './reading/widgets/note_card_sheet.dart';
import './reading/widgets/note_walkthrough.dart';
import '../providers/shared_welcome_provider.dart';
import './reading/widgets/share_with_notes.dart';
import '../services/file_storage_service.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_files.dart';
import '../components/desktop/adaptive_sheet.dart';
import '../components/desktop/route_shortcuts.dart';
import '../core/platform_caps.dart';
import '../services/library_files.dart';
import '../core/breakpoints.dart';
import './reading/widgets/reader_column.dart';
import './reading/paging/epub_page_turner.dart';
import '../providers/appearance_provider.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

part 'reading/reader_desktop.dart';

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
  late final EpubReadingCredit _epubReadingCredit = EpubReadingCredit(
    minTimePerPage: _readThreshold,
  );

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

  /// The EPUB's chapter on screen when it is read as pages.
  final EpubPageTurner _epubPageTurner = EpubPageTurner();

  /// How the open EPUB was laid out last build, to keep the place when the
  /// reader switches between scrolling and pages.
  PageTurn? _lastEpubPageTurn;

  /// The app's light/dark the page theme last followed.
  Brightness? _lastAppBrightness;

  /// Auto page turn for a PDF read as slides: scroll distance so far.
  double _pdfAutoTurnDistance = 0;

  bool get _pdfSlides =>
      ref.read(readerSettingsProvider).pdfPageTurn == PageTurn.slide;

  // UI state
  final ValueNotifier<bool> _showControlsNotifier = ValueNotifier(true);
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
  int _batteryLevel = 100;
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batterySubscription;
  
  List<int> _epubChapterLengths = [];
  int _epubTotalLength = 0;

  void _resetReadingViewState() {
    // Switch between EPUB and PDF theme preferences on open
    final book = ref.read(currentlyReadingProvider);
    if (book != null) {
      final isPdf = book.filePath.toLowerCase().endsWith('.pdf');
      Future.microtask(() {
        if (mounted) {
          if (isPdf) {
            // For PDFs, always force white on open
            ref.read(readerSettingsProvider.notifier).setTheme(ReaderTheme.white);
          } else {
            // For EPUBs, the page theme chosen for the app's appearance
            ref
                .read(readerSettingsProvider.notifier)
                .followAppearance(Theme.of(context).brightness);
          }
        }
      });
    }

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
    _epubReadingCredit.clear();
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
    _epubChapterLengths = [];
    _epubTotalLength = 0;
    // Force reload bookmarks/highlights for the NEW book
    _loadBookmarks();
  }

  @override
  void initState() {
    super.initState();
    VoiceNotePlayback.instance.onStart.add(_onVoiceNoteStart);
    VoiceNotePlayback.instance.onFinish.add(_onVoiceNoteFinish);
    Future.microtask(() {
      if (mounted) ref.read(libraryProvider.notifier).setReadingActive(true);
    });
    // Only phones show the battery (see ReadingFooter); on a computer the
    // query can fail outright, e.g. Linux without UPower.
    if (!PlatformCaps.isDesktop) {
      _getInitialBattery();
      _startBatterySubscription();
    }
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

        final dy = speed * 30.0 * deltaTime;
        if (_pdfSlides) {
          // As slides, a page turns once the scroll would have covered a
          // screen's height.
          _pdfAutoTurnDistance += dy;
          if (_pdfAutoTurnDistance >= MediaQuery.sizeOf(context).height) {
            _pdfAutoTurnDistance = 0;
            _jumpToPdfPage(_pdfCurrentPage + 2);
          }
          return;
        }

        // In pdfrx, we scroll by manipulating the matrix
        final currentMatrix = _pdfController!.value;

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
      ref.read(libraryProvider.notifier).setReadingActive(true);
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
      final hidden = await _loadHiddenAuthors(book.id!);
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _highlights = highlights;
          _hiddenAuthors = hidden;
          _hiddenVersion++;
        });
      }
      await _refreshReplyCounts(book.id!);
      await _placeNotesByText();
      await _maybeWelcomeSharedNotes(book);
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
      // The audiobook and a voice note never play at once.
      if (state.playing && VoiceNotePlayback.instance.playing) {
        _resumeAudiobookAfterVoiceNote = false;
        VoiceNotePlayback.instance.pause();
      }
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
      dialogTitle: 'Choose audiobook files',
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      // Copies the picked files out of the cache dir and skips duplicates.
      final imported = await FileStorageService.importAudioTracks(
        result.paths,
        book.id,
        book.audioTracks,
      );
      final List<AudioTrack> newTracks = [
        ...book.audioTracks,
        ...imported.added,
      ];
      final duplicatesCount = imported.duplicates;

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

    showAdaptiveSheet(
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
                    onReorderItem: (oldIndex, newIndex) async {
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
                                        .withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _removeTrack(latestBook, index);
                                  },
                                ),
                                Icon(
                                  Icons.drag_handle,
                                  color: settings.secondaryTextColor
                                      .withValues(alpha: 0.3),
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
  void deactivate() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Future.microtask(() {
      if (mounted) ref.read(libraryProvider.notifier).setReadingActive(false);
    });
    super.deactivate();
  }

  @override
  void dispose() {
    VoiceNotePlayback.instance.onStart.remove(_onVoiceNoteStart);
    VoiceNotePlayback.instance.onFinish.remove(_onVoiceNoteFinish);
    VoiceNotePlayback.instance.stop();
    _audioPlayer.dispose();
    _epubController?.dispose();
    _pageController?.dispose();
    _epubPageTurner.dispose();
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();
    _currentTimeTimer?.cancel();
    _batterySubscription?.cancel();
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
    _showControlsNotifier.dispose();

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

    _pdfController?.goToPage(
      pageNumber: targetPage,
      // duration: const Duration(milliseconds: 300),
      anchor: _pdfSlides ? PdfPageAnchor.center : PdfPageAnchor.top,
    );
    _recordInteraction();
  }

  /// Scrolls a PDF to a highlight: to its first line when its position holds
  /// character offsets, otherwise to the top of its page.
  Future<void> _jumpToPdfHighlight(Highlight h) async {
    final controller = _pdfController;
    final anchor = PdfHighlightAnchor.tryParse(h.position);
    if (controller == null ||
        !_isPdfReady ||
        anchor == null ||
        anchor.startPage >= _pdfPages) {
      _jumpToPdfPage(h.chapterIndex + 1);
      return;
    }
    final pageNumber = anchor.startPage + 1;
    try {
      final pageText = await controller.pages[anchor.startPage]
          .loadStructuredText(ensureLoaded: true);
      final range = anchor.rangeOnPage(
        anchor.startPage,
        pageText.fullText,
        h.text,
      );
      if (!mounted) return;
      if (range == null) {
        _jumpToPdfPage(pageNumber);
        return;
      }
      if (anchor.startPage != _pdfCurrentPage) {
        setState(() {
          _isJumpingFromToc = true;
          _setPdfPage(anchor.startPage);
        });
      }
      final bounds = PdfPageTextRange(
        pageText: pageText,
        start: range.start,
        end: range.end,
      ).bounds;
      await controller.ensureVisible(
        controller.calcRectForRectInsidePage(
          pageNumber: pageNumber,
          rect: bounds,
        ),
        margin: 50,
      );
      // Report the highlight's page as current even if a neighbouring page
      // fills more of the screen, so the jump above completes.
      controller.setCurrentPageNumber(pageNumber);
      _recordInteraction();
    } catch (e) {
      debugPrint('Could not jump to PDF highlight: $e');
      if (mounted) _jumpToPdfPage(pageNumber);
    }
  }

  // --- Notes from different readers --------------------------------------

  /// Readers whose notes are hidden in the text; '' stands for your own.
  Set<String> _hiddenAuthors = {};
  int _hiddenVersion = 0;
  List<Highlight>? _visibleCache;
  List<Highlight>? _visibleCacheSource;
  int _visibleCacheVersion = -1;

  /// Replies per highlight uid, for the markers in the text.
  Map<String, int> _replyCounts = const {};

  static String _authorKey(String? sharedBy) => sharedBy ?? '';
  static String _hiddenAuthorsKey(int bookId) => 'hidden_note_authors_$bookId';

  /// Highlights shown in the text: all but those of hidden readers. Kept
  /// as the same list between rebuilds so the views don't redo their work.
  List<Highlight> get _visibleHighlights {
    if (_hiddenAuthors.isEmpty) return _highlights;
    if (!identical(_visibleCacheSource, _highlights) ||
        _visibleCacheVersion != _hiddenVersion) {
      _visibleCacheSource = _highlights;
      _visibleCacheVersion = _hiddenVersion;
      _visibleCache = _highlights
          .where((h) => !_hiddenAuthors.contains(_authorKey(h.sharedBy)))
          .toList();
    }
    return _visibleCache!;
  }

  Future<Set<String>> _loadHiddenAuthors(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenAuthorsKey(bookId)) ?? const [])
        .toSet();
  }

  Future<void> _setAuthorHidden(String? sharedBy, bool hidden) async {
    final book = ref.read(currentlyReadingProvider);
    if (book?.id == null) return;
    final key = _authorKey(sharedBy);
    setState(() {
      _hiddenAuthors = {..._hiddenAuthors};
      hidden ? _hiddenAuthors.add(key) : _hiddenAuthors.remove(key);
      _hiddenVersion++;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _hiddenAuthorsKey(book!.id!),
      _hiddenAuthors.toList(),
    );
  }

  Future<void> _refreshReplyCounts(int bookId) async {
    final replies = await DatabaseService().getRepliesForBook(bookId);
    final counts = <String, int>{};
    for (final r in replies) {
      counts[r.highlightUid] = (counts[r.highlightUid] ?? 0) + 1;
    }
    if (mounted) setState(() => _replyCounts = counts);
  }

  bool get _isPdfBook =>
      ref.read(currentlyReadingProvider)?.filePath.toLowerCase().endsWith(
        '.pdf',
      ) ??
      false;

  List<String?> get _chapterTitles => [for (final c in _chapters) c.Title];

  /// Opens the card with a highlight's note, voice note and replies.
  Future<void> _openNoteCard(Highlight highlight, {VoidCallback? onGoTo}) async {
    final book = ref.read(currentlyReadingProvider);
    if (book?.id == null) return;
    await showNoteCard(
      context,
      highlight: highlight,
      settings: ref.read(readerSettingsProvider),
      onUpdate: _addHighlight,
      onDelete: _deleteHighlight,
      location: AnnotationOrder.location(
        highlight,
        isPdf: _isPdfBook,
        chapterTitles: _chapterTitles,
      ),
      onGoTo: onGoTo,
    );
    await _refreshReplyCounts(book!.id!);
  }

  /// Scrolls the text to a highlight.
  void _jumpToHighlight(Highlight h) {
    final book = ref.read(currentlyReadingProvider);
    if (book == null) return;
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (h.position.contains(':')) {
        final parts = h.position.split(':');
        final index = int.tryParse(parts[0]) ?? h.chapterIndex;
        // Position format is now 'index:ratio' or 'index:exact:occurrenceIndex:ratio'
        // In both cases, the ratio for navigation is the last part.
        final progress = double.tryParse(parts.last) ?? 0.0;
        
        if (index >= 0 && index < _chapters.length) {
          final bool isSameChapter = index == _currentChapterIndex;
          setState(() {
            _currentChapterIndex = index;
            _initialScrollProgress = progress;
            _currentChapter =
                _chapters[index].Title ?? 'Chapter ${index + 1}';
          });
          
          // If same chapter, jumpToPage(index) might not trigger a rebuild/didUpdateWidget 
          // in some PageView implementations if the index is identical,
          // but our state update above will propagate through the widget tree.
          _pageController?.jumpToPage(index);
          
          if (isSameChapter) {
            _recordInteraction();
          }
        }
      }
    } else {
      _jumpToPdfHighlight(h);
    }
  }

  // --- Walking through notes ----------------------------------------------

  List<Highlight>? _walkNotes;
  int _walkIndex = 0;

  void _startWalkThrough(List<Highlight> notes) {
    if (notes.isEmpty) return;
    _setControlsVisibility(false);
    setState(() {
      _walkNotes = notes;
      _walkIndex = 0;
    });
    _showWalkNote();
  }

  void _stepWalkThrough(int delta) {
    final notes = _walkNotes;
    if (notes == null) return;
    final next = _walkIndex + delta;
    if (next < 0 || next >= notes.length) return;
    setState(() => _walkIndex = next);
    _showWalkNote();
  }

  /// Jumps to the current note and plays its voice note.
  void _showWalkNote() {
    final note = _walkNotes![_walkIndex];
    _jumpToHighlight(note);
    if (note.hasAudio) {
      VoiceNotePlayback.instance.play(note.audioFile!);
    } else {
      VoiceNotePlayback.instance.pause();
    }
  }

  void _endWalkThrough() {
    VoiceNotePlayback.instance.pause();
    setState(() => _walkNotes = null);
  }

  Widget _buildWalkthroughBar() {
    final notes = _walkNotes!;
    // The note may have been edited or deleted since the walk started.
    final current = notes[_walkIndex];
    final note =
        _highlights.where((h) => h.id == current.id).firstOrNull ?? current;
    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: NoteWalkthroughBar(
        note: note,
        index: _walkIndex,
        count: notes.length,
        replyCount: _replyCounts[note.uid] ?? 0,
        onPrevious: _walkIndex > 0 ? () => _stepWalkThrough(-1) : null,
        onNext: _walkIndex < notes.length - 1
            ? () => _stepWalkThrough(1)
            : null,
        onOpen: () => _openNoteCard(note),
        onClose: _endWalkThrough,
      ),
    );
  }

  /// Greets a book that just arrived with someone's notes.
  Future<void> _maybeWelcomeSharedNotes(Book book) async {
    final welcome = ref.read(sharedWelcomeProvider);
    if (welcome == null || welcome.bookId != book.id) return;
    ref.read(sharedWelcomeProvider.notifier).state = null;
    final theirs = AnnotationOrder.sorted(
      _highlights.where((h) => h.sharedBy == welcome.sharedBy),
      isPdf: _isPdfBook,
    );
    if (theirs.isEmpty || !mounted) return;
    final withNotes = theirs.where((h) => h.hasNote || h.hasAudio).toList();
    final walk = await showSharedWelcomeSheet(
      context,
      bookTitle: book.title,
      sharedBy: welcome.sharedBy,
      noteCount: theirs.length,
      voiceCount: theirs.where((h) => h.hasAudio).length,
      replyCount: welcome.newReplies,
    );
    if (walk == true && mounted) {
      // Let the book finish opening before jumping around in it.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _startWalkThrough(withNotes.isEmpty ? theirs : withNotes);
    }
  }

  // --- Notes from another copy of the book ---------------------------------

  bool _placingNotes = false;

  /// Finds where notes shared from another copy of this book belong, by
  /// their text. Notes that can't be found stay listed, marked unplaced.
  Future<void> _placeNotesByText() async {
    final toPlace = _highlights.where((h) => h.needsPlacing).toList();
    if (toPlace.isEmpty || _placingNotes) return;
    final isPdf = _isPdfBook;
    if (isPdf && (_pdfController == null || !_isPdfReady)) return;
    if (!isPdf && _chapters.isEmpty) return;
    _placingNotes = true;
    final db = DatabaseService();
    try {
      if (isPdf) {
        await _placePdfNotes(toPlace, db);
      } else {
        final html = [for (final c in _chapters) c.HtmlContent ?? ''];
        for (final h in toPlace) {
          final found = findInChapters(
            html,
            h.text,
            near: h.chapterIndex,
            nearRatio: AnnotationOrder.epubRatio(h),
          );
          await db.updateHighlight(
            found == null
                ? h.copyWith(anchorState: Highlight.anchorUnplaced)
                : h.copyWith(
                    chapterIndex: found.chapter,
                    position: found.position,
                    anchorState: null,
                  ),
          );
        }
      }
      final book = ref.read(currentlyReadingProvider);
      if (book?.id == null) return;
      final highlights = await db.getHighlightsForBook(book!.id!);
      if (mounted) setState(() => _highlights = highlights);
    } catch (e) {
      debugPrint('Could not place shared notes: $e');
    } finally {
      _placingNotes = false;
    }
  }

  Future<void> _placePdfNotes(List<Highlight> notes, DatabaseService db) async {
    final pages = _pdfController!.pages;
    final texts = <int, String>{};
    Future<String> textOf(int index) async =>
        texts[index] ??= (await pages[index].loadStructuredText(
          ensureLoaded: true,
        )).fullText;

    for (final h in notes) {
      final hint = h.chapterIndex.clamp(0, pages.length - 1);
      final anchorHint = PdfHighlightAnchor.tryParse(h.position);
      Highlight? placed;
      for (var step = 0; step < pages.length * 2 && placed == null; step++) {
        final offset = (step + 1) ~/ 2 * (step.isOdd ? 1 : -1);
        final page = hint + offset;
        if (page < 0 || page >= pages.length) continue;
        final range = PdfHighlightAnchor.find(
          await textOf(page),
          h.text,
          near: page == hint ? anchorHint?.startIndex ?? 0 : 0,
        );
        if (range == null) continue;
        placed = h.copyWith(
          chapterIndex: page,
          position: PdfHighlightAnchor(
            startPage: page,
            startIndex: range.start,
            endPage: page,
            endIndex: range.end,
          ).format(),
          anchorState: null,
        );
      }
      await db.updateHighlight(
        placed ?? h.copyWith(anchorState: Highlight.anchorUnplaced),
      );
    }
  }

  /// Set when a voice note paused the audiobook, so it resumes afterwards.
  bool _resumeAudiobookAfterVoiceNote = false;

  void _onVoiceNoteStart() {
    if (_audioPlayer.playing) {
      _resumeAudiobookAfterVoiceNote = true;
      _audioPlayer.pause();
    }
  }

  void _onVoiceNoteFinish() {
    if (_resumeAudiobookAfterVoiceNote && mounted) {
      _resumeAudiobookAfterVoiceNote = false;
      _audioPlayer.play();
    }
  }

  void _jumpToPercent(double percent, Book book) {
    if (book.filePath.toLowerCase().endsWith('.epub')) {
      if (_chapters.isEmpty || _epubTotalLength == 0) return;

      final double targetTotalProgress = percent * _epubTotalLength;
      int chapterIndex = 0;
      double accumulatedLength = 0;

      for (int i = 0; i < _epubChapterLengths.length; i++) {
        final length = _epubChapterLengths[i];
        if (accumulatedLength + length >= targetTotalProgress) {
          chapterIndex = i;
          break;
        }
        accumulatedLength += length;
        if (i == _epubChapterLengths.length - 1) chapterIndex = i;
      }

      final double remainingLength = targetTotalProgress - accumulatedLength;
      final double chapterLength = _epubChapterLengths[chapterIndex].toDouble();
      final double chapterScrollProgress =
          (chapterLength > 0 ? remainingLength / chapterLength : 0.0)
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

  void _setControlsVisibility(bool visible) {
    if (_showControlsNotifier.value == visible) return;
    _showControlsNotifier.value = visible;
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleControls() {
    _recordInteraction();
    // On desktop the pointer brings the controls up and they hide on their
    // own, so a click in the text never hides them.
    if (Breakpoints.isWide(context)) return _revealControlsForPointer();
    _setControlsVisibility(!_showControlsNotifier.value);
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
            if (_scrollProgressNotifier.value >= bookmarkProgress &&
                _scrollProgressNotifier.value < bookmarkProgress + 0.05) {
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
            Breakpoints.isWide(context)
                ? _desktopToast(Icons.bookmark_remove_rounded, 'Bookmark removed')
                : SnackBar(
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
            Breakpoints.isWide(context)
                ? _desktopToast(Icons.bookmark_added_rounded, 'Position bookmarked')
                : SnackBar(
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
      document: EpubDocument.openFile(io.File(book.filePath)),
      epubCfi: book.lastPosition,
    );
    _epubController = controller;

    // Extract chapters when document is loaded
    controller.document.then((document) {
      final flattenedChapters = _flattenChapters(document.Chapters ?? []);
      
      // Visible text length per chapter, for page weights and weighted progress
      final lengths = epubChapterTextLengths(flattenedChapters);
      final total = lengths.fold(0, (sum, len) => sum + len);

      setState(() {
        _epubBook = document;
        _chapters = flattenedChapters;
        _epubChapterLengths = lengths;
        _epubTotalLength = total;

        // Find initial chapter index and scroll progress from overall progress
        if (total > 0) {
          // EPUB saves store the chapter index in currentPage/totalPages
          final position = epubPositionAt(
            lengths,
            book.progress,
            savedChapter: book.totalPages == lengths.length
                ? book.currentPage
                : null,
          );
          _currentChapterIndex = position.chapter;
          _initialScrollProgress = position.scroll;
        } else {
          // Fallback to equal chapters if lengths are unknown
          double totalProgress = book.progress * flattenedChapters.length;
          _currentChapterIndex = totalProgress.floor().clamp(
            0,
            flattenedChapters.length - 1,
          );
          _initialScrollProgress = totalProgress - _currentChapterIndex;
        }

        _pageController = PageController(initialPage: _currentChapterIndex);
        _currentChapter =
            flattenedChapters[_currentChapterIndex].Title ??
            'Chapter ${_currentChapterIndex + 1}';
        _epubPageEntryTime = DateTime.now();
        _initialized = true;
      });
      // Notes from another copy of the book can be placed now.
      _placeNotesByText();
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
      if (_chapters.isNotEmpty && _epubTotalLength > 0) {
        final double progress = epubProgressAt(
          _epubChapterLengths,
          _currentChapterIndex,
          _scrollProgressNotifier.value,
        );

        // If we are in the last chapter and very close to the end, snap to 1.0
        if (_currentChapterIndex == _chapters.length - 1 &&
            _scrollProgressNotifier.value > 0.99) {
          return 1.0;
        }
        return progress.clamp(0.0, 1.0);
      } else if (_chapters.isNotEmpty) {
        // Fallback
        final double progress =
            (_currentChapterIndex + _scrollProgressNotifier.value) /
            _chapters.length;
        return progress.clamp(0.0, 1.0);
      }
    }
    return book.progress;
  }

  void _handleChapterPageChange(int index, Book book) {
    if (index == _currentChapterIndex) return;

    final now = DateTime.now();

    // Credit what was scrolled through since the last update
    final int pagesRead = _takeEpubPagesRead(now);

    setState(() {
      _shouldJumpToBottom = !_isJumpingFromToc && index < _currentChapterIndex;
      _currentChapterIndex = index;
      _currentChapter = _chapters[index].Title ?? 'Chapter ${index + 1}';
      // Reset scroll progress for new chapter
      _scrollProgressNotifier.value = 0.0;
    });

    _recordInteraction();

    final progress = _calculateCurrentProgress(book);

    // Report pages read if any were accumulated
    ref
        .read(libraryProvider.notifier)
        .updateBookProgress(
          book.id!,
          progress,
          pagesRead: pagesRead,
          durationMinutes: 0,
          currentPage: _currentChapterIndex,
          totalPages: _chapters.length,
          estimateReadingTime: false,
        );
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
      pagesRead = _takeEpubPagesRead(now);
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
      _lastSyncTime = now;
    }
    _accumulatedSeconds = 0;
  }

  int _getEpubChapterWeight(int index) {
    if (index < 0 || index >= _chapters.length || _epubChapterLengths.isEmpty) {
      return 0;
    }
    return epubChapterPages(_epubChapterLengths[index]);
  }

  /// Whole EPUB pages read since the last call: the newly seen part of each
  /// chapter, at most one page per [_readThreshold] since the last call.
  int _takeEpubPagesRead(DateTime now) {
    final since = _epubPageEntryTime;
    _epubPageEntryTime = now;
    if (since == null || _chapters.isEmpty) return 0;
    return _epubReadingCredit.takePages(
      List.generate(_chapters.length, _getEpubChapterWeight),
      now.difference(since),
    );
  }

  Future<void> _addHighlight(Highlight highlight) async {
    final book = ref.read(currentlyReadingProvider);
    if (book?.id == null) return;

    final dbService = DatabaseService();

    // Edits of a saved highlight (note, color, voice note) arrive with its id.
    if (highlight.id != null) {
      await dbService.updateHighlight(highlight.copyWith(bookId: book!.id!));
      final highlights = await dbService.getHighlightsForBook(book.id!);
      if (mounted) setState(() => _highlights = highlights);
      return;
    }

    // Check if this exact text+chapter already has a highlight
    final existing = _highlights
        .where(
          (h) =>
              h.chapterIndex == highlight.chapterIndex &&
              h.text == highlight.text &&
              h.position == highlight.position,
        )
        .firstOrNull;

    if (existing != null) {
      // Update color and note of existing highlight
      var updated = existing.copyWith(
        color: highlight.color,
        note: highlight.note,
      );
      if (highlight.hasAudio) {
        if (existing.audioFile != highlight.audioFile) {
          await AnnotationAudioService.delete(existing.audioFile);
        }
        updated = updated.copyWith(
          audioFile: highlight.audioFile,
          audioDurationMs: highlight.audioDurationMs,
          audioWaveform: highlight.audioWaveform,
        );
      }
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

  /// Switching between scrolling and pages builds a new chapter pager, so
  /// it is told to open where the reader was.
  void _keepPlaceAcrossPageTurnModes(PageTurn pageTurn) {
    final previous = _lastEpubPageTurn;
    _lastEpubPageTurn = pageTurn;
    if (previous == null || previous == pageTurn || _pageController == null) {
      return;
    }
    final old = _pageController!;
    _pageController = PageController(initialPage: _currentChapterIndex);
    // The old pager lets go of it at the end of this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _shouldJumpToBottom = false;
    _initialScrollProgress = _scrollProgressNotifier.value;
  }

  /// When the app turns light or dark (the system at dusk, or the setting),
  /// an EPUB's page takes the theme chosen for that appearance.
  void _followAppAppearance() {
    final brightness = Theme.of(context).brightness;
    final previous = _lastAppBrightness;
    _lastAppBrightness = brightness;
    if (previous == null || previous == brightness) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerSettingsProvider.notifier).followAppearance(brightness);
    });
  }

  /// The day/night button: the app flips between light and dark, and the
  /// page (PDFs too) takes the theme chosen for the new appearance.
  void _toggleDayNight() {
    final current = Theme.of(context).brightness;
    final next = current == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    _lastAppBrightness = next;
    ref.read(appearanceProvider.notifier).toggle(current);
    ref
        .read(readerSettingsProvider.notifier)
        .followAppearance(next, includePdf: true);
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
      _keepPlaceAcrossPageTurnModes(settings.epubPageTurn);
    }
    _followAppAppearance();

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

    // The status bar sits on the page, so its icons follow the page's
    // colour rather than the app's light or dark.
    final pageIsLight = settings.backgroundColor.computeLuminance() > 0.5;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: YomuTheme.systemBars(
        pageIsLight ? Brightness.light : Brightness.dark,
      ),
      child: _withReaderToastInset(Scaffold(
      backgroundColor: settings.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: _withReaderShortcuts(book: book, child: PopScope(
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
                        _readerColumn(isEpub: true, settings: settings, child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) {
                            _epubPointerDownTime = DateTime.now();
                            _epubPointerDownPosition = event.position;
                          },
                          onPointerUp: (event) {
                            if (_epubPointerDownTime == null ||
                                _epubPointerDownPosition == null) {
                              return;
                            }
                            final elapsed = DateTime.now().difference(
                              _epubPointerDownTime!,
                            );
                            final distance =
                                (event.position - _epubPointerDownPosition!)
                                    .distance;

                            // As pages, a touch tap turns the page or shows
                            // the controls by where it lands (the page does
                            // that itself); a click still shows them.
                            final pageHandlesTap =
                                settings.epubPageTurn == PageTurn.slide &&
                                event.kind != PointerDeviceKind.mouse;
                            // Short tap: under 300ms and minimal movement
                            if (!pageHandlesTap &&
                                elapsed < const Duration(milliseconds: 300) &&
                                distance < 20) {
                              _toggleControls();
                            }
                            _epubPointerDownTime = null;
                            _epubPointerDownPosition = null;
                          },
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _showControlsNotifier,
                            builder: (context, showControls, _) {
                              return ReadingEpubView(
                                // A fresh pager when switching between
                                // scrolling and pages (see
                                // _keepPlaceAcrossPageTurnModes).
                                key: ValueKey(settings.epubPageTurn),
                                pageTurn: settings.epubPageTurn,
                                pageTurner: _epubPageTurner,
                                book: book,
                                settings: settings,
                                chapters: _chapters,
                                pageController: _pageController,
                                currentChapterIndex: _currentChapterIndex,
                                shouldJumpToBottom: _shouldJumpToBottom,
                                initialScrollProgress: _initialScrollProgress,
                                onJumpedToBottom: () =>
                                    setState(() => _shouldJumpToBottom = false),
                                onJumpedToPosition: () =>
                                    setState(() => _initialScrollProgress = 0.0),
                                pullDistanceNotifier: _pullDistanceNotifier,
                                isPullingDownNotifier: _isPullingDownNotifier,
                                scrollProgressNotifier: _scrollProgressNotifier,
                                autoScrollSpeedNotifier: _autoScrollSpeedNotifier,
                                showControls: showControls,
                                onPageChanged: (index) =>
                                    _handleChapterPageChange(index, book),
                                onHideControls: () {
                                  if (_showControlsNotifier.value) {
                                    _setControlsVisibility(false);
                                  }
                                },
                                onToggleControls: _toggleControls,
                                onInteraction: _recordInteraction,
                                highlights: _visibleHighlights,
                                onHighlight: _addHighlight,
                                onDeleteHighlight: _deleteHighlight,
                                onLookup: _lookupDictionary,
                                onOpenNote: _openNoteCard,
                                replyCounts: _replyCounts,
                                onContentSeen: _epubReadingCredit.markSeen,
                                searchQuery: _activeSearchQuery,
                                epubBook: _epubBook,
                              );
                            },
                          ),
                        ))
                      else
                        _readerColumn(isEpub: false, settings: settings, child: ReadingPdfView(
                          key: ValueKey('pdf_${book.id}'),
                          book: book,
                          settings: settings,

                          controller: _pdfController ??= PdfViewerController(),
                          searcher: _pdfSearcher,
                          highlights: _visibleHighlights,
                          onHighlight: _addHighlight,
                          onDeleteHighlight: _deleteHighlight,
                          onLookup: _lookupDictionary,
                          onOpenNote: _openNoteCard,
                          replyCounts: _replyCounts,
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
                              _placeNotesByText();
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
                                anchor: _pdfSlides
                                    ? PdfPageAnchor.center
                                    : PdfPageAnchor.top,
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
                          onHideControls: _toggleControls,
                          showControls: _showControlsNotifier.value,
                          scrollProgressNotifier: _scrollProgressNotifier,
                          pageTurn: settings.pdfPageTurn,
                          onTurnPage: (direction) {
                            _setControlsVisibility(false);
                            _turnPage(direction);
                          },
                        )),
                      _buildAnimatedControlsOverlay(context, book, settings),
                      if (_walkNotes != null) _buildWalkthroughBar(),
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
                    pagePosition: isEpub ? _epubPageTurner.position : null,
                    book: book,
                    settings: settings,
                    currentTime: currentTime,
                    currentChapter: _currentChapter,
                    batteryLevel: _batteryLevel,
                    scrollProgressNotifier: _scrollProgressNotifier,
                    totalChapters: _chapters.length,
                    currentChapterIndex: _currentChapterIndex,
                    chapterLengths: _epubChapterLengths,
                  );
                },
              ),
            ],
          ),
        ),
      )),
    )),
    );
  }

  Widget _buildAnimatedControlsOverlay(
    BuildContext context,
    Book book,
    ReaderSettings settings,
  ) {
    final isEpub = book.filePath.toLowerCase().endsWith('.epub');

    return ValueListenableBuilder<bool>(
      valueListenable: _showControlsNotifier,
      builder: (context, showControls, _) {
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: showControls ? 0 : -200,
              left: 0,
              right: 0,
          child: ValueListenableBuilder<String>(
            valueListenable: _currentTimeNotifier,
            builder: (context, currentTime, _) {
              return ReadingHeader(
                searchKey: _searchKey,
                lockKey: _lockKey,
                isNight: Theme.of(context).brightness == Brightness.dark,
                onToggleDayNight: _toggleDayNight,
                book: book,
                settings: settings,
                currentChapter: _currentChapter,
                pageInfo: isEpub
                    ? ValueListenableBuilder<double>(
                        valueListenable: _scrollProgressNotifier,
                        builder: (context, scrollProgress, _) {
                          final displayProgress = _calculateCurrentProgress(book);
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
                // Leaving the reader saves progress once, in PopScope below;
                // saving here as well recorded every session twice.
                onBackPressed: () => Navigator.of(context).pop(),
                onToggleSearch: () {
                  _isSearching = true;
                  _setControlsVisibility(true);
                  setState(() {});
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
          bottom: showControls ? 0 : -800,
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
      },
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
        await _pdfController?.useDocument((doc) async {
          if (_pdfSearcher != null) {
            // Track the query for highlighting in the PDF view
            _pdfSearcher!.startTextSearch(
              query,
              goToFirstMatch: false,
              searchImmediately: true,
            );

            for (int i = 0; i < doc.pages.length; i++) {
              final page = doc.pages[i];
              final pageText = await page.loadStructuredText();
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
                final match = PdfPageTextRange(
                  pageText: pageText,
                  start: index,
                  end: index + query.length,
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
        });
      } else {
        // EPUB Search
        for (int i = 0; i < _chapters.length; i++) {
          final chapter = _chapters[i];
          // Only the body the reader shows: epubx appends the rest of a
          // Calibre-split book to each chapter's HtmlContent.
          final content = cleanChapterHtml(chapter.HtmlContent ?? '');
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
      if (result.metadata is PdfPageTextRange) {
        _pdfSearcher?.goToMatch(result.metadata as PdfPageTextRange);
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

  Future<void> _getInitialBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (e) {
      debugPrint('Error getting battery level: $e');
    }
  }

  void _startBatterySubscription() {
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    });
  }

  Future<void> _exportToMarkdown(Book book) async {
    final bookmarks = await ref
        .read(libraryProvider.notifier)
        .getBookmarks(book.id!);
    final highlights = _highlights; // Already loaded in state
    final vocabulary = await ref
        .read(libraryProvider.notifier)
        .getVocabularyForBook(book.id!);

    bool includeVocabulary = false;
    if (vocabulary.isNotEmpty) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          bool includeVocab = true;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: context.yomu.surface,
                title: Text('Export Annotations', style: TextStyle(color: context.yomu.textPrimary)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ready to export all annotations as Markdown.',
                      style: TextStyle(color: context.yomu.tint(0.70), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text('Include Vocabulary List', style: TextStyle(color: context.yomu.textPrimary, fontSize: 14)),
                      subtitle: Text('Add words you looked up in this book', style: TextStyle(color: context.yomu.tint(0.38), fontSize: 11)),
                      value: includeVocab,
                      activeColor: context.yomu.accent,
                      checkColor: context.yomu.onAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => includeVocab = val ?? true),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('CANCEL', style: TextStyle(color: context.yomu.tint(0.54))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, includeVocab),
                    child: Text('SHARE', style: TextStyle(color: context.yomu.accent)),
                  ),
                ],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              );
            },
          );
        },
      );
      if (result == null) return; // Cancelled
      includeVocabulary = result;
    }

    final buffer = StringBuffer();
    buffer.writeln('# ${book.title}');
    buffer.writeln('*Exported with Yomu — ${DateTime.now().year}*');
    buffer.writeln();
    if (book.author.isNotEmpty) buffer.writeln('**Author:** ${book.author}');
    buffer.writeln('**Exported on:** ${_formatDate(DateTime.now())}');
    buffer.writeln();

    if (bookmarks.isNotEmpty) {
      buffer.writeln('## Bookmarks');
      for (final b in bookmarks) {
        buffer.writeln(
          '- ${b.title} (${(b.progress * 100).toStringAsFixed(1)}%) — ${_formatDate(b.createdAt)}',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('## Highlights & Notes');
    for (final h in highlights) {
      buffer.writeln('> ${h.text}');
      buffer.writeln();
      if (h.note != null && h.note!.isNotEmpty) {
        buffer.writeln('**Note:** ${h.note}');
        buffer.writeln();
      }
      final isPdf = book.filePath.toLowerCase().endsWith('.pdf');
      final pos = !isPdf && h.position.contains(':')
          ? 'Chapter ${(int.tryParse(h.position.split(':')[0]) ?? h.chapterIndex) + 1}'
          : 'Page ${h.chapterIndex + 1}';
      buffer.writeln('*Position: $pos — ${_formatDate(h.createdAt)}*');
      buffer.writeln('---');
    }

    if (includeVocabulary && vocabulary.isNotEmpty) {
      buffer.writeln('## Vocabulary List');
      for (final v in vocabulary) {
        buffer.writeln('- ${v.word} — ${_formatDate(v.timestamp)}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('---');
    buffer.writeln('*Exported with Yomu*');

    if (bookmarks.isEmpty && highlights.isEmpty) {
      buffer.writeln('*No bookmarks or highlights found.*');
    }

    try {
      final directory = await getTemporaryDirectory();
      final fileName =
          '${book.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_annotations.md';
      final file = io.File(p.join(directory.path, fileName));
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      await shareFiles(context,
        ShareParams(
          files: [XFile(file.path)],
          subject: '${book.title} - Annotations',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  /// Shares the book as a `.yomu` file carrying its highlights, notes and
  /// voice notes, so whoever opens it in Yomu sees them on the same book.
  Future<void> _shareWithAnnotations(Book book) =>
      shareBookWithNotes(context, book);

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

    final sheetController = DraggableScrollableController();
    showAdaptiveSheet(
      context: context,
      side: SheetSide.left,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        Widget sheet(ScrollController? scrollController) => NavigationSheet(
          scrollController: scrollController,
          sheetController: scrollController == null ? null : sheetController,
          readerSettings: settings,
          book: book,
          chapters: _chapters,
          tocChapters: _epubBook?.Chapters ?? [],
          pdfOutline: _pdfOutline,
          tocPdfOutline: _tocPdfOutline,
          currentChapterIndex: _currentChapterIndex,
          currentPdfNode: _currentPdfNode,
          totalPages: _pdfPages,
          focusJump: focusJump,
          onExport: () => _exportToMarkdown(book),
          onShareAnnotated: () => _shareWithAnnotations(book),
          getVocabulary: () =>
              ref.read(libraryProvider.notifier).getVocabularyForBook(book.id!),
          onUpdateHighlight: (h) async {
            await DatabaseService().updateHighlight(h);
            final updatedHighlights =
                await DatabaseService().getHighlightsForBook(book.id!);
            if (mounted) {
              setState(() {
                _highlights = updatedHighlights;
              });
            }
          },
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
          getHighlights: () =>
              DatabaseService().getHighlightsForBook(book.id!),
          highlights: _highlights,
          onHighlightTap: (h) {
            Navigator.pop(context);
            _jumpToHighlight(h);
          },
          hiddenAuthors: _hiddenAuthors,
          onSetAuthorHidden: _setAuthorHidden,
          onWalkThrough: (notes) {
            Navigator.pop(context);
            _startWalkThrough(notes);
          },
          onLookup: _lookupDictionary,
          onDeleteHighlight: (id) async {
            await _deleteHighlight(id);
          },
          onDeleteHighlights: (ids) async {
            final dbService = DatabaseService();
            for (final id in ids) {
              await dbService.deleteHighlight(id);
            }
            if (book.id != null) {
              final highlights = await dbService.getHighlightsForBook(book.id!);
              if (mounted) {
                setState(() => _highlights = highlights);
              }
            }
          },
          onDeleteBookmark: (bookmark) async {
            await ref
                .read(libraryProvider.notifier)
                .deleteBookmark(bookmark.id!);
            await _loadBookmarks();
          },
          onDeleteBookmarks: (bookmarks) async {
            for (final bookmark in bookmarks) {
              await ref
                  .read(libraryProvider.notifier)
                  .deleteBookmark(bookmark.id!);
            }
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

        // In a wide window the sheet is a side panel with nothing to drag.
        if (Breakpoints.isWide(context)) return sheet(null);

        // The sheet follows the finger: scrolling a list up grows it to full
        // height before the list itself scrolls; pulling down shrinks it and,
        // past the smallest size, closes it.
        final media = MediaQuery.of(context);
        final maxSize =
            ((media.size.height - media.padding.top - 8) / media.size.height)
                .clamp(NavigationSheet.initialSize, 1.0);
        return DraggableScrollableSheet(
          controller: sheetController,
          expand: false,
          initialChildSize: NavigationSheet.initialSize,
          minChildSize: NavigationSheet.minSize,
          maxChildSize: maxSize,
          builder: (context, scrollController) => sheet(scrollController),
        );
      },
    ).then((_) {
      sheetController.dispose();
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

  Future<void> _lookupDictionary(String word) async {
    final lookupWord = word.trim().split(RegExp(r'\s+')).first;
    final encoded = Uri.encodeComponent(lookupWord);

    final book = ref.read(currentlyReadingProvider);
    if (book != null) {
      await ref
          .read(libraryProvider.notifier)
          .recordDictionaryLookup(lookupWord, book.id!);
    }

    if (io.Platform.isAndroid) {
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
        return;
      } catch (e) {
        debugPrint('Dictionary intent failed: $e');
      }
    }
    if (io.Platform.isIOS || io.Platform.isMacOS) {
      final dictUri = Uri.parse('x-dictionary:r:$encoded');
      if (await canLaunchUrl(dictUri)) {
        await launchUrl(dictUri);
        return;
      }
    }
    // No system dictionary to hand the word to (Linux, Windows, or the above
    // failed): look it up on the web, as the EPUB page does.
    await launchUrl(
      Uri.parse('https://www.google.com/search?q=define+$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }
}
