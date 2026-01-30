import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../components/book_card.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'edit_book_screen.dart';
import 'file_selection_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  Future<void> _handleSelectiveImport() async {
    final notifier = ref.read(libraryProvider.notifier);
    final bookService = BookService();

    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return;

    final files = await bookService.findBookFiles(directoryPath);
    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No EPUB or PDF files found in this folder.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      final selectedPaths = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FileSelectionScreen(directoryPath: directoryPath, files: files),
        ),
      );

      if (selectedPaths != null && selectedPaths.isNotEmpty) {
        notifier.importFiles(selectedPaths);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    return Scaffold(
      backgroundColor: YomuConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => notifier.setSearchQuery(value),
              )
            : const Text('My Library'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            tooltip: 'Add Books',
            onSelected: (value) {
              if (value == 'file') {
                _handleSelectiveImport();
              } else if (value == 'folder') {
                ref.read(libraryProvider.notifier).scanFolder();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'folder',
                child: Row(
                  children: [
                    Icon(Icons.folder_open),
                    SizedBox(width: 8),
                    Text('Scan Folder'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'file',
                child: Row(
                  children: [
                    Icon(Icons.file_open),
                    SizedBox(width: 8),
                    Text('Import Files'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  notifier.setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const _FilterBottomSheet(),
              );
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.allBooks.isEmpty
          ? _buildEmptyState()
          : _buildBookGrid(state.filteredBooks),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('Your library is empty'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(libraryProvider.notifier).scanFolder(),
                icon: const Icon(Icons.folder_open),
                label: const Text('Scan Folder'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _handleSelectiveImport,
                icon: const Icon(Icons.add),
                label: const Text('Import Files'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => _showBookDetails(book),
          onLongPress: () => _showBookOptions(book),
        );
      },
    );
  }

  void _showBookDetails(Book book) {
    // Navigate to reader
  }

  void _showBookOptions(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: YomuConstants.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
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
      ...state.allBooks.map((b) => b.folderPath).whereType<String>().toSet(),
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
                  onPressed: () => notifier.clearFilters(),
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
              labelBuilder: (path) {
                if (path == 'All') return 'All';
                if (path == 'imported_files') return 'Imported Files';
                return p.basename(path);
              },
            ),

            // Series Section
            _buildDropdownSection(
              context,
              'Filter by Series',
              state.selectedSeries ?? 'All',
              series,
              (val) => notifier.setSeriesFilter(val),
            ),

            // Tags Section
            _buildDropdownSection(
              context,
              'Filter by Tag',
              state.selectedTag ?? 'All',
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
