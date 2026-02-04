import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../providers/library_provider.dart';

class LibraryHeader extends ConsumerStatefulWidget {
  final TextEditingController searchController;

  const LibraryHeader({super.key, required this.searchController});

  @override
  ConsumerState<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends ConsumerState<LibraryHeader> {
  bool _isExpanded = false;

  String _getShortPath(String path) {
    if (path == 'All') return 'All';
    final parts = path.split(RegExp(r'[/\\]'));
    if (parts.length <= 2) return path;
    return parts.sublist(parts.length - 2).join('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    hintText: 'Search titles, authors...',
                    hintStyle: TextStyle(
                      color: YomuConstants.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: YomuConstants.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.tune_rounded,
                        color: _isExpanded
                            ? YomuConstants.accent
                            : YomuConstants.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                    ),
                    filled: true,
                    fillColor: YomuConstants.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => notifier.setSearchQuery(value),
                ),
              ),
            ],
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Container(
              height: _isExpanded ? null : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected:
                              state.selectedGenre == 'All' &&
                              state.selectedAuthor == 'All' &&
                              state.selectedFolder == 'All' &&
                              !state.onlyFavorites,
                          onTap: () => notifier.clearFilters(),
                        ),
                        _FilterChip(
                          label: 'Favorites',
                          isSelected: state.onlyFavorites,
                          icon: state.onlyFavorites
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          onTap: () => notifier.toggleFavoriteOnly(),
                        ),
                        _FilterChip(
                          label: state.selectedGenre == 'All'
                              ? 'Genre'
                              : state.selectedGenre,
                          isSelected: state.selectedGenre != 'All',
                          hasDropdown: true,
                          dropdownOptions: [
                            'All',
                            ...state.allBooks
                                .map((b) => b.genre ?? 'Unknown')
                                .toSet(),
                          ].toList(),
                          onSelected: (val) => notifier.setGenreFilter(val),
                          onTap: () {},
                        ),
                        _FilterChip(
                          label: state.selectedAuthor == 'All'
                              ? 'Author'
                              : state.selectedAuthor,
                          isSelected: state.selectedAuthor != 'All',
                          hasDropdown: true,
                          dropdownOptions: [
                            'All',
                            ...state.allBooks.map((b) => b.author).toSet(),
                          ].toList(),
                          onSelected: (val) => notifier.setAuthorFilter(val),
                          onTap: () {},
                        ),
                        _FilterChip(
                          label: state.selectedFolder == 'All'
                              ? 'Folder'
                              : _getShortPath(state.selectedFolder),
                          isSelected: state.selectedFolder != 'All',
                          hasDropdown: true,
                          dropdownOptions: [
                            'All',
                            ...state.allBooks
                                .map((b) => b.folderPath)
                                .whereType<String>()
                                .toSet(),
                          ].toList(),
                          labelMapper: _getShortPath,
                          onSelected: (val) => notifier.setFolderFilter(val),
                          onTap: () {},
                        ),
                        _FilterChip(
                          label: state.sortBy.name.toUpperCase(),
                          isSelected: state.sortBy != BookSortBy.recent,
                          icon: Icons.sort_rounded,
                          hasDropdown: true,
                          dropdownOptions: BookSortBy.values
                              .map((v) => v.name.toUpperCase())
                              .toList(),
                          onSelected: (val) {
                            notifier.setSortBy(
                              BookSortBy.values.firstWhere(
                                (e) => e.name.toUpperCase() == val,
                              ),
                            );
                          },
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatusTab(
                        'Reading',
                        state.statusFilter == BookStatusFilter.reading,
                        () =>
                            notifier.setStatusFilter(BookStatusFilter.reading),
                      ),
                      _StatusTab(
                        'To Read',
                        state.statusFilter == BookStatusFilter.unread,
                        () => notifier.setStatusFilter(BookStatusFilter.unread),
                      ),
                      _StatusTab(
                        'Finished',
                        state.statusFilter == BookStatusFilter.finished,
                        () =>
                            notifier.setStatusFilter(BookStatusFilter.finished),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData? icon;
  final bool hasDropdown;
  final List<String>? dropdownOptions;
  final String Function(String)? labelMapper;
  final Function(String)? onSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.icon,
    this.hasDropdown = false,
    this.dropdownOptions,
    this.labelMapper,
    this.onSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipContent = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? YomuConstants.accent : YomuConstants.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : YomuConstants.textSecondary,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : YomuConstants.textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (hasDropdown) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected ? Colors.white : YomuConstants.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (hasDropdown && dropdownOptions != null && onSelected != null) {
      return PopupMenuButton<String>(
        onSelected: onSelected,
        offset: const Offset(0, 44),
        color: YomuConstants.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => (dropdownOptions ?? []).map((opt) {
          final isItemSelected =
              opt == label ||
              (label == 'Genre' && opt == 'All') ||
              (label == 'Author' && opt == 'All');
          return PopupMenuItem<String>(
            value: opt,
            child: Text(
              labelMapper?.call(opt) ?? opt,
              style: TextStyle(
                color: YomuConstants.textPrimary,
                fontSize: 14,
                fontWeight: isItemSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        child: chipContent,
      );
    }

    return GestureDetector(onTap: onTap, child: chipContent);
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusTab(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : YomuConstants.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: YomuConstants.accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: YomuConstants.accent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
