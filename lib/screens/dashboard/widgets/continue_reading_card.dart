import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../reading_screen.dart';

class ContinueReadingCard extends ConsumerWidget {
  final Book book;

  const ContinueReadingCard({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
}
