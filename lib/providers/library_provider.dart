import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../models/highlight_model.dart';
import '../services/database_service.dart';
import '../services/book_service.dart';

enum BookSortBy { title, author, recent }

enum BookStatusFilter { all, unread, reading, finished }

final currentlyReadingProvider = StateProvider<Book?>((ref) => null);

class LibraryState {
  final List<Book> allBooks;
  final List<Book> filteredBooks;
  final String searchQuery;
  final bool isLoading;
  final String selectedAuthor;
  final String selectedGenre;
  final String selectedFolder;
  final BookStatusFilter statusFilter;
  final bool onlyFavorites;
  final String? selectedSeries;
  final String? selectedTag;
  final BookSortBy sortBy;
  final bool sortAscending;
  final int currentStreak;
  final List<int>
  activityData; // Simple list of activity counts for the heatmap
  final Map<String, int> dailyReadingValues; // date -> value (pages/min)
  final int totalXP;
  final int level;
  final int totalPagesRead;
  final int totalMinutesRead;
  final double weeklyGoalValue;
  final String weeklyGoalType; // 'minutes' or 'pages'
  final Set<String> unlockedAchievements;
  final List<Map<String, dynamic>> sessionHistory;
  final List<Highlight> highlights;

  LibraryState({
    required this.allBooks,
    required this.filteredBooks,
    this.searchQuery = '',
    this.isLoading = false,
    this.selectedAuthor = 'All',
    this.selectedGenre = 'All',
    this.selectedFolder = 'All',
    this.statusFilter = BookStatusFilter.all,
    this.onlyFavorites = false,
    this.selectedSeries = 'All',
    this.selectedTag = 'All',
    this.sortBy = BookSortBy.recent,
    this.sortAscending = false,
    this.currentStreak = 0,
    this.activityData = const [],
    this.dailyReadingValues = const {},
    this.totalXP = 0,
    this.level = 1,
    this.totalPagesRead = 0,
    this.totalMinutesRead = 0,
    this.weeklyGoalValue = 300,
    this.weeklyGoalType = 'minutes',
    this.unlockedAchievements = const {},
    this.sessionHistory = const [],
    this.highlights = const [],
  });

  LibraryState copyWith({
    List<Book>? allBooks,
    List<Book>? filteredBooks,
    String? searchQuery,
    bool? isLoading,
    String? selectedAuthor,
    String? selectedGenre,
    String? selectedFolder,
    BookStatusFilter? statusFilter,
    bool? onlyFavorites,
    String? selectedSeries,
    String? selectedTag,
    BookSortBy? sortBy,
    bool? sortAscending,
    int? currentStreak,
    List<int>? activityData,
    Map<String, int>? dailyReadingValues,
    int? totalXP,
    int? level,
    int? totalPagesRead,
    int? totalMinutesRead,
    double? weeklyGoalValue,
    String? weeklyGoalType,
    Set<String>? unlockedAchievements,
    List<Map<String, dynamic>>? sessionHistory,
    List<Highlight>? highlights,
  }) {
    return LibraryState(
      allBooks: allBooks ?? this.allBooks,
      filteredBooks: filteredBooks ?? this.filteredBooks,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      selectedAuthor: selectedAuthor ?? this.selectedAuthor,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      statusFilter: statusFilter ?? this.statusFilter,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      selectedSeries: selectedSeries ?? this.selectedSeries,
      selectedTag: selectedTag ?? this.selectedTag,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      currentStreak: currentStreak ?? this.currentStreak,
      activityData: activityData ?? this.activityData,
      dailyReadingValues: dailyReadingValues ?? this.dailyReadingValues,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      totalMinutesRead: totalMinutesRead ?? this.totalMinutesRead,
      weeklyGoalValue: weeklyGoalValue ?? this.weeklyGoalValue,
      weeklyGoalType: weeklyGoalType ?? this.weeklyGoalType,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      highlights: highlights ?? this.highlights,
    );
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  return LibraryNotifier(ref);
});

class LibraryNotifier extends StateNotifier<LibraryState> {
  final Ref _ref;
  final DatabaseService _dbService = DatabaseService();
  final BookService _bookService = BookService();

