part of '../reading_screen.dart';

// Desktop behavior for the reader: a readable text column with page-turn
// gutters, zoom, a highlight menu that follows mouse selection, controls
// that get out of the way, and keyboard control. Kept in its own part so
// the main reader file only needs a few call sites.

/// Widest the EPUB text column grows: a comfortable line length at the
/// default text size.
const double _epubColumnMaxWidth = 760;

/// Widest a PDF page opens at. Wider than this, a page of normal text is
/// larger than it needs to be. Zooming in can go past it.
const double _pdfMaxPageWidth = 960;

/// Text size the reader starts at; ⌘0 goes back to it.
const double _defaultTextSize = 18;

/// How long the reader controls stay up after the pointer stops moving.
const Duration _controlsIdleTimeout = Duration(milliseconds: 2500);

/// One key per reader screen for finding the EPUB chapter's scroll view.
final _epubColumnKeys = Expando<GlobalKey>('epubColumn');

/// Whether each book file could be read, checked once per path.
final _readableChecks = Expando<Map<String, Future<bool>>>('readableChecks');

/// Per-screen state the extension can't hold in fields.
final _controlsHideTimers = Expando<Timer>('controlsHideTimer');
final _lastPointerY = Expando<double>('lastPointerY');
final _pinchStartZoom = Expando<double>('pinchStartZoom');

/// How much a pinch has magnified the EPUB page (1 = the normal column).
final _epubZoom = Expando<double>('epubZoom');

/// Most a pinch magnifies an EPUB page: past filling the window, it keeps
/// enlarging the text within it up to this.
const double _maxEpubZoom = 2.5;

extension _DesktopReader on _ReadingScreenState {
  GlobalKey get _epubColumnKey => _epubColumnKeys[this] ??= GlobalKey();

  bool get _isEpubOpen =>
      ref.read(currentlyReadingProvider)?.filePath.toLowerCase().endsWith(
        '.epub',
      ) ??
      false;

  /// Rebuilds the reader. Extensions can't call the protected `setState`
  /// directly; this is the same call.
  void _refresh() {
    // ignore: invalid_use_of_protected_member
    if (mounted) setState(() {});
  }

  /// Lays the book out for the window. An EPUB sits in a column with
  /// page-turn gutters; a PDF keeps the whole window (so zooming has room)
  /// and opens at a readable page width.
  Widget _readerColumn({
    required bool isEpub,
    required ReaderSettings settings,
    required Widget child,
  }) {
    final book = ref.read(currentlyReadingProvider);
    final laidOut = _layOutBook(isEpub: isEpub, settings: settings, child: child);
    if (!PlatformCaps.isDesktop || book == null) return laidOut;

    // A book whose file macOS no longer lets Yomu read gets a way to find it
    // again, instead of a load error.
    final checks = _readableChecks[this] ??= {};
    return FutureBuilder<bool>(
      future: checks[book.filePath] ??= LibraryFiles.isReadable(book.filePath),
      builder: (context, snapshot) => snapshot.data == false
          ? MissingBookFile(
              fileName: p.basename(book.filePath),
              folder: p.dirname(book.filePath),
              settings: settings,
              onLocate: () => _locateBookFile(book),
            )
          : laidOut,
    );
  }

