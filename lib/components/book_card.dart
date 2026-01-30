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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(YomuConstants.borderRadius),
          boxShadow: YomuConstants.cardShadow,
        ),
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
                    // New Tag
                    if (book.progress == 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: YomuConstants.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    // Progress Bar for Reading books
                    if (book.progress > 0 && book.progress < 1.0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GlassContainer(
                          height: 4,
                          blur: 0,
                          opacity: 0.3,
                          borderRadius: 0,
                          child: LinearPercentIndicator(
                            lineHeight: 4.0,
                            percent: book.progress,
                            backgroundColor: Colors.transparent,
                            progressColor: YomuConstants.accent,
                            barRadius: const Radius.circular(0),
                            padding: EdgeInsets.zero,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: YomuConstants.textSecondary,
              ),
            ),
            // Progress information for books in progress
            if (book.progress > 0 && book.progress < 1.0) ...[
              const SizedBox(height: 4),
              Text(
                '${(book.progress * 100).toStringAsFixed(0)}% complete',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: YomuConstants.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (book.totalPages > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Page ${book.currentPage + 1} of ${book.totalPages}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: YomuConstants.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              if (book.estimatedReadingMinutes > 0) ...[
                const SizedBox(height: 2),
                Text(
                  _formatReadingTime(book.estimatedReadingMinutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: YomuConstants.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
              if (book.lastReadAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatLastRead(book.lastReadAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: YomuConstants.textSecondary.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatReadingTime(int minutes) {
    if (minutes < 60) {
      return '~$minutes min left';
    } else if (minutes < 1440) {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      if (mins == 0) {
        return '~$hours hr left';
      }
      return '~$hours hr $mins min left';
    } else {
      final days = (minutes / 1440).floor();
      return '~$days day${days > 1 ? 's' : ''} left';
    }
  }

  String _formatLastRead(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return 'Read ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Read ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Read ${difference.inDays}d ago';
    } else {
      return 'Read on ${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
