import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';

import '../models/book_model.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onTap;
  final Function(Offset)? onLongPress;
  final Function(Offset)? onMenuPressed;
  final GlobalKey? menuKey;
  final bool isSelected;
  final bool selectionMode;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.onMenuPressed,
    this.menuKey,
    this.isSelected = false,
    this.selectionMode = false,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _tapPosition = details.globalPosition;
        });
      },
      onTap: widget.onTap,
      onLongPress: () {
        if (widget.onLongPress != null) widget.onLongPress!(_tapPosition);
      },
      child: GlassContainer(
        width: 150,
        padding: const EdgeInsets.all(8),
        borderRadius: YomuConstants.borderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  YomuConstants.borderRadius - 4,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.book.coverPath.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: widget.book.coverPath,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: YomuConstants.surface),
                            errorWidget: (context, url, error) => Padding(
                              padding: const EdgeInsets.all(50.0),
                              child: Image.asset(
                                'assets/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : widget.book.coverPath.isNotEmpty
                        ? Image.file(
                            File(widget.book.coverPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Padding(
                                  padding: const EdgeInsets.all(50.0),
                                  child: Image.asset(
                                    'assets/icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                    // New Tag
                    if (widget.book.progress == 0)
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
                    if (widget.book.isFavorite)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    // Selection Overlay
                    if (widget.selectionMode)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? YomuConstants.accent.withValues(alpha: 0.3)
                                : Colors.black26,
                          ),
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.isSelected
                                    ? YomuConstants.accent
                                    : Colors.white24,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                widget.isSelected ? Icons.check : Icons.add,
                                color: widget.isSelected
                                    ? Colors.black
                                    : Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        widget.book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: YomuConstants.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onMenuPressed != null && !widget.selectionMode)
                  InkWell(
                    key: widget.menuKey,
                    onTapDown: (details) {
                      setState(() {
                        _tapPosition = details.globalPosition;
                      });
                    },
                    onTap: () => widget.onMenuPressed!(_tapPosition),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: YomuConstants.textSecondary.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Progress information for books in progress
            if (widget.book.progress > 0 && widget.book.progress < 1.0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.book.progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          YomuConstants.accent,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(widget.book.progress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: YomuConstants.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.book.totalPages > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${widget.book.filePath.toLowerCase().endsWith('.epub') ? 'Chapter' : 'Page'} ${widget.book.currentPage + 1} of ${widget.book.totalPages}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: YomuConstants.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              if (widget.book.estimatedReadingMinutes > 0) ...[
                const SizedBox(height: 2),
                Text(
                  _formatReadingTime(widget.book.estimatedReadingMinutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: YomuConstants.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
              if (widget.book.lastReadAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatLastRead(widget.book.lastReadAt!),
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
