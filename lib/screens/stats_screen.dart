import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _selectedMonth = 'January 2026';

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

    return GlassContainer(
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
                Text(
                  currentTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
            'Keep going! Progress: ${(progress * 100).toInt()}%',
            style: TextStyle(color: YomuConstants.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(YomuConstants.accent),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final months = ['December 2025', 'January 2026', 'February 2026'];
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
              ...months.map(
                (m) => ListTile(
                  title: Text(
                    m,
                    style: TextStyle(
                      color: _selectedMonth == m
                          ? YomuConstants.accent
                          : Colors.white,
                    ),
                  ),
                  trailing: _selectedMonth == m
                      ? Icon(Icons.check, color: YomuConstants.accent)
                      : null,
                  onTap: () {
                    setState(() => _selectedMonth = m);
                    Navigator.pop(context);
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

  @override
  void initState() {
    super.initState();
    final state = ref.read(libraryProvider);
    _value = state.weeklyGoalValue;
    _type = state.weeklyGoalType;
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
                  Text(
                    '${_value.toInt()} $_type',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: YomuConstants.accent,
                    ),
                  ),
                  Row(
                    children: [
                      _buildValueBtn(Icons.remove, () {
                        setState(() => _value = (_value - 10).clamp(10, 1000));
                      }),
                      const SizedBox(width: 12),
                      _buildValueBtn(Icons.add, () {
                        setState(() => _value = (_value + 10).clamp(10, 1000));
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
