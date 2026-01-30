import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../components/activity_graph.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import 'reading_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
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
              _buildHeader(context),
              const SizedBox(height: 30),
              if (recentBooks.isNotEmpty) ...[
                _buildContinueReadingTile(context, ref, recentBooks.first),
                const SizedBox(height: 30),
              ],
              _buildQuickStats(context, libraryState),
              const SizedBox(height: 30),
              if (recentBooks.length > 1) ...[
                Text('My Shelf', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (recentBooks.length - 1).clamp(0, 10),
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final book = recentBooks[index + 1];
                      return _buildShelfItem(context, ref, book);
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
              Text(
                'Reading Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Current Month',
                style: TextStyle(
                  color: YomuConstants.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ActivityGraph(
                dailyValues: libraryState.dailyReadingValues,
                selectedMonth: DateFormat('MMMM yyyy').format(DateTime.now()),
                weeklyGoalType: libraryState.weeklyGoalType,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    // Simple manual date formatting for "Monday, Oct 24"
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr =
        '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr.toUpperCase(),
          style: TextStyle(
            color: YomuConstants.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Good Evening, ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 24,
                color: YomuConstants.textSecondary,
              ),
            ),
            Text(
              'Yomite',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, LibraryState state) {
    return Row(
      children: [
        _buildStatItem(
          context,
          'Streak',
          '${state.currentStreak}',
          Icons.local_fire_department,
          YomuConstants.accent,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          context,
          'Pages',
          '${state.totalPagesRead}',
          Icons.auto_stories,
          YomuConstants.accentGreen,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          context,
          'Level',
          '${state.level}',
          Icons.stars_rounded,
          Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: GlassContainer(
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
      ),
    );
  }

  Widget _buildContinueReadingTile(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(currentlyReadingProvider.notifier).state = book;
        ref.read(libraryProvider.notifier).markBookAsOpened(book);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReadingScreen()),
        );
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: book.coverPath.startsWith('assets')
                      ? AssetImage(book.coverPath) as ImageProvider
                      : FileImage(File(book.coverPath)),
                  fit: BoxFit.cover,
                ),
                boxShadow: YomuConstants.cardShadow,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    book.author,
                    style: TextStyle(
                      color: YomuConstants.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: book.progress,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            YomuConstants.accent,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(book.progress * 100).toInt()}%',
                        style: TextStyle(
                          color: YomuConstants.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfItem(BuildContext context, WidgetRef ref, Book book) {
    return GestureDetector(
      onTap: () {
        ref.read(currentlyReadingProvider.notifier).state = book;
        ref.read(libraryProvider.notifier).markBookAsOpened(book);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReadingScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: book.coverPath.startsWith('assets')
                    ? AssetImage(book.coverPath) as ImageProvider
                    : FileImage(File(book.coverPath)),
                fit: BoxFit.cover,
              ),
              boxShadow: YomuConstants.cardShadow,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              book.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
