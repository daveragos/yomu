import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';
import '../components/activity_graph.dart';
import '../components/stat_badge.dart';
import '../components/daily_activity_sheet.dart';
import '../providers/library_provider.dart';
import './dashboard/widgets/dashboard_header.dart';
import './dashboard/widgets/continue_reading_card.dart';
import './dashboard/widgets/shelf_item.dart';
import '../components/rank_up_dialog.dart';
import 'main_navigation.dart';

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
    ref.listen(libraryProvider.select((s) => s.level), (previous, next) {
      final state = ref.read(libraryProvider);
      final currentRank = YomuConstants.getRankForLevel(next);
      final lastRank = YomuConstants.getRankForLevel(state.lastCelebratedLevel);

      if (currentRank.level > lastRank.level) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              RankUpDialog(level: next, rankName: state.rankName),
        );
        ref.read(libraryProvider.notifier).markLevelCelebrated(next);
      }
    });

    final libraryState = ref.watch(libraryProvider);
    final hasAnimated = ref.watch(hasDashboardAnimatedProvider);

    final recentBooks =
        libraryState.allBooks.where((b) => b.lastReadAt != null).toList()
          ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));

    return Scaffold(
      backgroundColor: YomuConstants.background,
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
                  ContinueReadingCard(book: recentBooks.first),
                  hasAnimated,
                  (w) => w
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
                const SizedBox(height: 30),
              ],
              _animateIf(
                _buildQuickStats(context, libraryState),
                hasAnimated,
                (w) => w
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0),
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
                            color: YomuConstants.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  hasAnimated,
                  (w) => w.animate().fadeIn(delay: 500.ms),
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
                        ShelfItem(book: book),
                        hasAnimated,
                        (w) => w
                            .animate()
                            .fadeIn(delay: (600 + (index * 100)).ms)
                            .scale(begin: const Offset(0.9, 0.9)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
              _animateIf(
                Text(
                  'Reading Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                hasAnimated,
                (w) => w.animate().fadeIn(delay: 800.ms),
              ),
              const SizedBox(height: 4),
              _animateIf(
                Text(
                  'Current Month',
                  style: TextStyle(
                    color: YomuConstants.textSecondary,
                    fontSize: 12,
                  ),
                ),
                hasAnimated,
                (w) => w.animate().fadeIn(delay: 850.ms),
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
                    .fadeIn(delay: 900.ms)
                    .slideY(begin: 0.05, end: 0),
              ),
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

  Widget _buildQuickStats(BuildContext context, LibraryState state) {
    return Row(
      children: [
        Expanded(
          child: StatBadge(
            label: 'Streak',
            value: '${state.currentStreak}',
            icon: Icons.local_fire_department,
            color: YomuConstants.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Pages',
            value: '${state.totalPagesRead}',
            icon: Icons.auto_stories,
            color: YomuConstants.accentGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Minutes',
            value: '${state.totalMinutesRead}',
            icon: Icons.timer,
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatBadge(
            label: 'Level',
            value: '${state.level}',
            icon: Icons.stars_rounded,
            color: Colors.purpleAccent,
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

    showModalBottomSheet(
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
}
