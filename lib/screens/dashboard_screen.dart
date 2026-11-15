import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';
import '../core/yomu_colors.dart';
import '../components/activity_graph.dart';
import '../components/stat_badge.dart';
import '../components/daily_activity_sheet.dart';
import '../providers/library_provider.dart';
import './dashboard/widgets/dashboard_header.dart';
import './dashboard/widgets/continue_reading_card.dart';
import './dashboard/widgets/shelf_item.dart';
import '../components/streak_widget.dart';
import 'main_navigation.dart';
import '../models/book_model.dart';
import 'edit_book_screen.dart';
import '../components/book_overlay_menu.dart';
import 'reading/widgets/share_with_notes.dart';
import '../components/daily_quests_card.dart';
import '../components/desktop/adaptive_sheet.dart';
import '../components/desktop/hover_lift.dart';
import '../components/desktop/page_header.dart';
import '../core/breakpoints.dart';
import '../components/desktop/desktop_columns.dart';
import './dashboard/widgets/continue_reading_hero.dart';
import './dashboard/widgets/desktop_stat_tile.dart';
import './stats/widgets/level_info_card.dart';
import './stats/widgets/level_metadata_sheet.dart';

final hasDashboardAnimatedProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(hasDashboardAnimatedProvider.notifier).state = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final hasAnimated = ref.watch(hasDashboardAnimatedProvider);

    final recentBooks =
        libraryState.allBooks.where((b) => b.lastReadAt != null).toList()
          ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));

    if (Breakpoints.isWide(context)) {
      return _buildWide(context, libraryState, recentBooks, hasAnimated);
    }

    final colors = context.yomu;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: YomuConstants.horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _animateIf(
                const DashboardHeader(),
                hasAnimated,
                (w) => w
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.1, end: 0),
              ),
              const SizedBox(height: 30),
              if (recentBooks.isNotEmpty) ...[
                _animateIf(
                  ContinueReadingCard(
                    book: recentBooks.first,
                    onLongPress: (pos) =>
                        _showBookOptions(recentBooks.first, pos),
                    onMenuPressed: (pos) =>
                        _showBookOptions(recentBooks.first, pos),
                  ),
                  hasAnimated,
                  (w) => w
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
                const SizedBox(height: 30),
              ],
              const SizedBox(height: 30),
              _animateIf(
                _buildQuickStats(context, libraryState),
                hasAnimated,
                (w) => w
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0),
              ),
              const SizedBox(height: 30),
              _animateIf(
                Text(
                  'Reading Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                hasAnimated,
                (w) => w.animate().fadeIn(delay: 500.ms),
              ),
              const SizedBox(height: 4),
              _animateIf(
                Text(
                  'Current Month',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                hasAnimated,
                (w) => w.animate().fadeIn(delay: 550.ms),
              ),
              const SizedBox(height: 12),
              _animateIf(
                ActivityGraph(
                  dailyValues: libraryState.dailyReadingValues,
                  selectedMonth: DateFormat('MMMM yyyy').format(DateTime.now()),
                  weeklyGoalType: libraryState.weeklyGoalType,
                  weeklyGoalValue: libraryState.weeklyGoalValue,
                  onDateTapped: (date, value) => _showDailyActivityDetail(
                    context,
                    libraryState,
                    date,
                    value,
                  ),
                ),
                hasAnimated,
                (w) => w
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.05, end: 0),
              ),
              const SizedBox(height: 30),
              if (recentBooks.length > 1) ...[
                _animateIf(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Shelf',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(navigationStateProvider.notifier).state =
                              NavigationState(current: 1, previous: 0);
                        },
                        child: Text(
                          'See More',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  hasAnimated,
                  (w) => w.animate().fadeIn(delay: 800.ms),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (recentBooks.length - 1).clamp(0, 5),
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final book = recentBooks[index + 1];
                      return _animateIf(
                        ShelfItem(
                          book: book,
                          onLongPress: (pos) => _showBookOptions(book, pos),
                          onMenuPressed: (pos) => _showBookOptions(book, pos),
                        ),
                        hasAnimated,
                        (w) => w
                            .animate()
                            .fadeIn(delay: (900 + (index * 100)).ms)
                            .scale(begin: const Offset(0.9, 0.9)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
              const SizedBox(height: 30),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animateIf(
    Widget widget,
    bool hasAnimated,
    Widget Function(Widget) animator,
  ) {
    if (hasAnimated) return widget;
    return animator(widget);
  }

  /// Wide windows: a header across the top, then the current book, shelf and
  /// activity on the left, and level, stats and quests on the right.
  Widget _buildWide(
    BuildContext context,
    LibraryState state,
    List<Book> recentBooks,
    bool hasAnimated,
  ) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final shelf = recentBooks.skip(1).take(10).toList();
    final colors = context.yomu;

    Widget reveal(Widget child, int delayMs) => _animateIf(
      child,
      hasAnimated,
      (w) => w
          .animate()
          .fadeIn(delay: delayMs.ms, duration: 500.ms)
          .slideY(begin: 0.05, end: 0),
    );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reveal(
          recentBooks.isEmpty
              ? ContinueReadingEmpty(onOpenLibrary: _openLibrary)
              : ContinueReadingHero(
                  book: recentBooks.first,
                  onShowOptions: (pos) =>
                      _showBookOptions(recentBooks.first, pos),
                ),
          100,
        ),
        if (shelf.isNotEmpty) ...[
          const SizedBox(height: 36),
          reveal(
            _wideSectionTitle(
              context,
              'My Shelf',
              action: TextButton(
                onPressed: _openLibrary,
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            300,
          ),
          const SizedBox(height: 12),
          reveal(
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final book in shelf)
                  ShelfItem(
                    book: book,
                    onLongPress: (pos) => _showBookOptions(book, pos),
                    onMenuPressed: (pos) => _showBookOptions(book, pos),
                  ),
              ],
            ),
            350,
          ),
        ],
        const SizedBox(height: 36),
        reveal(
          _wideSectionTitle(
            context,
            'Reading Activity',
            subtitle: DateFormat('MMMM yyyy').format(now),
          ),
          400,
        ),
        const SizedBox(height: 16),
        reveal(
          ActivityGraph(
            dailyValues: state.dailyReadingValues,
            selectedMonth: DateFormat('MMMM yyyy').format(now),
            weeklyGoalType: state.weeklyGoalType,
            weeklyGoalValue: state.weeklyGoalValue,
            onDateTapped: (date, value) =>
                _showDailyActivityDetail(context, state, date, value),
          ),
          450,
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reveal(
          HoverLift(
            lift: 2,
            child: LevelInfoCard(
              state: state,
              onTap: () => _showLevelMetadata(context, state),
            ),
          ),
          200,
        ),
        const SizedBox(height: 20),
        reveal(_buildWideStatGrid(state, colors), 300),
        const SizedBox(height: 20),
        reveal(DailyQuestsCard(quests: state.dailyQuests), 400),
      ],
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Breakpoints.desktopGutter,
            28,
            Breakpoints.desktopGutter,
            48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              reveal(
                DesktopPageHeader(
                  eyebrow: DateFormat('EEEE, MMM d').format(now),
                  title: '$greeting, ${state.rankName}',
                  subtitle: _streakLine(state),
                ),
                0,
              ),
              const SizedBox(height: 32),
              DesktopColumns(
                start: left,
                end: right,
                startFlex: 3,
                endFlex: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _streakLine(LibraryState state) {
    final streak = state.currentStreak;
    if (streak == 0) return 'Read a few pages today to start a streak.';
    final days = streak == 1 ? '1-day streak' : '$streak-day streak';
    return state.isStreakActiveToday
        ? 'You have read today. $days and counting.'
        : 'Read a few pages today to keep your $days.';
  }

  Widget _wideSectionTitle(
    BuildContext context,
    String title, {
    String? subtitle,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.yomu.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }

  Widget _buildWideStatGrid(LibraryState state, YomuColors colors) {
    final tiles = [
      DesktopStatTile(
        label: 'Day streak',
        value: '${state.currentStreak}',
        icon: Icons.local_fire_department,
        color: streakColor(
          colors: colors,
          streak: state.currentStreak,
          isActive: state.isStreakActiveToday,
        ),
      ),
      DesktopStatTile(
        label: 'Pages',
        value: '${state.totalPagesRead}',
        icon: Icons.auto_stories,
      ),
      DesktopStatTile(
        label: 'Minutes',
        value: '${state.totalMinutesRead}',
        icon: Icons.timer,
      ),
      // The level card above already shows the level, so the fourth tile
      // shows total XP instead.
      DesktopStatTile(
        label: 'Total XP',
        value: '${state.totalXP}',
        icon: Icons.stars_rounded,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 16),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 16),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  void _openLibrary() {
    ref.read(navigationStateProvider.notifier).state = NavigationState(
      current: 1,
      previous: 0,
    );
  }

  void _showLevelMetadata(BuildContext context, LibraryState state) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LevelMetadataSheet(state: state),
    );
  }

  Widget _buildQuickStats(BuildContext context, LibraryState state) {
    return Row(
      children: [
        Expanded(
          child: StreakWidget(
            streak: state.currentStreak,
            isActive: state.isStreakActiveToday,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Pages',
            value: '${state.totalPagesRead}',
            icon: Icons.auto_stories,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Minutes',
            value: '${state.totalMinutesRead}',
            icon: Icons.timer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Level',
            value: '${state.level}',
            icon: Icons.stars_rounded,
          ),
        ),
      ],
    );
  }

  void _showDailyActivityDetail(
    BuildContext context,
    LibraryState state,
    DateTime date,
    int totalValue,
  ) {
    if (totalValue == 0) return;

    showAdaptiveSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyActivitySheet(
        date: date,
        totalValue: totalValue,
        goalType: state.weeklyGoalType,
        allBooks: state.allBooks,
        sessionHistory: state.sessionHistory,
      ),
    );
  }

  void _showBookOptions(Book book, Offset tapPosition) {
    BookOverlayMenu.show(
      context: context,
      book: book,
      position: tapPosition,
      onAction: (action) {
        switch (action) {
          case 'favorite':
            ref.read(libraryProvider.notifier).toggleBookFavorite(book);
            break;
          case 'edit':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditBookScreen(book: book),
              ),
            );
            break;
          case 'share_notes':
            shareBookWithNotes(context, book);
            break;
          case 'delete':
            _showDeleteConfirmation(book);
            break;
        }
      },
    );
  }

  void _showDeleteConfirmation(Book book) async {
    bool deleteHistory = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = context.yomu;
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              'Remove Book',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to remove "${book.title}"?',
                  style: TextStyle(color: colors.tint(0.70)),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Remove reading history',
                    style: TextStyle(fontSize: 14, color: colors.tint(0.70)),
                  ),
                  value: deleteHistory,
                  activeColor: colors.accent,
                  onChanged: (val) {
                    setDialogState(() {
                      deleteHistory = val ?? false;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.tint(0.60)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      ref
          .read(libraryProvider.notifier)
          .deleteBook(book.id!, deleteHistory: deleteHistory);
    }
  }
}
