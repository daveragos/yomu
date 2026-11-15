import 'package:flutter/material.dart';
import '../../../core/yomu_colors.dart';
import '../../../providers/library_provider.dart';

class AchievementBadge extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool isUnlocked;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.desc,
    required this.icon,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.tint(0.05),
            border: Border.all(
              color: isUnlocked ? colors.accent : colors.tint(0.10),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isUnlocked ? colors.accent : colors.tint(0.24),
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
            color: isUnlocked ? colors.textPrimary : colors.tint(0.24),
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
          style: TextStyle(color: colors.tint(0.24), fontSize: 8),
        ),
      ],
    );
  }
}

class AchievementsGrid extends StatelessWidget {
  final LibraryState state;

  const AchievementsGrid({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final achievementList = [
      {
        'id': 'the_first_page',
        'title': 'The First Page',
        'desc': 'Finish your first book',
        'icon': Icons.book,
      },
      {
        'id': 'habit_builder',
        'title': 'Habit Builder',
        'desc': 'Read for 3 days in a row',
        'icon': Icons.trending_up,
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
        'id': 'early_bird',
        'title': 'Early Bird',
        'desc': 'Read books before 9 AM',
        'icon': Icons.wb_sunny,
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
        'desc': 'Read for 2 hours in one go',
        'icon': Icons.timer,
      },
      {
        'id': 'scholar',
        'title': 'Scholar',
        'desc': 'Total 5,000 pages read',
        'icon': Icons.history_edu,
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
        'id': 'bibliophile',
        'title': 'Bibliophile',
        'desc': 'Add 10 books to library',
        'icon': Icons.library_books,
      },
      {
        'id': 'collector',
        'title': 'Collector',
        'desc': 'Add 100 books to library',
        'icon': Icons.collections_bookmark,
      },
      {
        'id': 'weekend_warrior',
        'title': 'Weekend Warrior',
        'desc': 'Read on both Sat and Sun',
        'icon': Icons.umbrella,
      },
      {
        'id': 'the_translator',
        'title': 'Word Seeker',
        'desc': 'Look up your first word',
        'icon': Icons.search,
      },
      {
        'id': 'vocabulary_builder',
        'title': 'Vocab Builder',
        'desc': 'Total 20 words looked up',
        'icon': Icons.menu_book,
      },
      {
        'id': 'polyglot',
        'title': 'Lexicoguru',
        'desc': 'Total 100 words looked up',
        'icon': Icons.psychology,
      },
    ];

    final sortedList = List<Map<String, dynamic>>.from(achievementList);
    sortedList.sort((a, b) {
      final aUnlocked = state.unlockedAchievements.contains(a['id']);
      final bUnlocked = state.unlockedAchievements.contains(b['id']);
      if (aUnlocked == bUnlocked) return 0;
      return aUnlocked ? -1 : 1;
    });

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
          // Three columns on phones, more as the layout widens.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: sortedList.length,
          itemBuilder: (context, index) {
            final ach = sortedList[index];
            final isUnlocked = state.unlockedAchievements.contains(ach['id']);
            return GestureDetector(
              onTap: () => _showAchievementDetail(
                context,
                title: ach['title'] as String,
                desc: ach['desc'] as String,
                icon: ach['icon'] as IconData,
                isUnlocked: isUnlocked,
              ),
              child: AchievementBadge(
                title: ach['title'] as String,
                desc: ach['desc'] as String,
                icon: ach['icon'] as IconData,
                isUnlocked: isUnlocked,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAchievementDetail(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required bool isUnlocked,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = context.yomu;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.tint(0.05),
                  border: Border.all(
                    color: isUnlocked ? colors.accent : colors.tint(0.10),
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isUnlocked ? colors.accent : colors.tint(0.24),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnlocked ? colors.textPrimary : colors.tint(0.38),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnlocked ? colors.tint(0.70) : colors.tint(0.24),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isUnlocked ? 'Unlocked' : 'Keep reading to unlock!',
                style: TextStyle(
                  color: isUnlocked ? colors.accent : colors.tint(0.24),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