  /// Asks for the book's file again, repairs the library entry (keeping
  /// progress and notes) and reopens the reader on it.
  Future<void> _locateBookFile(Book book) async {
    final ext = p.extension(book.filePath).replaceFirst('.', '');
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Locate "${book.title}"',
      initialDirectory: p.dirname(book.filePath),
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    final picked = result?.files.single.path;
    if (picked == null || !mounted) return;

    final books = await ref
        .read(libraryProvider.notifier)
        .importFiles([picked]);
    if (!mounted || books.isEmpty) return;

    ref.read(currentlyReadingProvider.notifier).state = books.first;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ReadingScreen()),
    );
  }

  Widget _layOutBook({
    required bool isEpub,
    required ReaderSettings settings,
    required Widget child,
  }) {
    if (!isEpub) {
      // As slides, a page is fitted whole to the window instead.
      if (settings.pdfPageTurn == PageTurn.slide) return child;
      return PdfDesktopFit(
        controller: _pdfController,
        isReady: _isPdfReady,
        maxPageWidth: _pdfMaxPageWidth,
        onFitted: () => _pdfController?.goToPage(
          pageNumber: _pdfCurrentPage + 1,
          anchor: PdfPageAnchor.top,
        ),
        child: child,
      );
    }
    // A pinch magnifies the page into the margins, like zooming a page in
    // Preview or a browser. +/− change the text size instead.
    return ReaderColumn(
      maxWidth: _epubColumnMaxWidth,
      zoom: _epubZoom[this] ?? 1,
      color: settings.textColor,
      onPrevious: () => _turnPage(-1),
      onNext: () => _turnPage(1),
      child: PinchListener(
        onStart: () => _pinchStartZoom[this] = _epubZoom[this] ?? 1,
        onScale: (scale) {
          final start = _pinchStartZoom[this];
          if (start == null) return;
          _epubZoom[this] = (start * scale).clamp(1.0, _maxEpubZoom);
          _refresh();
        },
        child: DesktopSelectionMenu(
          child: KeyedSubtree(key: _epubColumnKey, child: child),
        ),
      ),
    );
  }

  /// Zooms in (1) or out (-1): larger or smaller text in an EPUB, the page
  /// zoom in a PDF.
  void _zoom(int direction) {
    if (_isEpubOpen) {
      _setTextSize(ref.read(readerSettingsProvider).textSize + direction * 2);
      return;
    }
    final controller = _pdfController;
    if (controller == null || !controller.isReady) return;
    direction > 0 ? controller.zoomUp() : controller.zoomDown();
  }

  /// Back to actual size: the default text size and no pinch zoom, or a
  /// PDF's opening page width.
  void _resetZoom() {
    if (_isEpubOpen) {
      _epubZoom[this] = 1;
      _setTextSize(_defaultTextSize);
      _refresh();
      return;
    }
    final controller = _pdfController;
    if (controller == null) return;
    if (_pdfSlides) {
      // The page shown whole is pdfrx's smallest zoom in slide mode.
      if (controller.isReady) {
        controller
            .setZoom(controller.centerPosition, controller.minScale)
            .then(
              (_) => controller.goToPage(
                pageNumber: _pdfCurrentPage + 1,
                anchor: PdfPageAnchor.center,
              ),
            );
      }
      return;
    }
    PdfDesktopFit.fit(controller, _pdfMaxPageWidth);
  }

  void _setTextSize(double size) {
    final settings = ref.read(readerSettingsProvider);
    // setTextSize clamps to the range the display settings offer.
    if (size == settings.textSize) return;
    ref.read(readerSettingsProvider.notifier).setTextSize(size);
  }

  /// On desktop, moving the pointer brings the controls back, and they hide
  /// again once it rests, unless it rests on them or a panel is open.
  void _revealControlsForPointer() {
    _setControlsVisibility(true);
    _controlsHideTimers[this]?.cancel();
    _controlsHideTimers[this] = Timer(_controlsIdleTimeout, () {
      if (!mounted || !Breakpoints.isWide(context)) return;
      final y = _lastPointerY[this];
      final height = MediaQuery.sizeOf(context).height;
      final overControls = y != null && (y < 96 || y > height - 140);
      final busy =
          _isSearching ||
          _isNavigationSheetOpen ||
          _isAudioControlsExpanded ||
          DesktopSelectionMenu.isShown;
      if (overControls || busy) return;
      _setControlsVisibility(false);
    });
  }

  /// Moves one screen back (-1) or forward (1). An EPUB scrolls within the
  /// chapter and moves to the next one at its end; a PDF moves a page.
  void _turnPage(int direction) {
    if (_isEpubOpen) {
      if (_epubPageTurner.isActive) {
        _epubPageTurner.turn(direction);
        _recordInteraction();
        return;
      }
      _scrollEpub(direction, byScreen: true);
    } else {
      _jumpToPdfPage(_pdfCurrentPage + 1 + direction);
    }
  }

  /// Scrolls the visible chapter by a screen (or a few lines). At either end
  /// of the chapter, a screen-sized move goes to the neighboring chapter.
  void _scrollEpub(int direction, {required bool byScreen}) {
    final scrollable = _visibleChapterScrollable();
    if (scrollable == null) return;
    final position = scrollable.position;
    final step = byScreen ? position.viewportDimension * 0.88 : 80.0;
    final atEnd = direction > 0
        ? position.pixels >= position.maxScrollExtent - 1
        : position.pixels <= position.minScrollExtent + 1;

    if (atEnd) {
      if (byScreen) _turnChapter(direction);
      return;
    }
    position.animateTo(
      (position.pixels + step * direction).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _recordInteraction();
  }

  void _turnChapter(int direction) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final target = _currentChapterIndex + direction;
    if (target < 0 || target >= _chapters.length) return;
    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// The scroll view of the chapter on screen. Chapters sit in a vertical
  /// PageView, so this skips the PageView itself and any chapter it keeps
  /// built off screen.
  ScrollableState? _visibleChapterScrollable() {
    final column = _epubColumnKey.currentContext;
    final columnBox = column?.findRenderObject() as RenderBox?;
    if (column == null || columnBox == null || !columnBox.hasSize) return null;
    final center = columnBox.localToGlobal(columnBox.size.center(Offset.zero));

    ScrollableState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        final box = element.findRenderObject() as RenderBox?;
        final isChapter =
            axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
            state.widget.controller is! PageController;
        if (isChapter && box != null && box.hasSize) {
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.contains(center)) {
            found = state;
            return;
          }
        }
      }
      element.visitChildren(visit);
    }

    column.visitChildElements(visit);
    return found;
  }

  void _openSearch() {
    _isSearching = true;
    _setControlsVisibility(true);
    _refresh();
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    _isSearching = false;
    _searchController.clear();
    _searchResults = [];
    _activeSearchQuery = null;
    _refresh();
  }

  /// Leaves the reader. Progress is saved as the route pops (PopScope in
  /// the reader), so it isn't saved here too.
  void _exitReader(Book book) => Navigator.of(context).maybePop();

  /// Keyboard and pointer control for the reader. Keys that edit text are
  /// left alone while a text field (search, notes) has focus.
  Widget _withReaderShortcuts({required Book book, required Widget child}) {
    final meta = io.Platform.isMacOS;
    SingleActivator command(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, meta: meta, control: !meta, shift: shift);

    final reader = RouteShortcuts(
      bindings: {
        // As pages, every arrow turns a page; scrolled, ←/→ change chapter
        // and ↑/↓ scroll a few lines.
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _isEpubOpen && !_epubPageTurner.isActive
            ? _turnChapter(1)
            : _turnPage(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _isEpubOpen && !_epubPageTurner.isActive
            ? _turnChapter(-1)
            : _turnPage(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _isEpubOpen && !_epubPageTurner.isActive
            ? _scrollEpub(1, byScreen: false)
            : _turnPage(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _isEpubOpen && !_epubPageTurner.isActive
            ? _scrollEpub(-1, byScreen: false)
            : _turnPage(-1),
        const SingleActivator(LogicalKeyboardKey.space): () => _turnPage(1),
        const SingleActivator(LogicalKeyboardKey.space, shift: true): () =>
            _turnPage(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _turnPage(1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _turnPage(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (DesktopSelectionMenu.dismiss()) return;
          // A PDF selection (and its menu) goes before the reader does.
          final pdf = _pdfController;
          if (!_isEpubOpen &&
              pdf != null &&
              pdf.isReady &&
              pdf.textSelectionDelegate.hasSelectedText) {
            pdf.textSelectionDelegate.clearTextSelection();
            return;
          }
          _isSearching ? _closeSearch() : _exitReader(book);
        },
        command(LogicalKeyboardKey.equal): () => _zoom(1),
        command(LogicalKeyboardKey.equal, shift: true): () => _zoom(1),
        command(LogicalKeyboardKey.add): () => _zoom(1),
        command(LogicalKeyboardKey.minus): () => _zoom(-1),
        command(LogicalKeyboardKey.digit0): _resetZoom,
        command(LogicalKeyboardKey.keyF): _openSearch,
        command(LogicalKeyboardKey.keyD): () => _toggleBookmark(book),
      },
      child: child,
    );

    // Always present, so resizing across the breakpoint keeps the book.
    final isWide = Breakpoints.isWide(context);
    return ReaderCommandScope(
      commands: ReaderCommands(zoom: _zoom, resetZoom: _resetZoom),
      child: MouseRegion(
        onHover: (event) {
          if (!isWide) return;
          _lastPointerY[this] = event.position.dy;
          _revealControlsForPointer();
        },
        child: reader,
      ),
    );
  }

  /// A desktop toast with a leading accent icon.
  SnackBar _desktopToast(IconData icon, String message) {
    return SnackBar(
      duration: const Duration(seconds: 2),
      content: Row(
        children: [
          Icon(icon, size: 18, color: YomuConstants.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  /// Toasts in the reader rise above the floating controls instead of
  /// covering them.
  Widget _withReaderToastInset(Widget scaffold) {
    final theme = Theme.of(context);
    // Always present, so resizing across the breakpoint keeps the book.
    return Theme(
      data: Breakpoints.isWide(context)
          ? theme.copyWith(
              snackBarTheme: theme.snackBarTheme.copyWith(
                insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 136),
              ),
            )
          : theme,
      child: scaffold,
    );
  }
}
