import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../core/constants.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../services/database_service.dart';
import '../services/book_service.dart';
import '../models/quest_model.dart';
import '../services/notification_service.dart';

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
  final int totalXP;
  final int level;
  final int totalPagesRead;
  final int totalMinutesRead;
  final double weeklyPageGoal;
  final double weeklyMinuteGoal;
  final double weeklyXPGoal;
  final String weeklyGoalType; // Kept for backward compat with ActivityGraph
  final Map<String, int> dailyPages;
  final Map<String, int> dailyMinutes;
  final Map<String, int> dailyXP;
  final Set<String> unlockedAchievements;
  final List<Map<String, dynamic>> sessionHistory;
  final List<DailyQuest> dailyQuests;
  final bool isStreakActiveToday;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;

  final int lastCelebratedLevel;

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
    this.totalXP = 0,
    this.level = 1,
    this.lastCelebratedLevel = 1,
    this.totalPagesRead = 0,
    this.totalMinutesRead = 0,
    this.weeklyPageGoal = 100,
    this.weeklyMinuteGoal = 0,
    this.weeklyXPGoal = 0,
    this.weeklyGoalType = 'pages',
    this.dailyPages = const {},
    this.dailyMinutes = const {},
    this.dailyXP = const {},
    this.unlockedAchievements = const {},
    this.sessionHistory = const [],
    this.dailyQuests = const [],
    this.isStreakActiveToday = false,
    this.notificationsEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  double get weeklyGoalValue {
    if (weeklyGoalType == 'pages') return weeklyPageGoal;
    if (weeklyGoalType == 'minutes') return weeklyMinuteGoal;
    return weeklyXPGoal;
  }

  Map<String, int> get dailyReadingValues {
    if (weeklyGoalType == 'pages') return dailyPages;
    if (weeklyGoalType == 'minutes') return dailyMinutes;
    return dailyXP;
  }

  List<int> get activityData {
    final values = dailyReadingValues;
    final activity = List<int>.filled(31, 0);
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    for (var entry in values.entries) {
      final sessionDate = DateTime.parse(entry.key);
      final difference = todayNormalized.difference(sessionDate).inDays;
      if (difference >= 0 && difference < 31) {
        final val = entry.value;
        int level = 0;
        final double goal = weeklyGoalValue / 7.0;
        if (val >= goal * 2.0) {
          level = 4;
        } else if (val >= goal) {
          level = 3;
        } else if (val >= goal * 0.5) {
          level = 2;
        } else if (val > 0) {
          level = 1;
        }
        activity[30 - difference] = level;
      }
    }
    return activity;
  }

  String get rankName => YomuConstants.getRankForLevel(level).name;

  int get weeklyPagesRead => _sumForCurrentWeek(dailyPages);
  int get weeklyMinutesRead => _sumForCurrentWeek(dailyMinutes);
  int get weeklyXPRead => _sumForCurrentWeek(dailyXP);

  bool get dailyGoalReached {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final progress = dailyReadingValues[today] ?? 0;
    return progress >= (weeklyGoalValue / 7.0);
  }

  int _sumForCurrentWeek(Map<String, int> values) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    int sum = 0;
    values.forEach((dateStr, val) {
      final date = DateTime.parse(dateStr);
      if (!date.isBefore(monday)) {
        sum += val;
      }
    });
    return sum;
  }

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
    int? totalXP,
    int? level,
    int? lastCelebratedLevel,
    int? totalPagesRead,
    int? totalMinutesRead,
    double? weeklyPageGoal,
    double? weeklyMinuteGoal,
    double? weeklyXPGoal,
    String? weeklyGoalType,
    Map<String, int>? dailyPages,
    Map<String, int>? dailyMinutes,
    Map<String, int>? dailyXP,
    Set<String>? unlockedAchievements,
    List<Map<String, dynamic>>? sessionHistory,
    List<DailyQuest>? dailyQuests,
    bool? isStreakActiveToday,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
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
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      lastCelebratedLevel: lastCelebratedLevel ?? this.lastCelebratedLevel,
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      totalMinutesRead: totalMinutesRead ?? this.totalMinutesRead,
      weeklyPageGoal: weeklyPageGoal ?? this.weeklyPageGoal,
      weeklyMinuteGoal: weeklyMinuteGoal ?? this.weeklyMinuteGoal,
      weeklyXPGoal: weeklyXPGoal ?? this.weeklyXPGoal,
      weeklyGoalType: weeklyGoalType ?? this.weeklyGoalType,
      dailyPages: dailyPages ?? this.dailyPages,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      dailyXP: dailyXP ?? this.dailyXP,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      dailyQuests: dailyQuests ?? this.dailyQuests,
      isStreakActiveToday: isStreakActiveToday ?? this.isStreakActiveToday,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
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
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    await _loadGoal();
    await loadBooks();
    await _loadQuests();

    if (state.notificationsEnabled) {
      await NotificationService().scheduleDailyReminder(
        id: 999,
        title: 'Time to read!',
        body: 'Keep your streak alive and dive back into your books.',
        hour: state.reminderHour,
        minute: state.reminderMinute,
      );
      await NotificationService().scheduleWeekendBoostNotifications();
    }
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final pageGoal = prefs.getDouble('weeklyPageGoal');
    final minuteGoal = prefs.getDouble('weeklyMinuteGoal') ?? 0.0;
    final xpGoal = prefs.getDouble('weeklyXPGoal') ?? 0.0;

    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    final reminderHour = prefs.getInt('reminderHour') ?? 20;
    final reminderMinute = prefs.getInt('reminderMinute') ?? 0;

    // Migration
    double finalPageGoal = pageGoal ?? 100.0;
    String finalType = prefs.getString('weeklyGoalType') ?? 'pages';

    if (pageGoal == null) {
      // Check for old value
      final oldVal = prefs.getDouble('weeklyGoalValue');
      if (oldVal != null) {
        if (finalType == 'pages') {
          finalPageGoal = oldVal;
        }
        // If it was minutes, we migrate that too if minuteGoal is still 0
        if (finalType == 'minutes' && minuteGoal == 0) {
          // Temporarily set it, though we now have dedicated fields
          await prefs.setDouble('weeklyMinuteGoal', oldVal);
        }
      }
    }

    final celebrated = prefs.getInt('lastCelebratedLevel') ?? 1;
    state = state.copyWith(
      weeklyPageGoal: finalPageGoal,
      weeklyMinuteGoal: minuteGoal,
      weeklyXPGoal: xpGoal,
      weeklyGoalType: finalType,
      lastCelebratedLevel: celebrated,
      notificationsEnabled: notificationsEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
  }

  Future<void> updateNotificationSettings({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) {
      await prefs.setBool('notificationsEnabled', enabled);
    }
    if (hour != null) {
      await prefs.setInt('reminderHour', hour);
    }
    if (minute != null) {
      await prefs.setInt('reminderMinute', minute);
    }

    state = state.copyWith(
      notificationsEnabled: enabled ?? state.notificationsEnabled,
      reminderHour: hour ?? state.reminderHour,
      reminderMinute: minute ?? state.reminderMinute,
    );

    if (state.notificationsEnabled) {
      await NotificationService().scheduleDailyReminder(
        id: 999,
        title: 'Time to read!',
        body: 'Keep your streak alive and dive back into your books.',
        hour: state.reminderHour,
        minute: state.reminderMinute,
      );
      await NotificationService().scheduleWeekendBoostNotifications();
    } else {
      await NotificationService().cancel(id: 999);
      await NotificationService().cancel(id: 1000);
      await NotificationService().cancel(id: 1001);
    }
  }

  Future<void> markLevelCelebrated(int level) async {
    state = state.copyWith(lastCelebratedLevel: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastCelebratedLevel', level);
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true);
    final books = await _dbService.getBooks();
    final sessions = await _dbService.getReadingSessions();
    final questXp = await _dbService.getTotalQuestXP();

    final streak = _calculateStreak(sessions);
    final activity = _calculateDetailedActivity(sessions, books);
    final stats = _calculateStats(sessions, books, questXp);
    final visibleBooks = books.where((b) => !b.isDeleted).toList();

    state = state.copyWith(
      allBooks: visibleBooks,
      filteredBooks: _applyFilters(visibleBooks, state),
      isLoading: false,
      currentStreak: streak,
      isStreakActiveToday: _isStreakActiveToday(sessions),
      dailyPages: activity.pages,
      dailyMinutes: activity.minutes,
      dailyXP: activity.xp,
      totalXP: stats.xp,
      level: stats.level,
      totalPagesRead: stats.totalPages,
      totalMinutesRead: stats.totalMinutes,
      unlockedAchievements: stats.achievements,
      sessionHistory: sessions,
    );

    await _loadQuests();
  }

  bool _isStreakActiveToday(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return sessions.any((s) => s['date'] == today);
  }

  Future<void> _loadQuests() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final questMaps = await _dbService.getQuestsForDate(today);

    if (questMaps.isEmpty) {
      final newQuests = _generateDailyQuests(today);
      for (var q in newQuests) {
        await _dbService.insertQuest(q.toMap());
      }
      state = state.copyWith(dailyQuests: newQuests);
    } else {
      state = state.copyWith(
        dailyQuests: questMaps.map((m) => DailyQuest.fromMap(m)).toList(),
      );
    }
  }

  List<DailyQuest> _generateDailyQuests(String dateStr) {
    final date = DateTime.parse(dateStr);
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final multiplier = isWeekend ? 2 : 1;

    return [
      DailyQuest(
        id: 'pages_$dateStr',
        title: 'Daily Reader',
        description: 'Read 5 pages today.',
        type: QuestType.pages,
        targetValue: 5,
        xpReward: 100 * multiplier,
        date: date,
      ),
      DailyQuest(
        id: 'minutes_$dateStr',
        title: 'Deep Focus',
        description: 'Read for 15 minutes.',
        type: QuestType.minutes,
        targetValue: 15,
        xpReward: 150 * multiplier,
        date: date,
      ),
      DailyQuest(
        id: 'early_$dateStr',
        title: 'Early Bird',
        description: 'Read before 9:00 AM.',
        type: QuestType.earlyBird,
        targetValue: 1,
        xpReward: 200 * multiplier,
        date: date,
      ),
    ];
  }

  _UserStats _calculateStats(
    List<Map<String, dynamic>> sessions,
    List<Book> books,
    int questXp,
  ) {
    int totalPages = 0;
    int totalMinutes = 0;
    for (var s in sessions) {
      totalPages += (s['pagesRead'] as int? ?? 0);
      totalMinutes += (s['durationMinutes'] as int? ?? 0);
    }

    final finishedBooks = books.where((b) => b.progress >= 0.99).length;
    final streak = _calculateStreak(sessions);

    // XP calculation:
    // PDF: 10 per page, 5 per minute
    // EPUB: 40 per chapter (since epubs "pages" are chapters), 5 per minute
    int xp = 0;
    for (var s in sessions) {
      final p = (s['pagesRead'] as int? ?? 0);
      final m = (s['durationMinutes'] as int? ?? 0);

      // Boost calculation
      double multiplier = 1.0;
      final sessionTimestamp = s['timestamp'] != null
          ? DateTime.tryParse(s['timestamp']) ?? DateTime.parse(s['date'])
          : DateTime.parse(s['date']);

      // Early Bird: 6 AM - 9 AM (1.5x)
      if (sessionTimestamp.hour >= 6 && sessionTimestamp.hour < 9) {
        multiplier = 1.5;
      }
      // Night Owl: 10 PM - 1 AM (1.5x)
      else if (sessionTimestamp.hour >= 22 || sessionTimestamp.hour < 1) {
        multiplier = 1.5;
      }

      // Weekend Warrior: 2x XP on Sat/Sun (Overrides time boosts)
      if (sessionTimestamp.weekday == DateTime.saturday ||
          sessionTimestamp.weekday == DateTime.sunday) {
        multiplier = 2.0;
      }

      // Base XP: 10 per page + 5 per minute
      // (EPUBs are normalized to 10 "pages" per chapter in updateBookProgress)
      xp += ((p * 10 + m * 5) * multiplier).round();
    }

    // Add Quest XP from historical database
    xp += questXp;

    // Level calculation: 1 level per 1000 XP
    int level = (xp ~/ 1000) + 1;
    if (level > 99) level = 99;

    // Achievements check
    // Achievements check
    final achievements = <String>{};
    if (finishedBooks >= 1) achievements.add('the_first_page');
    if (streak >= 3) achievements.add('habit_builder');
    if (streak >= 7) achievements.add('seven_day_streak');
    if (streak >= 30) achievements.add('unstoppable');
    if (totalPages >= 1000) achievements.add('bookworm');
    if (totalPages >= 5000) achievements.add('scholar');
    if (finishedBooks >= 10) achievements.add('yomibito');
    if (finishedBooks >= 50) achievements.add('sensei');
    if (books.where((b) => !b.isDeleted).length >= 10) {
      achievements.add('bibliophile');
    }
    if (books.where((b) => !b.isDeleted).length >= 100) {
      achievements.add('collector');
    }

    // Time & Session based achievements
    final readOnSat = sessions.any((s) {
      final ts = s['timestamp'] != null
          ? DateTime.tryParse(s['timestamp']) ?? DateTime.parse(s['date'])
          : DateTime.parse(s['date']);
      return ts.weekday == DateTime.saturday;
    });
    final readOnSun = sessions.any((s) {
      final ts = s['timestamp'] != null
          ? DateTime.tryParse(s['timestamp']) ?? DateTime.parse(s['date'])
          : DateTime.parse(s['date']);
      return ts.weekday == DateTime.sunday;
    });
    if (readOnSat && readOnSun) achievements.add('weekend_warrior');

    for (var s in sessions) {
      final pages = (s['pagesRead'] as int? ?? 0);
      final minutes = (s['durationMinutes'] as int? ?? 0);
      final ts = s['timestamp'] != null
          ? DateTime.tryParse(s['timestamp']) ?? DateTime.parse(s['date'])
          : DateTime.parse(s['date']);

      if (pages >= 100) achievements.add('century_club');
      if (minutes >= 120) achievements.add('marathoner');
      if (ts.hour >= 6 && ts.hour < 9) achievements.add('early_bird');
      if (ts.hour >= 22 || ts.hour < 1) achievements.add('night_owl');
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

  _DetailedActivityData _calculateDetailedActivity(
    List<Map<String, dynamic>> sessions,
    List<Book> books,
  ) {
    final pages = <String, int>{};
    final minutes = <String, int>{};
    final xpMap = <String, int>{};

    for (var session in sessions) {
      final date = session['date'] as String;
      final bookId = session['bookId'] as int?;
      final book = books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => books.isNotEmpty
            ? books[0]
            : Book(
                title: 'Unknown',
                author: 'Unknown',
                coverPath: '',
                filePath: '',
                addedAt: DateTime.now(),
              ),
      );
      final isEpub = book.filePath.toLowerCase().endsWith('.epub');

      final p = (session['pagesRead'] as int? ?? 0);
      final m = (session['durationMinutes'] as int? ?? 0);

      final xp = isEpub ? (p * 40) + (m * 5) : (p * 10) + (m * 5);

      pages[date] = (pages[date] ?? 0) + p;
      minutes[date] = (minutes[date] ?? 0) + m;
      xpMap[date] = (xpMap[date] ?? 0) + xp;
    }

    return _DetailedActivityData(pages: pages, minutes: minutes, xp: xpMap);
  }

  // Helper getters for backward compat on graph if needed
  Map<String, int> get dailyReadingValues {
    if (state.weeklyGoalType == 'pages') return state.dailyPages;
    if (state.weeklyGoalType == 'minutes') return state.dailyMinutes;
    return state.dailyXP;
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

    // 1. Estimate Pages if null, based on progress
    // We only want to track pages read if progress moved and pagesRead wasn't provided.
    if (finalPages == 0 &&
        pagesRead == null &&
        durationMinutes != null &&
        durationMinutes > 0 &&
        progress > oldProgress + 0.001) {
      final effectiveTotalPages = book.totalPages > 0 ? book.totalPages : 300;
      finalPages = ((progress - oldProgress) * effectiveTotalPages)
          .round()
          .clamp(1, 100);
    }

    // 2. Estimate Minutes ONLY if allowed and not provided
    if (estimateReadingTime && finalMinutes == 0 && finalPages > 0) {
      finalMinutes = (finalPages * 1.2).ceil().clamp(1, 60);
    }

    if (finalPages > 0 || finalMinutes > 0) {
      await _dbService.insertReadingSession(bookId, finalPages, finalMinutes);
    }

    _updateStateAndSync(updatedBook);

    // Refresh stats
    final sessions = await _dbService.getReadingSessions();
    final questXp = await _dbService.getTotalQuestXP();
    final activity = _calculateDetailedActivity(sessions, state.allBooks);
    final stats = _calculateStats(sessions, state.allBooks, questXp);

    // Check for new achievements
    final newAchievements = stats.achievements.difference(
      state.unlockedAchievements,
    );
    for (var achievement in newAchievements) {
      final title = _getAchievementTitle(achievement);
      NotificationService().showNotification(
        id: achievement.hashCode,
        title: 'Achievement Unlocked!',
        body: 'You earned the "$title" badge!',
      );
    }

    state = state.copyWith(
      currentStreak: _calculateStreak(sessions),
      dailyPages: activity.pages,
      dailyMinutes: activity.minutes,
      dailyXP: activity.xp,
      totalXP: stats.xp,
      level: stats.level,
      totalPagesRead: stats.totalPages,
      totalMinutesRead: stats.totalMinutes,
      unlockedAchievements: stats.achievements,
      sessionHistory: sessions,
      isStreakActiveToday: _isStreakActiveToday(sessions),
    );

    await _updateQuests(finalPages, finalMinutes);
  }

  String _getAchievementTitle(String key) {
    switch (key) {
      case 'the_first_page':
        return 'The First Page';
      case 'habit_builder':
        return 'Habit Builder';
      case 'seven_day_streak':
        return '7-Day Streak';
      case 'unstoppable':
        return 'Unstoppable';
      case 'bookworm':
        return 'Bookworm';
      case 'scholar':
        return 'Scholar';
      case 'yomibito':
        return 'Yomibito';
      case 'sensei':
        return 'Sensei';
      case 'century_club':
        return 'Century Club';
      case 'marathoner':
        return 'Marathoner';
      case 'early_bird':
        return 'Early Bird';
      case 'night_owl':
        return 'Night Owl';
      case 'bibliophile':
        return 'Bibliophile';
      case 'collector':
        return 'Collector';
      case 'weekend_warrior':
        return 'Weekend Warrior';
      default:
        return 'New Achievement';
    }
  }

  Future<void> _updateQuests(int pagesRead, int minutesRead) async {
    if (pagesRead <= 0 && minutesRead <= 0) return;

    final now = DateTime.now();
    final updatedQuests = <DailyQuest>[];
    bool changed = false;

    for (var quest in state.dailyQuests) {
      if (quest.isCompleted) {
        updatedQuests.add(quest);
        continue;
      }

      int newVal = quest.currentValue;
      bool newlyCompleted = false;

      switch (quest.type) {
        case QuestType.pages:
          newVal += pagesRead;
          break;
        case QuestType.minutes:
          newVal += minutesRead;
          break;
        case QuestType.earlyBird:
          if (now.hour < 9) {
            newVal = 1;
          }
          break;
        case QuestType.nightOwl:
          if (now.hour >= 22 || now.hour < 1) {
            newVal = 1;
          }
          break;
        case QuestType.bookFinished:
          break;
      }

      if (newVal >= quest.targetValue) {
        newVal = quest.targetValue;
        newlyCompleted = true;
      }

      if (newVal != quest.currentValue || newlyCompleted) {
        final updated = quest.copyWith(
          currentValue: newVal,
          isCompleted: newlyCompleted,
        );
        updatedQuests.add(updated);
        await _dbService.updateQuestProgress(
          updated.id,
          updated.currentValue,
          updated.isCompleted,
        );
        changed = true;
      } else {
        updatedQuests.add(quest);
      }
    }

    if (changed) {
      final oldQuests = state.dailyQuests;
      state = state.copyWith(dailyQuests: updatedQuests);

      // Notify for newly completed quests
      for (var q in updatedQuests) {
        final wasCompleted = oldQuests.any(
          (oq) => oq.id == q.id && oq.isCompleted,
        );
        if (q.isCompleted && !wasCompleted) {
          NotificationService().showNotification(
            id: q.id.hashCode,
            title: 'Quest Completed!',
            body: 'You completed: ${q.title}. +${q.xpReward} XP earned!',
          );
        }
      }

      // Reload stats to reflect quest XP
      final sessions = await _dbService.getReadingSessions();
      final questXp = await _dbService.getTotalQuestXP();
      final stats = _calculateStats(sessions, state.allBooks, questXp);

      // Check for level up notification
      if (stats.level > state.level) {
        final newRank = YomuConstants.getRankForLevel(stats.level);
        final oldRank = YomuConstants.getRankForLevel(state.level);

        if (newRank.name != oldRank.name) {
          NotificationService().showNotification(
            id: 1001,
            title: 'Rank Up!',
            body: 'Congratulations! You are now a ${newRank.name}!',
          );
        } else {
          NotificationService().showNotification(
            id: 1002,
            title: 'Level Up!',
            body: 'You reached Level ${stats.level}!',
          );
        }
      }

      state = state.copyWith(totalXP: stats.xp, level: stats.level);
    }
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

    return (totalPages / totalMinutes).clamp(0.1, 100.0);
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

  Future<void> updateWeeklyGoals({
    double? pages,
    double? minutes,
    double? xp,
    String? activeType,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final newPages = pages ?? state.weeklyPageGoal;
    final newMinutes = minutes ?? state.weeklyMinuteGoal;
    final newXP = xp ?? state.weeklyXPGoal;
    final newType = activeType ?? state.weeklyGoalType;

    if (pages != null) await prefs.setDouble('weeklyPageGoal', pages);
    if (minutes != null) await prefs.setDouble('weeklyMinuteGoal', minutes);
    if (xp != null) await prefs.setDouble('weeklyXPGoal', xp);
    if (activeType != null) await prefs.setString('weeklyGoalType', activeType);

    state = state.copyWith(
      weeklyPageGoal: newPages,
      weeklyMinuteGoal: newMinutes,
      weeklyXPGoal: newXP,
      weeklyGoalType: newType,
    );

    // Re-calculate activity data
    final sessions = await _dbService.getReadingSessions();
    final activity = _calculateDetailedActivity(sessions, state.allBooks);

    state = state.copyWith(
      dailyPages: activity.pages,
      dailyMinutes: activity.minutes,
      dailyXP: activity.xp,
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

class _DetailedActivityData {
  final Map<String, int> pages;
  final Map<String, int> minutes;
  final Map<String, int> xp;

  _DetailedActivityData({
    required this.pages,
    required this.minutes,
    required this.xp,
  });
}
