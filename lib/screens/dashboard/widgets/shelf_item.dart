import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../reading_screen.dart';

class ShelfItem extends ConsumerStatefulWidget {
  final Book book;
  final Function(Offset)? onLongPress;
  final Function(Offset)? onMenuPressed;

  const ShelfItem({
    super.key,
    required this.book,
    this.onLongPress,
    this.onMenuPressed,
  });

  @override
  ConsumerState<ShelfItem> createState() => _ShelfItemState();
}

class _ShelfItemState extends ConsumerState<ShelfItem> {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: YomuConstants.surface,
                  boxShadow: YomuConstants.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
              if (widget.onMenuPressed != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTapDown: (details) {
                      setState(() {
                        _tapPosition = details.globalPosition;
                      });
                    },
                    onTap: () => widget.onMenuPressed!(_tapPosition),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              widget.book.title,
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