  LibraryNotifier(this._ref)
    : super(
        LibraryState(
          allBooks: [],
          filteredBooks: [],
          searchQuery: '',
          isLoading: true,
          selectedAuthor: 'All',
          selectedGenre: 'All',
          selectedFolder: 'All',
          statusFilter: BookStatusFilter.all,
          onlyFavorites: false,
          selectedSeries: 'All',
          selectedTag: 'All',
          sortBy: BookSortBy.recent,
          sortAscending: false,
          highlights: [],
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    await _loadGoal();
    await loadBooks();
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble('weeklyGoalValue') ?? 300.0;
    final type = prefs.getString('weeklyGoalType') ?? 'minutes';
    state = state.copyWith(weeklyGoalValue: value, weeklyGoalType: type);
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true);
    final books = await _dbService.getBooks();
    final sessions = await _dbService.getReadingSessions();

    final streak = _calculateStreak(sessions);
    final activity = _calculateActivity(sessions, state.weeklyGoalType);
    final stats = _calculateStats(sessions, books);
    final highlights = await _dbService.getAllHighlights();

    final visibleBooks = books.where((b) => !b.isDeleted).toList();

    state = state.copyWith(
      allBooks: visibleBooks,
      filteredBooks: _applyFilters(visibleBooks, state),
      isLoading: false,
      currentStreak: streak,
      activityData: activity.levels,
      dailyReadingValues: activity.values,
      totalXP: stats.xp,
      level: stats.level,
      totalPagesRead: stats.totalPages,
      totalMinutesRead: stats.totalMinutes,
      unlockedAchievements: stats.achievements,
      sessionHistory: sessions,
      highlights: highlights,
    );
  }

  _UserStats _calculateStats(
    List<Map<String, dynamic>> sessions,
    List<Book> books,
  ) {
    int totalPages = 0;
    int totalMinutes = 0;
    for (var s in sessions) {
      totalPages += (s['pagesRead'] as int? ?? 0);
      totalMinutes += (s['durationMinutes'] as int? ?? 0);
    }

    final finishedBooks = books.where((b) => b.progress >= 0.99).length;
    final streak = _calculateStreak(sessions);

    // XP calculation: 10 per page, 5 per minute
    int xp = (totalPages * 10) + (totalMinutes * 5);

    // Level calculation based on user requirements
    int level = 1;
    if (finishedBooks >= 50) {
      level = 50;
    } else if (totalPages >= 10000) {
      level = 40;
    } else if (finishedBooks >= 10) {
      level = 20;
    } else if (streak >= 14) {
      level = 10;
    } else if (finishedBooks >= 3) {
      level = 5;
    }

    // Achievements check
    final achievements = <String>{};
    if (finishedBooks >= 1) achievements.add('the_first_page');
    if (streak >= 7) achievements.add('seven_day_streak');
    if (streak >= 30) achievements.add('unstoppable');
    if (totalPages >= 1000) achievements.add('bookworm');
    if (finishedBooks >= 10) achievements.add('yomibito');
    if (finishedBooks >= 50) achievements.add('sensei');

    // Time-based achievements (would need real session timestamps)
    // For now, placeholders or simple checks
    for (var s in sessions) {
      if ((s['pagesRead'] as int? ?? 0) >= 100) {
        achievements.add('century_club');
      }
    }

    return _UserStats(
      xp: xp,
      level: level,
      totalPages: totalPages,
      totalMinutes: totalMinutes,
      achievements: achievements,
    );
  }

  int _calculateStreak(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;

    final readDates = sessions
        .map((s) => s['date'] as String)
        .toSet()
        .map((d) => DateTime.parse(d))
        .toList();

    if (readDates.isEmpty) return 0;

    readDates.sort((a, b) => b.compareTo(a)); // Newest first

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final yesterdayNormalized = todayNormalized.subtract(
      const Duration(days: 1),
    );

    if (!readDates.contains(todayNormalized) &&
        !readDates.contains(yesterdayNormalized)) {
      return 0;
    }

    int streak = 0;
    DateTime currentCheck = readDates.contains(todayNormalized)
        ? todayNormalized
        : yesterdayNormalized;

    while (readDates.contains(currentCheck)) {
      streak++;
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }

    return streak;
  }

  _ActivityData _calculateActivity(
    List<Map<String, dynamic>> sessions,
    String type,
  ) {
    final values = <String, int>{};
    for (var session in sessions) {
      final date = session['date'] as String;
      final val =
          (type == 'pages' ? session['pagesRead'] : session['durationMinutes'])
              as int;
      values[date] = (values[date] ?? 0) + val;
    }

    // Still need levels for backward compat or simple graph, but graph will now use values
    final activity = List<int>.filled(31, 0);
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    for (var entry in values.entries) {
      final sessionDate = DateTime.parse(entry.key);
      final difference = todayNormalized.difference(sessionDate).inDays;
      if (difference >= 0 && difference < 31) {
        final val = entry.value;
        int level = 0;
        if (type == 'pages') {
          if (val > 50) {
            level = 4;
          } else if (val > 20) {
            level = 3;
          } else if (val > 10) {
            level = 2;
          } else if (val > 0) {
            level = 1;
          }
        } else {
          if (val > 60) {
            level = 4;
          } else if (val > 30) {
            level = 3;
          } else if (val > 15) {
            level = 2;
          } else if (val > 0) {
            level = 1;
          }
        }
        activity[30 - difference] = level;
      }
    }
    return _ActivityData(levels: activity, values: values);
  }

