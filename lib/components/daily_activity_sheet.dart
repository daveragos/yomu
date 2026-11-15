import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/yomu_colors.dart';
import './glass_container.dart';
import '../models/book_model.dart';
import '../providers/library_provider.dart';
import '../screens/reading_screen.dart';

class DailyActivitySheet extends ConsumerWidget {
  final DateTime date;
  final int totalValue;
  final String goalType;
  final List<Book> allBooks;
  final List<dynamic> sessionHistory;

  const DailyActivitySheet({
    super.key,
    required this.date,
    required this.totalValue,
    required this.goalType,
    required this.allBooks,
    required this.sessionHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = date.toIso8601String().split('T')[0];
    final daySessions = sessionHistory
        .where((s) => s['date'] == dateStr)
        .toList();

    // Group and aggregate sessions by bookId
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
    final colors = context.yomu;

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
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Daily Achievement',
                    style: TextStyle(
                      color: colors.textSecondary,
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
                  color: colors.tint(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.tint(0.10)),
                ),
                child: Text(
                  '$totalValue $goalType',
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Books Read',
            style: TextStyle(
              color: colors.tint(0.70),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (mergedSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No specific book data for this day',
                  style: TextStyle(color: colors.tint(0.38)),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mergedSessions.length,
                itemBuilder: (context, index) {
                  final session = mergedSessions[index];
                  final bookId = session['bookId'] as int;

                  // Safe search for the book
                  Book? book;
                  try {
                    book = allBooks.firstWhere((b) => b.id == bookId);
                  } catch (_) {
                    // Book might have been deleted but session history remains
                  }

                  final int val;
                  if (goalType == 'pages') {
                    val = session['pagesRead'] as int? ?? 0;
                  } else if (goalType == 'minutes') {
                    val = session['durationMinutes'] as int? ?? 0;
                  } else {
                    // XP
                    final isEpub =
                        book?.filePath.toLowerCase().endsWith('.epub') ?? false;
                    final p = session['pagesRead'] as int? ?? 0;
                    final m = session['durationMinutes'] as int? ?? 0;
                    val = isEpub ? (p * 40 + m * 5) : (p * 10 + m * 5);
                  }

                  if (book == null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.tint(0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                'assets/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Unknown Book (Removed)',
                              style: TextStyle(
                                color: colors.tint(0.38),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          Text(
                            '+$val',
                            style: TextStyle(
                              color: colors.tint(0.38),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        // Close bottom sheet before navigation
                        Navigator.pop(context);

                        ref.read(currentlyReadingProvider.notifier).state =
                            book;
                        ref
                            .read(libraryProvider.notifier)
                            .markBookAsOpened(book!);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReadingScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: book.coverPath.startsWith('assets')
                                    ? Image.asset(
                                        book.coverPath,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Image.asset(
                                                    'assets/icon.png',
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                      )
                                    : Image.file(
                                        File(book.coverPath),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Image.asset(
                                                    'assets/icon.png',
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
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
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    book.author,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+$val',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
