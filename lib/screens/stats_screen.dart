import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../components/activity_graph.dart';
import '../providers/library_provider.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      backgroundColor: YomuConstants.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading Stats',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _buildLevelInfo(context, libraryState),
              const SizedBox(height: 32),
              _buildQuickStats(context, libraryState),
              const SizedBox(height: 32),
              _buildWeeklyGoal(context, libraryState),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reading Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showMonthPicker(context),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(_selectedMonth),
                    style: TextButton.styleFrom(
                      foregroundColor: YomuConstants.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ActivityGraph(
                dailyValues: libraryState.dailyReadingValues,
                selectedMonth: _selectedMonth,
                weeklyGoalType: libraryState.weeklyGoalType,
                weeklyGoalValue: libraryState.weeklyGoalValue,
                onDateTapped: (date, value) =>
                    _showDailyActivityDetail(date, value),
              ),
              const SizedBox(height: 32),
              _buildAchievements(context, libraryState),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelInfo(BuildContext context, LibraryState state) {
    final titles = {
      1: 'Kohai (後輩)',
      5: 'Yomite (読み手)',
      10: 'Senpai (先輩)',
      20: 'Chousha (著者)',
      40: 'Sensei (先生)',
      50: 'Tatsujin (達人)',
    };

    String currentTitle = 'Kohai (後輩)';
    for (var entry in titles.entries) {
      if (state.level >= entry.key) currentTitle = entry.value;
    }

    return GestureDetector(
      onTap: () => _showLevelMetadata(context, state),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: YomuConstants.accent.withValues(alpha: 0.1),
                border: Border.all(color: YomuConstants.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: YomuConstants.accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${state.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currentTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                  Text(
                    'Current Level',
                    style: TextStyle(
                      color: YomuConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (state.totalXP % 1000) / 1000,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        YomuConstants.accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelMetadata(BuildContext context, LibraryState state) {
    final titles = [
      {
        'level': 1,
        'name': 'Kohai (後輩)',
        'desc': 'Getting started on the journey.',
      },
      {'level': 5, 'name': 'Yomite (読み手)', 'desc': 'A dedicated reader.'},
      {
        'level': 10,
        'name': 'Senpai (先輩)',
        'desc': 'Experienced and knowledgeable.',
      },
      {
        'level': 20,
        'name': 'Chousha (著者)',
        'desc': 'Deeply connected to the words.',
      },
      {
        'level': 40,
        'name': 'Sensei (先生)',
        'desc': 'A master of the literary arts.',
      },
      {
        'level': 50,
        'name': 'Tatsujin (達人)',
        'desc': 'Absolute mastery reached.',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reading Ranks',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Earn XP by reading to rank up!',
                style: TextStyle(
                  color: YomuConstants.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              ...titles.map((t) {
                final bool isReached = state.level >= (t['level'] as int);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReached
                              ? YomuConstants.accent.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isReached
                                ? YomuConstants.accent
                                : Colors.white10,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${t['level']}',
                            style: TextStyle(
                              color: isReached ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] as String,
                              style: TextStyle(
                                color: isReached
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              t['desc'] as String,
                              style: TextStyle(
                                color: isReached
                                    ? YomuConstants.textSecondary
                                    : Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isReached)
                        Icon(
                          Icons.check_circle,
                          color: YomuConstants.accent,
                          size: 18,
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats(BuildContext context, LibraryState state) {
    return Row(
      children: [
        Expanded(
          child: _buildBadge(
            context,
            'Streak',
            '${state.currentStreak}',
            Icons.local_fire_department,
            YomuConstants.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBadge(
            context,
            'Pages',
            '${state.totalPagesRead}',
            Icons.auto_stories,
            YomuConstants.accentGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBadge(
            context,
            'Minutes',
            '${state.totalMinutesRead}',
            Icons.timer,
            Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoal(BuildContext context, LibraryState state) {
    final double goal = state.weeklyGoalValue;
    final double current = state.weeklyGoalType == 'minutes'
        ? state.totalMinutesRead.toDouble()
        : state.totalPagesRead.toDouble();
    final double progress = (current / goal).clamp(0.0, 1.0);

    final bool isGoalMet = progress >= 1.0;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Goal',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                onPressed: () => _showGoalSettings(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isGoalMet
                ? 'Amazing! Goal Exceeded! 🎉'
                : 'Keep going! Progress: ${(progress * 100).toInt()}%',
            style: TextStyle(
              color: isGoalMet
                  ? YomuConstants.accent
                  : YomuConstants.textSecondary,
              fontSize: 14,
              fontWeight: isGoalMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isGoalMet ? YomuConstants.accentGreen : YomuConstants.accent,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${current.toInt()} / ${goal.toInt()} ${state.weeklyGoalType}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(BuildContext context, LibraryState state) {
    final achievementList = [
      {
        'id': 'the_first_page',
        'title': 'The First Page',
        'desc': 'Finish your first book',
        'icon': Icons.book,
      },
      {
        'id': 'seven_day_streak',
        'title': '7-Day Streak',
        'desc': 'Read for 7 days in a row',
        'icon': Icons.flash_on,
      },
      {
        'id': 'bookworm',
        'title': 'Bookworm',
        'desc': 'Total 1,000 pages read',
        'icon': Icons.menu_book,
      },
      {
        'id': 'night_owl',
        'title': 'Night Owl',
        'desc': 'Read books after 10 PM',
        'icon': Icons.nightlight_round,
      },
      {
        'id': 'century_club',
        'title': 'Century Club',
        'desc': '100+ pages read in one go',
        'icon': Icons.military_tech,
      },
      {
        'id': 'unstoppable',
        'title': 'Unstoppable',
        'desc': 'Read for 30 days in a row',
        'icon': Icons.bolt,
      },
      {
        'id': 'marathoner',
        'title': 'Marathoner',
        'desc': 'Read for 5 hours in one go',
        'icon': Icons.timer,
      },
      {
        'id': 'yomibito',
        'title': 'Yomibito',
        'desc': 'Finish 10 books in total',
        'icon': Icons.auto_stories,
      },
      {
        'id': 'sensei',
        'title': 'Sensei',
        'desc': 'Finish 50 books in total',
        'icon': Icons.school,
      },
      {
        'id': 'early_bird',
        'title': 'Early Bird',
        'desc': 'Read books before 7 AM',
        'icon': Icons.wb_sunny,
      },
      {
        'id': 'genre_explorer',
        'title': 'Genre Explorer',
        'desc': 'Read from 5 different genres',
        'icon': Icons.explore,
      },
      {
        'id': 'collector',
        'title': 'Collector',
        'desc': 'Add 100 books to library',
        'icon': Icons.collections_bookmark,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: achievementList.length,
          itemBuilder: (context, index) {
            final ach = achievementList[index];
            final isUnlocked = state.unlockedAchievements.contains(ach['id']);
            return _AchievementBadge(
              title: ach['title'] as String,
              desc: ach['desc'] as String,
              icon: ach['icon'] as IconData,
              isUnlocked: isUnlocked,
            );
          },
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context) {
    final state = ref.read(libraryProvider);
    final sessions = state.dailyReadingValues.keys.toList();

    // Generate month list from session dates
    final Set<String> availableMonthsSet = {};
    availableMonthsSet.add(DateFormat('MMMM yyyy').format(DateTime.now()));

    for (var dateStr in sessions) {
      try {
        final date = DateTime.parse(dateStr);
        availableMonthsSet.add(DateFormat('MMMM yyyy').format(date));
      } catch (_) {}
    }

    final availableMonths = availableMonthsSet.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA); // Descending
      });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableMonths.length,
                  itemBuilder: (context, index) {
                    final m = availableMonths[index];
                    return ListTile(
                      title: Text(
                        m,
                        style: TextStyle(
                          color: _selectedMonth == m
                              ? YomuConstants.accent
                              : Colors.white,
                          fontWeight: _selectedMonth == m
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: _selectedMonth == m
                          ? Icon(Icons.check, color: YomuConstants.accent)
                          : null,
                      onTap: () {
                        setState(() => _selectedMonth = m);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _showGoalSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _GoalSettingsSheet();
      },
    );
  }

  void _showDailyActivityDetail(DateTime date, int totalValue) {
    if (totalValue == 0) return;

    final state = ref.read(libraryProvider);
    final dateStr = date.toIso8601String().split('T')[0];
    final daySessions = state.sessionHistory
        .where((s) => s['date'] == dateStr)
        .toList();

    // Group and aggregate sessions by bookId (using String key for robustness)
    final Map<String, Map<String, dynamic>> aggregatedMap = {};
    for (var s in daySessions) {
      final idRaw = s['bookId'];
      if (idRaw == null) continue;
      final bookIdKey = idRaw.toString();

      if (!aggregatedMap.containsKey(bookIdKey)) {
        aggregatedMap[bookIdKey] = {
          'bookId': idRaw is int ? idRaw : int.tryParse(bookIdKey) ?? 0,
          'pagesRead': 0,
          'durationMinutes': 0,
        };
      }
      aggregatedMap[bookIdKey]!['pagesRead'] =
          (aggregatedMap[bookIdKey]!['pagesRead'] as int) +
          (s['pagesRead'] as int? ?? 0);
      aggregatedMap[bookIdKey]!['durationMinutes'] =
          (aggregatedMap[bookIdKey]!['durationMinutes'] as int) +
          (s['durationMinutes'] as int? ?? 0);
    }

    final mergedSessions = aggregatedMap.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Daily Achievement',
                        style: TextStyle(
                          color: YomuConstants.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: YomuConstants.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: YomuConstants.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$totalValue ${state.weeklyGoalType}',
                      style: TextStyle(
                        color: YomuConstants.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Books Read',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mergedSessions.length,
                  itemBuilder: (context, index) {
                    final session = mergedSessions[index];
                    final bookId = session['bookId'] as int;
                    final book = state.allBooks.firstWhere(
                      (b) => b.id == bookId,
                    );
                    final val = state.weeklyGoalType == 'pages'
                        ? session['pagesRead']
                        : session['durationMinutes'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: (book.coverPath.startsWith('assets'))
                                    ? AssetImage(book.coverPath)
                                          as ImageProvider
                                    : FileImage(io.File(book.coverPath)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  book.author,
                                  style: TextStyle(
                                    color: YomuConstants.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+$val',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Keep it up!',
                  style: TextStyle(
                    color: YomuConstants.accent.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool isUnlocked;

  const _AchievementBadge({
    required this.title,
    required this.desc,
    required this.icon,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked
                ? YomuConstants.accent.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isUnlocked ? YomuConstants.accent : Colors.white10,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isUnlocked ? YomuConstants.accent : Colors.white24,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnlocked ? Colors.white : Colors.white24,
            fontSize: 10,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white24, fontSize: 8),
        ),
      ],
    );
  }
}

class _GoalSettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GoalSettingsSheet> createState() => _GoalSettingsSheetState();
}

class _GoalSettingsSheetState extends ConsumerState<_GoalSettingsSheet> {
  late double _value;
  late String _type;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = ref.read(libraryProvider);
    _value = state.weeklyGoalValue;
    _type = state.weeklyGoalType;
    _controller = TextEditingController(text: _value.toInt().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(double newValue) {
    setState(() {
      _value = newValue.clamp(1, 10000);
      _controller.text = _value.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Weekly Goal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'I want to read...',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeChip('minutes', Icons.timer),
                  const SizedBox(width: 12),
                  _buildTypeChip('pages', Icons.menu_book),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: YomuConstants.accent,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final dVal = double.tryParse(val);
                              if (dVal != null) {
                                setState(() {
                                  _value = dVal;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _type,
                          style: TextStyle(
                            fontSize: 16,
                            color: YomuConstants.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildValueBtn(Icons.remove, () {
                        _updateValue((_value - 10).clamp(1, 10000));
                      }),
                      const SizedBox(width: 12),
                      _buildValueBtn(Icons.add, () {
                        _updateValue((_value + 10).clamp(1, 10000));
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(libraryProvider.notifier)
                        .setWeeklyGoal(_value, _type);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YomuConstants.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Goal'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? YomuConstants.accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? YomuConstants.accent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? YomuConstants.accent : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              type.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? YomuConstants.accent : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