  void setSearchQuery(String query) {
    final newState = state.copyWith(searchQuery: query);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setSortBy(BookSortBy sortBy) {
    final newState = state.copyWith(sortBy: sortBy);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void toggleSortOrder() {
    final newState = state.copyWith(sortAscending: !state.sortAscending);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setStatusFilter(BookStatusFilter filter) {
    // Toggle: if clicking already selected tab, clear it
    final targetFilter = state.statusFilter == filter
        ? BookStatusFilter.all
        : filter;
    final newState = state.copyWith(statusFilter: targetFilter);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void toggleFavoriteOnly() {
    final newState = state.copyWith(onlyFavorites: !state.onlyFavorites);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setAuthorFilter(String author) {
    // Toggle: if clicking already selected author, set to 'All'
    final targetAuthor = state.selectedAuthor == author ? 'All' : author;
    final newState = state.copyWith(selectedAuthor: targetAuthor);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setGenreFilter(String genre) {
    // Toggle: if clicking already selected genre, set to 'All'
    final targetGenre = state.selectedGenre == genre ? 'All' : genre;
    final newState = state.copyWith(selectedGenre: targetGenre);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setFolderFilter(String folder) {
    final newState = state.copyWith(selectedFolder: folder);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setSeriesFilter(String series) {
    final newState = state.copyWith(selectedSeries: series);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setTagFilter(String tag) {
    final newState = state.copyWith(selectedTag: tag);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  List<Book> _applyFilters(List<Book> books, LibraryState currentState) {
    List<Book> filtered = List.from(books);

    // 1. Search filter
    if (currentState.searchQuery.isNotEmpty) {
      final query = currentState.searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (b) =>
                b.title.toLowerCase().contains(query) ||
                b.author.toLowerCase().contains(query),
          )
          .toList();
    }

    // 2. Author filter
    if (currentState.selectedAuthor != 'All') {
      filtered = filtered
          .where((b) => b.author == currentState.selectedAuthor)
          .toList();
    }

    // 2.1 Genre filter
    if (currentState.selectedGenre != 'All') {
      filtered = filtered
          .where((b) => b.genre == currentState.selectedGenre)
          .toList();
    }

    // 3. Status filter
    if (currentState.statusFilter != BookStatusFilter.all) {
      filtered = filtered.where((b) {
        switch (currentState.statusFilter) {
          case BookStatusFilter.unread:
            return b.progress == 0;
          case BookStatusFilter.reading:
            return b.progress > 0 && b.progress < 0.95;
          case BookStatusFilter.finished:
            return b.progress >= 0.95;
          default:
            return true;
        }
      }).toList();
    }

    // 4. Favorites filter
    if (currentState.onlyFavorites) {
      filtered = filtered.where((b) => b.isFavorite).toList();
    }

    // 5. Folder filter
    if (currentState.selectedFolder != 'All') {
      filtered = filtered
          .where((b) => b.folderPath == currentState.selectedFolder)
          .toList();
    }

    // 6. Series filter
    if (currentState.selectedSeries != 'All') {
      filtered = filtered
          .where((b) => b.series == currentState.selectedSeries)
          .toList();
    }

    // 7. Tags filter
    if (currentState.selectedTag != 'All') {
      filtered = filtered
          .where(
            (b) =>
                b.tags != null &&
                b.tags!.split(',').contains(currentState.selectedTag),
          )
          .toList();
    }

    // 8. Sorting
    filtered.sort((a, b) {
      int cmp;
      switch (currentState.sortBy) {
        case BookSortBy.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case BookSortBy.author:
          cmp = a.author.toLowerCase().compareTo(b.author.toLowerCase());
          break;
        case BookSortBy.recent:
          cmp = a.addedAt.compareTo(b.addedAt);
          break;
      }
      return currentState.sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  Future<List<Book>> importFiles(List<String> paths) async {
    state = state.copyWith(isLoading: true);
    final List<Book> result = [];
    final existing = await _dbService.getBooks();

    for (var path in paths) {
      final file = io.File(path);
      final book = await _bookService.processFile(file);
      if (book != null) {
        final duplicate = existing.firstWhereOrNull(
          (b) =>
              b.filePath == book.filePath ||
              (book.contentHash != null && b.contentHash == book.contentHash),
        );

        if (duplicate == null) {
          final bookToInsert = book.copyWith(folderPath: p.dirname(path));
          final id = await _dbService.insertBook(bookToInsert);
          result.add(bookToInsert.copyWith(id: id));
        } else if (duplicate.isDeleted) {
          debugPrint('Restoring soft-deleted book: ${duplicate.title}');
          final bookToUpdate = duplicate.copyWith(
            isDeleted: false,
            folderPath: p.dirname(path),
            filePath: path, // Path might have changed
          );
          await _dbService.updateBook(bookToUpdate);
          await _dbService.restoreBook(duplicate.id!);
          result.add(bookToUpdate);
        } else {
          debugPrint('Duplicate book found, skipping: ${book.title}');
          result.add(duplicate);
        }
      }
    }
    await loadBooks();
    return result;
  }

  Future<void> updateBookProgress(
    int bookId,
    double progress, {
    int? pagesRead,
    int? durationMinutes,
    int? currentPage,
    int? totalPages,
    String? lastPosition,
    bool estimateReadingTime = true,
  }) async {
    final book = state.allBooks.firstWhereOrNull((b) => b.id == bookId);
    if (book == null) return;
    final oldProgress = book.progress;

    // Calculate estimated reading time if we have total pages
    int estimatedMinutes = 0;
    if (totalPages != null && currentPage != null && totalPages > 0) {
      final pagesRemaining = totalPages - currentPage;
      if (pagesRemaining > 0) {
        final readingSpeed = await _getReadingSpeed();
        estimatedMinutes = (pagesRemaining / readingSpeed).ceil();
      }
    }

    final updatedBook = book.copyWith(
      progress: progress,
      lastReadAt: DateTime.now(),
      currentPage: currentPage ?? book.currentPage,
      totalPages: totalPages ?? book.totalPages,
      estimatedReadingMinutes: estimatedMinutes > 0
          ? estimatedMinutes
          : book.estimatedReadingMinutes,
      lastPosition: lastPosition ?? book.lastPosition,
    );
    await _dbService.updateBook(updatedBook);

    // Record session
    int finalPages = pagesRead ?? 0;
    int finalMinutes = durationMinutes ?? 0;

    // 1. Estimate Pages if not provided, based on progress
    // We always want to track pages read if progress moved, even if we don't estimate time.
    if (finalPages == 0 && progress > oldProgress) {
      final effectiveTotalPages = book.totalPages > 0 ? book.totalPages : 300;
      finalPages = ((progress - oldProgress) * effectiveTotalPages)
          .round()
          .clamp(1, 100);
    }

    // 2. Estimate Minutes ONLY if allowed and not provided
    if (estimateReadingTime && finalMinutes == 0 && finalPages > 0) {
      // Estimate minutes based on a standard reading speed (e.g., 200 words/min -> ~2 mins per page)
      // but make it distinct from pages.
      finalMinutes = (finalPages * 1.2).ceil().clamp(1, 60);
    }

    if (finalPages > 0 || finalMinutes > 0) {
      await _dbService.insertReadingSession(bookId, finalPages, finalMinutes);
    }

    _updateStateAndSync(updatedBook);

    // Refresh stats
    final sessions = await _dbService.getReadingSessions();
    final activity = _calculateActivity(sessions, state.weeklyGoalType);
    final stats = _calculateStats(sessions, state.allBooks);

    state = state.copyWith(
      currentStreak: _calculateStreak(sessions),
      activityData: activity.levels,
      dailyReadingValues: activity.values,
      totalXP: stats.xp,
      level: stats.level,
      totalPagesRead: stats.totalPages,
      totalMinutesRead: stats.totalMinutes,
      unlockedAchievements: stats.achievements,
      sessionHistory: sessions,
    );
  }

  /// Calculate user's average reading speed in pages per minute
  Future<double> _getReadingSpeed() async {
    final sessions = await _dbService.getReadingSessions();

    if (sessions.isEmpty) {
      return 1.0; // Default: 1 page per minute
    }

    int totalPages = 0;
    int totalMinutes = 0;

    for (var session in sessions) {
      totalPages += (session['pagesRead'] as int? ?? 0);
      totalMinutes += (session['durationMinutes'] as int? ?? 0);
    }

    if (totalMinutes == 0) {
      return 1.0;
    }

    return totalPages / totalMinutes;
  }

  Future<void> scanFolder() async {
    state = state.copyWith(isLoading: true);
    final newBooks = await _bookService.scanDirectory();
    if (newBooks.isNotEmpty) {
      await loadBooks();
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markBookAsOpened(Book book) async {
    if (book.lastReadAt == null) {
      final updatedBook = book.copyWith(lastReadAt: DateTime.now());
      await _dbService.updateBook(updatedBook);

      // Update local state to remove "NEW" tag instantly
      state = state.copyWith(
        allBooks: state.allBooks
            .map((b) => b.id == updatedBook.id ? updatedBook : b)
            .toList(),
        filteredBooks: state.filteredBooks
            .map((b) => b.id == updatedBook.id ? updatedBook : b)
            .toList(),
      );
    }
  }

  Future<void> setWeeklyGoal(double value, String type) async {
    state = state.copyWith(weeklyGoalValue: value, weeklyGoalType: type);

    // Persist goal
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weeklyGoalValue', value);
    await prefs.setString('weeklyGoalType', type);

    // Re-calculate activity data for the new unit
    final sessions = await _dbService.getReadingSessions();
    final activity = _calculateActivity(sessions, type);

    state = state.copyWith(
      activityData: activity.levels,
      dailyReadingValues: activity.values,
    );
  }

  Future<void> deleteBook(int id, {bool deleteHistory = false}) async {
    if (deleteHistory) {
      await _dbService.hardDeleteBook(id);
    } else {
      await _dbService.softDeleteBook(id);
    }
    await loadBooks();
  }

  Future<void> toggleBookFavorite(Book book) async {
    final updatedBook = book.copyWith(isFavorite: !book.isFavorite);
    await _dbService.updateBook(updatedBook);
    await loadBooks();
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedAuthor: 'All',
      selectedGenre: 'All',
      selectedFolder: 'All',
      statusFilter: BookStatusFilter.all,
      onlyFavorites: false,
      selectedSeries: 'All',
      selectedTag: 'All',
      sortBy: BookSortBy.recent,
      sortAscending: false,
    );
    state = state.copyWith(filteredBooks: _applyFilters(state.allBooks, state));
  }

  Future<void> updateBookAudio(
    int bookId, {
    String? audioPath,
    int? audioLastPosition,
  }) async {
    final book = state.allBooks.firstWhereOrNull((b) => b.id == bookId);
    if (book == null) return;

    final updatedBook = book.copyWith(
      audioPath: audioPath, // Allow setting to null or a new path
      audioLastPosition: audioLastPosition ?? book.audioLastPosition,
    );
    await _dbService.updateBook(updatedBook);

    _updateStateAndSync(updatedBook);
  }

  // Bookmark specialized methods
  Future<void> addBookmark(Bookmark bookmark) async {
    await _dbService.insertBookmark(bookmark);
  }

  Future<List<Bookmark>> getBookmarks(int bookId) async {
    return await _dbService.getBookmarks(bookId);
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    await _dbService.deleteBookmark(bookmarkId);
  }

  Future<void> addHighlight(Highlight highlight) async {
    await _dbService.insertHighlight(highlight);
    await loadBooks(); // Refresh all state
  }

  Future<List<Highlight>> getHighlights(int bookId) async {
    return await _dbService.getHighlights(bookId);
  }

  Future<void> updateHighlight(Highlight highlight) async {
    await _dbService.updateHighlight(highlight);
    await loadBooks();
  }

  Future<void> deleteHighlight(int highlightId) async {
    await _dbService.deleteHighlight(highlightId);
    await loadBooks();
  }

  void _updateStateAndSync(Book updatedBook) {
    // Update state
    state = state.copyWith(
      allBooks: state.allBooks
          .map((b) => b.id == updatedBook.id ? updatedBook : b)
          .toList(),
      filteredBooks: state.filteredBooks
          .map((b) => b.id == updatedBook.id ? updatedBook : b)
          .toList(),
    );

    // Sync current reader
    final currentBook = _ref.read(currentlyReadingProvider);
    if (currentBook?.id == updatedBook.id) {
      _ref.read(currentlyReadingProvider.notifier).state = updatedBook;
    }
  }
}

class _UserStats {
  final int xp;
  final int level;
  final int totalPages;
  final int totalMinutes;
  final Set<String> achievements;

  _UserStats({
    required this.xp,
    required this.level,
    required this.totalPages,
    required this.totalMinutes,
    required this.achievements,
  });
}

class _ActivityData {
  final List<int> levels;
  final Map<String, int> values;

  _ActivityData({required this.levels, required this.values});
}
