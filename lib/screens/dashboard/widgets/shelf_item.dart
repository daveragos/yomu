import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../reading_screen.dart';

class ShelfItem extends ConsumerWidget {
  final Book book;

  const ShelfItem({super.key, required this.book});

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
