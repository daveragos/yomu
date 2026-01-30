import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_view/epub_view.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
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
  bool _isPdfReady = false;
  String _pdfErrorMessage = '';
  DateTime _lastSyncTime = DateTime.now();
  int _lastSyncPage = 0;
  bool _initialized = false;
  int _accumulatedSeconds = 0;
  Timer? _heartbeatTimer;
  Timer? _debounceTimer; // For debouncing progress updates
  DateTime _lastInteractionTime = DateTime.now();
  PdfViewerController? _pdfController;
  final Duration _idlenessTimeout = const Duration(minutes: 2);

  @override
  void dispose() {
    _epubController?.dispose();
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();
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
    _epubController = EpubController(
      document: EpubDocument.openFile(File(book.filePath)),
      epubCfi: book.lastPosition,
    );
    _startHeartbeat(book);
  }

  void _startHeartbeat(Book book) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isIdle()) return; // Don't track time if idle

      _accumulatedSeconds++;
      if (_accumulatedSeconds >= 60) {
        _accumulatedSeconds = 0;
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book,
              book.progress,
              pagesRead: 0,
              durationMinutes: 1,
            );
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

      // Update book with total pages on first load
      ref
          .read(libraryProvider.notifier)
          .updateBookProgress(
            book,
            book.progress,
            pagesRead: 0,
            durationMinutes: 0,
            currentPage: page,
            totalPages: total,
          );
      return;
    }

    // Update local state immediately for smooth UI
    setState(() {
      _pdfCurrentPage = page;
      _pdfPages = total;
    });

    // Debounce the progress sync to reduce database writes and rebuilds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final int pagesRead = (page - _lastSyncPage).clamp(0, 1000);
      final int duration = DateTime.now().difference(_lastSyncTime).inMinutes;
      final progress = page / (total - 1);

      // Only sync if significant (e.g., page moved or some time passed)
      if (pagesRead > 0 || duration >= 1) {
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book,
              progress,
              pagesRead: pagesRead,
              durationMinutes: duration,
              currentPage: page,
              totalPages: total,
            );
        _lastSyncPage = page;
        _lastSyncTime = DateTime.now();
      } else {
        // Just update progress in DB without a full session if it's just a jump
        ref
            .read(libraryProvider.notifier)
            .updateBookProgress(
              book,
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
    if (!_initialized) return;

    // Cancel any pending debounced updates
    _debounceTimer?.cancel();
    _heartbeatTimer?.cancel();

    final now = DateTime.now();
    int duration = now.difference(_lastSyncTime).inMinutes;

    // Round up if they read for more than 30 seconds in the last partial minute
    if (_accumulatedSeconds >= 30) {
      duration += 1;
    }

    int pagesRead = 0;
    double progress = book.progress;
    int currentPage = book.currentPage;
    int totalPages = book.totalPages;

    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      if (_pdfPages > 0) {
        pagesRead = (_pdfCurrentPage - _lastSyncPage).clamp(0, 1000);
        progress = _pdfCurrentPage / (_pdfPages - 1).clamp(1, 1000000);
        currentPage = _pdfCurrentPage;
        totalPages = _pdfPages;
      }
    }

    if (pagesRead > 0 || duration > 0) {
      ref
          .read(libraryProvider.notifier)
          .updateBookProgress(
            book,
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

    if (book == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.1),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a book from your library to start reading',
                style: TextStyle(color: Colors.white54),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            _syncFinalProgress(book);
            ref.read(selectedIndexProvider.notifier).state = 1; // Library
          },
        ),
        title: Column(
          children: [
            Text(
              book.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              book.author,
              style: TextStyle(
                color: YomuConstants.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmark_border_rounded,
              color: Colors.white,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.text_fields_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _syncFinalProgress(book);
          }
        },
        child: Stack(
          children: [
            if (isEpub)
              EpubView(
                controller: _epubController!,
                onDocumentLoaded: (document) {
                  if (!_initialized) {
                    _lastSyncTime = DateTime.now();
                    _initialized = true;
                  }
                },
                onChapterChanged: (value) {
                  _recordInteraction();
                  final now = DateTime.now();
                  final duration = now.difference(_lastSyncTime).inMinutes;
                  final location = _epubController?.generateEpubCfi();

                  ref
                      .read(libraryProvider.notifier)
                      .updateBookProgress(
                        book,
                        book.progress,
                        pagesRead: 0,
                        durationMinutes: duration > 0 ? duration : 0,
                        lastPosition: location,
                      );
                  _lastSyncTime = now;
                },
                builders: EpubViewBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  chapterDividerBuilder: (_) => const Divider(),
                ),
              )
            else
              Listener(
                onPointerMove: (_) => _recordInteraction(),
                onPointerDown: (_) => _recordInteraction(),
                child: PdfViewer.file(
                  book.filePath,
                  controller: _pdfController ??= PdfViewerController(),
                  params: PdfViewerParams(
                    onViewerReady: (document, controller) {
                      setState(() {
                        _pdfPages = document.pages.length;
                        _isPdfReady = true;
                      });
                      if (!_initialized) {
                        final initialPage = (book.progress * (_pdfPages - 1))
                            .toInt();
                        controller.goToPage(pageNumber: initialPage + 1);
                        _startHeartbeat(book);
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
            if (_pdfErrorMessage.isNotEmpty)
              Center(child: Text(_pdfErrorMessage))
            else if (!isEpub && !_isPdfReady)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildReaderControls(context, book),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderControls(BuildContext context, Book book) {
    String progressText = '';
    if (book.filePath.toLowerCase().endsWith('.pdf')) {
      progressText = 'Page ${_pdfCurrentPage + 1} of $_pdfPages';
    } else {
      progressText = '${(book.progress * 100).toStringAsFixed(0)}% Read';
    }

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      borderRadius: 0,
      blur: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  // TODO: Control pagination
                },
              ),
              Text(progressText),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                onPressed: () {
                  // TODO: Control pagination
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
