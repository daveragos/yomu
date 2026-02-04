import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import './glass_container.dart';
import '../models/book_model.dart';

class DailyActivitySheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                  '$totalValue $goalType',
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
          if (mergedSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No specific book data for this day',
                  style: TextStyle(color: Colors.white38),
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

                  if (book == null) return const SizedBox.shrink();

                  final val = goalType == 'pages'
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
                                  ? AssetImage(book.coverPath) as ImageProvider
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
  }
}
