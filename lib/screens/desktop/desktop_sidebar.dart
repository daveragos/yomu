import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/book_cover_image.dart';
import '../../core/yomu_colors.dart';
import '../../models/book_model.dart';
import '../../providers/library_provider.dart';

/// One place the sidebar can take the reader.
typedef SidebarDestination = ({IconData icon, String label});

/// Navigation for wide windows. Top to bottom: the wordmark, the four
/// destinations, the book being read, and the reader's rank and streak, so
/// the progress Yomu is built around stays in view on every screen.
class DesktopSidebar extends ConsumerWidget {
  final List<SidebarDestination> destinations;
  final List<GlobalKey> destinationKeys;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<Book> onOpenBook;

  static const double width = 248;

  const DesktopSidebar({
    super.key,
    required this.destinations,
    required this.destinationKeys,
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenBook,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final recent = state.allBooks.where((b) => b.lastReadAt != null).toList()
      ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
    final current = recent.isEmpty ? null : recent.first;
    final colors = context.yomu;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.35),
        border: Border(
          right: BorderSide(color: colors.tint(0.06)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Wordmark(),
              const SizedBox(height: 28),
              for (var i = 0; i < destinations.length; i++)
                _NavItem(
                  key: destinationKeys[i],
                  icon: destinations[i].icon,
                  label: destinations[i].label,
                  shortcut: Platform.isMacOS ? '⌘${i + 1}' : 'Ctrl ${i + 1}',
                  isSelected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
              if (current != null) ...[
                const _SectionLabel('Continue reading'),
                const SizedBox(height: 8),
                _ContinueReading(book: current, onTap: () => onOpenBook(current)),
                const SizedBox(height: 16),
              ],
              _RankCard(state: state, onTap: () => onSelect(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Yomu',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '読む',
            style: TextStyle(
              color: colors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.yomu.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final colors = context.yomu;
    final Color background = selected
        ? colors.tint(0.07)
        : _hovered
        ? colors.tint(0.04)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: selected
                      ? colors.accent
                      : colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: selected
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _hovered || selected ? 1 : 0,
                  child: Text(
                    widget.shortcut,
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueReading extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ContinueReading({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = (book.progress * 100).round();
    final colors = context.yomu;
    return Material(
      color: colors.tint(0.03),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 38,
                  height: 56,
                  child: ColoredBox(
                    color: colors.surface,
                    child: BookCoverImage(book: book),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: book.progress.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: colors.tint(0.1),
                              color: colors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// The reader's rank, level progress and streak. Opens Stats.
class _RankCard extends StatelessWidget {
  final LibraryState state;
  final VoidCallback onTap;

  const _RankCard({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Same level math as the dashboard header: 1000 XP per level.
    final levelStart = (state.level - 1) * 1000;
    final progress = ((state.totalXP - levelStart) / 1000).clamp(0.0, 1.0);
    final colors = context.yomu;

    return Material(
      color: colors.tint(0.03),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.tint(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.rankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: state.isStreakActiveToday
                        ? colors.accent
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${state.currentStreak}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LEVEL ${state.level}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${state.totalXP - levelStart} / 1000 XP',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: colors.tint(0.1),
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
