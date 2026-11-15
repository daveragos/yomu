import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/desktop/page_header.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants.dart';
import '../../../providers/library_provider.dart';

class LibraryHeader extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final GlobalKey? filterKey;

  /// Imports books. Wide windows show it as the header's "Add books" button
  /// (phones use the floating button instead).
  final VoidCallback? onAddBooks;

  /// Key for the "Add books" button, so the first-run tutorial can point at
  /// it in wide windows.
  final GlobalKey? addButtonKey;

  const LibraryHeader({
    super.key,
    required this.searchController,
    this.filterKey,
    this.onAddBooks,
    this.addButtonKey,
  });

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

  static const _statusOptions = [
    ('Reading', BookStatusFilter.reading),
    ('To Read', BookStatusFilter.unread),
    ('Finished', BookStatusFilter.finished),
  ];

  List<Widget> _filterChips(LibraryState state, LibraryNotifier notifier) {
    return [
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
        label: state.selectedFileType == 'All'
            ? 'File Type'
            : state.selectedFileType,
        isSelected: state.selectedFileType != 'All',
        hasDropdown: true,
        dropdownOptions: ['All', 'EPUB', 'PDF'],
        onSelected: (val) => notifier.setFileTypeFilter(val),
        onTap: () {},
      ),
      _FilterChip(
        label: state.selectedTag == 'All'
            ? 'Category'
            : state.selectedTag!,
        isSelected: state.selectedTag != 'All',
        hasDropdown: true,
        dropdownOptions: [
          'All',
          ...state.allBooks
              .where(
                (b) => b.tags != null && b.tags!.isNotEmpty,
              )
              .expand(
                (b) =>
                    b.tags!.split(',').map((e) => e.trim()),
              )
              .where((e) => e.isNotEmpty)
              .toSet(),
        ].toList(),
        onSelected: (val) => notifier.setTagFilter(val),
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
    ];
  }

  /// "12 books · 3 reading", or "3 of 12 books" while filters hide some.
  String _countLabel(LibraryState state) {
    final total = state.allBooks.length;
    if (total == 0) return 'No books yet';
    final shown = state.filteredBooks.length;
    String books(int n) => '$n ${n == 1 ? 'book' : 'books'}';
    if (shown != total) return '$shown of ${books(total)}';
    final reading = state.allBooks
        .where((b) => b.progress > 0 && b.progress < 1)
        .length;
    return reading == 0 ? books(total) : '${books(total)} · $reading reading';
  }

  bool _hasActiveFilters(LibraryState state) =>
      state.selectedAuthor != 'All' ||
      state.selectedFolder != 'All' ||
      state.selectedFileType != 'All' ||
      (state.selectedTag != null && state.selectedTag != 'All') ||
      state.onlyFavorites ||
      state.sortBy != BookSortBy.recent;

  /// Wide windows: a page title with search, filters and "Add books" on the
  /// right, and the reading-status pills always visible beneath it. The
  /// filter chips open under the pills, as they do on phones.
  Widget _buildWide(LibraryState state, LibraryNotifier notifier) {
    final filtersActive = _hasActiveFilters(state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Breakpoints.desktopGutter,
        24,
        Breakpoints.desktopGutter,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPageHeader(
            title: 'Library',
            subtitle: _countLabel(state),
            actions: [
              SizedBox(
                width: 300,
                child: _DesktopSearchField(
                  controller: widget.searchController,
                  onChanged: notifier.setSearchQuery,
                ),
              ),
              _DesktopIconButton(
                key: widget.filterKey,
                icon: Icons.tune_rounded,
                tooltip: _isExpanded ? 'Hide filters' : 'Filter and sort',
                isActive: _isExpanded || filtersActive,
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
              if (widget.onAddBooks != null)
                DesktopPrimaryButton(
                  key: widget.addButtonKey,
                  icon: Icons.add_rounded,
                  label: 'Add books',
                  onPressed: widget.onAddBooks!,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatusPill(
                label: 'All',
                isSelected: state.statusFilter == BookStatusFilter.all,
                onTap: () => notifier.setStatusFilter(BookStatusFilter.all),
              ),
              for (final (label, filter) in _statusOptions)
                _StatusPill(
                  label: label,
                  isSelected: state.statusFilter == filter,
                  onTap: () => notifier.setStatusFilter(filter),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Wrap(
                      runSpacing: 8,
                      children: _filterChips(state, notifier),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    if (Breakpoints.isWide(context)) return _buildWide(state, notifier);

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
                      key: widget.filterKey,
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
                      children: _filterChips(state, notifier),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (label, filter) in _statusOptions)
                        _StatusTab(
                          label,
                          state.statusFilter == filter,
                          () => notifier.setStatusFilter(filter),
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
              (label == 'Author' && opt == 'All') ||
              (label == 'File Type' && opt == 'All') ||
              (label == 'Category' && opt == 'All') ||
              (label == 'Folder' && opt == 'All');
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

/// Compact search box for the wide header, sized to sit beside buttons.
class _DesktopSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _DesktopSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );

    return SizedBox(
      height: 46,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: YomuConstants.textPrimary, fontSize: 14),
          cursorColor: YomuConstants.accent,
          decoration: InputDecoration(
            hintText: 'Search titles, authors...',
            hintStyle: TextStyle(
              color: YomuConstants.textSecondary.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: YomuConstants.textSecondary,
              size: 19,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: YomuConstants.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            enabledBorder: border(Colors.white.withValues(alpha: 0.08)),
            focusedBorder: border(YomuConstants.accent.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}

/// Square glass icon button matching the search field's height.
class _DesktopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _DesktopIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(46, 46),
        foregroundColor: isActive
            ? YomuConstants.accent
            : YomuConstants.textSecondary,
        backgroundColor: isActive
            ? YomuConstants.accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive
                ? YomuConstants.accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}

/// Reading-status choice in the wide layout, left-aligned like tabs in a
/// desktop toolbar rather than stretched across the window.
class _StatusPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? YomuConstants.accent.withValues(alpha: 0.14)
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? YomuConstants.accent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: selected
                    ? YomuConstants.accent
                    : YomuConstants.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
