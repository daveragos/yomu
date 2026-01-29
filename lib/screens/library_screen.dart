import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import 'package:path/path.dart' as p;
import '../components/book_card.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import 'edit_book_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final books = libraryState.filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(libraryProvider.notifier).setSearchQuery(value);
                },
              )
            : const Text('My Library'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => ref.read(libraryProvider.notifier).importBook(),
              tooltip: 'Import Book',
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  ref.read(libraryProvider.notifier).setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context, ref, libraryState),
            tooltip: 'Filters & Sorting',
          ),
        ],
      ),
      body: libraryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : books.isEmpty
          ? _buildEmptyState(context, ref)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                YomuConstants.horizontalPadding,
                YomuConstants.horizontalPadding,
                YomuConstants.horizontalPadding,
                100, // Extra padding at bottom for BNB clearance
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () {
                    // Open reading screen
                  },
                  onLongPress: () => _showBookActions(context, ref, book),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: YomuConstants.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: YomuConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => ref.read(libraryProvider.notifier).importBook(),
            style: ElevatedButton.styleFrom(
              backgroundColor: YomuConstants.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Import your first book'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    LibraryState state,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FilterBottomSheet(),
    );
  }

  void _showBookActions(BuildContext context, WidgetRef ref, Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: YomuConstants.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                book.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: book.isFavorite ? Colors.red : null,
              ),
              title: Text(
                book.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
              onTap: () {
                ref.read(libraryProvider.notifier).toggleBookFavorite(book);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Metadata'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditBookScreen(book: book),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Book',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Book'),
                    content: Text(
                      'Are you sure you want to delete "${book.title}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(libraryProvider.notifier).deleteBook(book.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends ConsumerWidget {
  const _FilterBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    // Get unique values for lists
    final authors = ['All', ...state.allBooks.map((b) => b.author).toSet()];
    final folders = [
      'All',
      ...state.allBooks.map((b) => b.folderPath ?? 'Unknown').toSet(),
    ];
    final series = [
      'All',
      ...state.allBooks.map((b) => b.series).whereType<String>().toSet(),
    ];
    final tags = [
      'All',
      ...state.allBooks.expand((b) => b.tags?.split(',') ?? <String>[]).toSet(),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: YomuConstants.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort & Filter',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                TextButton(
                  onPressed: () {
                    notifier.clearFilters();
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const Divider(),

            // Sorting Section
            _buildSection(context, 'Sort By'),
            Wrap(
              spacing: 8,
              children: [
                _buildChip(
                  context,
                  'Title',
                  state.sortBy == BookSortBy.title,
                  () => notifier.setSortBy(BookSortBy.title),
                ),
                _buildChip(
                  context,
                  'Author',
                  state.sortBy == BookSortBy.author,
                  () => notifier.setSortBy(BookSortBy.author),
                ),
                _buildChip(
                  context,
                  'Recent',
                  state.sortBy == BookSortBy.recent,
                  () => notifier.setSortBy(BookSortBy.recent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ascending Order'),
              trailing: Switch(
                value: state.sortAscending,
                onChanged: (_) => notifier.toggleSortOrder(),
              ),
            ),

            const Divider(),

            // Status Section
            _buildSection(context, 'Status'),
            Wrap(
              spacing: 8,
              children: [
                for (final status in BookStatusFilter.values)
                  _buildChip(
                    context,
                    status.name.substring(0, 1).toUpperCase() +
                        status.name.substring(1),
                    state.statusFilter == status,
                    () => notifier.setStatusFilter(status),
                  ),
              ],
            ),

            const Divider(),

            // Favorite Section
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Favorites Only'),
              trailing: Switch(
                value: state.onlyFavorites,
                onChanged: (_) => notifier.toggleFavoriteOnly(),
              ),
            ),

            const Divider(),

            // Author Section
            _buildDropdownSection(
              context,
              'Filter by Author',
              state.selectedAuthor,
              authors,
              (val) => notifier.setAuthorFilter(val),
            ),

            // Folder Section
            _buildDropdownSection(
              context,
              'Filter by Folder',
              state.selectedFolder,
              folders,
              (val) => notifier.setFolderFilter(val),
              labelBuilder: (path) => path == 'All' ? 'All' : p.basename(path),
            ),

            // Series Section
            _buildDropdownSection(
              context,
              'Filter by Series',
              state.selectedSeries,
              series,
              (val) => notifier.setSeriesFilter(val),
            ),

            // Tags Section
            _buildDropdownSection(
              context,
              'Filter by Tag',
              state.selectedTag,
              tags,
              (val) => notifier.setTagFilter(val),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: YomuConstants.accent,
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: YomuConstants.accent.withValues(alpha: 0.2),
      checkmarkColor: YomuConstants.accent,
      labelStyle: TextStyle(
        color: isSelected ? YomuConstants.accent : Colors.white,
      ),
    );
  }

  Widget _buildDropdownSection(
    BuildContext context,
    String title,
    String selectedValue,
    List<String> options,
    Function(String) onChanged, {
    String Function(String)? labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(context, title),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: YomuConstants.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(selectedValue) ? selectedValue : 'All',
              isExpanded: true,
              dropdownColor: YomuConstants.surface,
              items: options
                  .map(
                    (opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        labelBuilder != null ? labelBuilder(opt) : opt,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
