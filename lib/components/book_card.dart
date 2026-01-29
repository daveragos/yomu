import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../core/constants.dart';
import 'glass_container.dart';

import '../models/book_model.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCard({super.key, required this.book, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(YomuConstants.borderRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    book.coverPath.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: book.coverPath,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: YomuConstants.surface),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.book),
                          )
                        : book.coverPath.isNotEmpty
                        ? Image.file(
                            File(book.coverPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.book),
                          )
                        : Container(
                            color: YomuConstants.surface,
                            child: const Icon(
                              Icons.book,
                              color: Colors.white24,
                            ),
                          ),
                    if (book.isFavorite)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GlassContainer(
                        height: 40,
                        blur: 5,
                        opacity: 0.2,
                        borderRadius: 0,
                        child: Center(
                          child: LinearPercentIndicator(
                            lineHeight: 4.0,
                            percent: book.progress,
                            backgroundColor: Colors.white24,
                            progressColor: YomuConstants.accent,
                            barRadius: const Radius.circular(2),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
