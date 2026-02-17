import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../reading_screen.dart';

class ContinueReadingCard extends ConsumerStatefulWidget {
  final Book book;
  final Function(Offset)? onLongPress;
  final Function(Offset)? onMenuPressed;

  const ContinueReadingCard({
    super.key,
    required this.book,
    this.onLongPress,
    this.onMenuPressed,
  });

  @override
  ConsumerState<ContinueReadingCard> createState() =>
      _ContinueReadingCardState();
}

class _ContinueReadingCardState extends ConsumerState<ContinueReadingCard> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _tapPosition = details.globalPosition;
        });
      },
      onTap: () {
        ref.read(currentlyReadingProvider.notifier).state = widget.book;
        ref.read(libraryProvider.notifier).markBookAsOpened(widget.book);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReadingScreen()),
        );
      },
      onLongPress: () {
        if (widget.onLongPress != null) widget.onLongPress!(_tapPosition);
      },
      onSecondaryTapDown: (details) {
        setState(() {
          _tapPosition = details.globalPosition;
        });
      },
      onSecondaryTap: () {
        if (widget.onLongPress != null) widget.onLongPress!(_tapPosition);
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
                color: YomuConstants.surface,
                boxShadow: YomuConstants.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.book.coverPath.startsWith('assets')
                    ? Image.asset(
                        widget.book.coverPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : Image.file(
                        File(widget.book.coverPath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.book.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.onMenuPressed != null)
                        InkWell(
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
                              color: YomuConstants.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    widget.book.author,
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
                          value: widget.book.progress,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            YomuConstants.accent,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(widget.book.progress * 100).toInt()}%',
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
