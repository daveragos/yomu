import 'package:flutter/material.dart';
import '../../../core/constants.dart';
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: sortedList.length,
          itemBuilder: (context, index) {
            final ach = sortedList[index];
            final isUnlocked = state.unlockedAchievements.contains(ach['id']);
            return AchievementBadge(
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
}
