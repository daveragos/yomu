import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/book_cover_image.dart';
import '../../../components/desktop/hover_lift.dart';
import '../../../components/desktop/page_header.dart';
import '../../../components/glass_container.dart';
import '../../../core/yomu_colors.dart';
import '../../../models/book_model.dart';
import '../../../providers/library_provider.dart';
import '../../reading_screen.dart';

/// The wide-window version of the "Continue reading" card: a large cover,
/// the title and progress, and a Resume button.
///
/// Clicking anywhere on the card or on Resume opens the book, as tapping the
/// phone card does. Right-click or the menu button opens the book options.
class ContinueReadingHero extends ConsumerStatefulWidget {
  final Book book;
  final void Function(Offset position) onShowOptions;

  const ContinueReadingHero({
    super.key,
    required this.book,
    required this.onShowOptions,
  });

  @override
  ConsumerState<ContinueReadingHero> createState() =>
      _ContinueReadingHeroState();
}

class _ContinueReadingHeroState extends ConsumerState<ContinueReadingHero> {
  Offset _tapPosition = Offset.zero;

  void _open() {
    ref.read(currentlyReadingProvider.notifier).state = widget.book;
    ref.read(libraryProvider.notifier).markBookAsOpened(widget.book);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final percent = (book.progress * 100).toInt();
    final colors = context.yomu;

    return HoverLift(
      lift: 3,
      child: GestureDetector(
        onTap: _open,
        onSecondaryTapDown: (details) => _tapPosition = details.globalPosition,
        onSecondaryTap: () => widget.onShowOptions(_tapPosition),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 130,
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colors.surface,
                  boxShadow: colors.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BookCoverImage(book: book),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                // At least as tall as the cover, taller when a long title
                // wraps in a narrow column.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 195),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Continue reading',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          _MenuButton(
                            onPressed: (position) =>
                                widget.onShowOptions(position),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: book.progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: colors.tint(0.10),
                                color: colors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DesktopPrimaryButton(
                        icon: Icons.play_arrow_rounded,
                        label: book.progress > 0 ? 'Resume' : 'Start reading',
                        onPressed: _open,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final void Function(Offset position) onPressed;

  const _MenuButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    Offset position = Offset.zero;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTapDown: (details) => position = details.globalPosition,
      onTap: () => onPressed(position),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.more_horiz_rounded,
          color: context.yomu.textSecondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// Shown in place of the hero before any book has been opened.
class ContinueReadingEmpty extends StatelessWidget {
  final VoidCallback onOpenLibrary;

  const ContinueReadingEmpty({super.key, required this.onOpenLibrary});

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.tint(0.05),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: colors.textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick your first book',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open a book from your library and it will wait for you here.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          DesktopPrimaryButton(
            icon: Icons.menu_book_rounded,
            label: 'Open Library',
            onPressed: onOpenLibrary,
          ),
        ],
      ),
    );
  }
}
