import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
              _buildHeader(
                context,
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 30),
              if (recentBooks.isNotEmpty) ...[
                _buildContinueReadingTile(context, ref, recentBooks.first)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 30),
              ],
              _buildQuickStats(context, libraryState)
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 30),
              if (recentBooks.length > 1) ...[
                Text(
                  'My Shelf',
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate().fadeIn(delay: 500.ms),
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
                      return _buildShelfItem(context, ref, book)
                          .animate()
                          .fadeIn(delay: (600 + (index * 100)).ms)
                          .scale(begin: const Offset(0.9, 0.9));
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
              Text(
                'Reading Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ).animate().fadeIn(delay: 800.ms),
              const SizedBox(height: 4),
              Text(
                'Current Month',
                style: TextStyle(
                  color: YomuConstants.textSecondary,
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 850.ms),
              const SizedBox(height: 12),
              ActivityGraph(
                dailyValues: libraryState.dailyReadingValues,
                selectedMonth: DateFormat('MMMM yyyy').format(DateTime.now()),
                weeklyGoalType: libraryState.weeklyGoalType,
                weeklyGoalValue: libraryState.weeklyGoalValue,
                onDateTapped: (date, value) =>
                    _showDailyActivityDetail(context, ref, date, value),
              ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.05, end: 0),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();

    return Stack(
      children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  YomuConstants.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(now).toUpperCase(),
              style: TextStyle(
                color: YomuConstants.accent.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: now.hour < 12
                        ? 'Good Morning, \n'
                        : now.hour < 17
                        ? 'Good Afternoon, \n'
                        : 'Good Evening, \n',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 24,
                      color: YomuConstants.textSecondary,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: 'Yomite',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: YomuConstants.textPrimary,
                    ),
                  ),
                ],
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
        const SizedBox(width: 8),
        _buildStatItem(
          context,
          'Pages',
          '${state.totalPagesRead}',
          Icons.auto_stories,
          YomuConstants.accentGreen,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          context,
          'Minutes',
          '${state.totalMinutesRead}',
          Icons.timer,
          Colors.orangeAccent,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          context,
          'Level',
          '${state.level}',
          Icons.stars_rounded,
          Colors.purpleAccent,
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

  void _showDailyActivityDetail(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    int totalValue,
  ) {
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
                                image: book.coverPath.startsWith('assets')
                                    ? AssetImage(book.coverPath)
                                          as ImageProvider
                                    : FileImage(File(book.coverPath)),
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
