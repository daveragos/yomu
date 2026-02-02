import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../components/book_card.dart';
import '../components/glass_container.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'edit_book_screen.dart';
import 'file_selection_screen.dart';
import 'reading_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isMenuOpen = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

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
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    return Scaffold(
      backgroundColor: YomuConstants.background,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildLibraryHeader(context, state, notifier),
                Expanded(
                  child: state.allBooks.isEmpty
                      ? _buildEmptyState()
                      : _buildBookGrid(state.filteredBooks),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: _buildAnimatedFAB(),
      ),
    );
  }

  Widget _buildLibraryHeader(
    BuildContext context,
    LibraryState state,
    LibraryNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Library',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 28),
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
            ],
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search books...',
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: YomuConstants.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) => notifier.setSearchQuery(value),
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showFilterExplorer(context, state, notifier),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: 12,
                  color: YomuConstants.accent,
                  opacity: 0.9,
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_getActiveFilterCount(state) > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_getActiveFilterCount(state)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (state.selectedGenre != 'All')
                        _buildActiveFilterTag(
                          state.selectedGenre,
                          () => notifier.setGenreFilter('All'),
                        ),
                      if (state.selectedAuthor != 'All')
                        _buildActiveFilterTag(
                          state.selectedAuthor,
                          () => notifier.setAuthorFilter('All'),
                        ),
                      if (state.selectedFolder != 'All')
                        _buildActiveFilterTag(
                          p.basename(state.selectedFolder),
                          () => notifier.setFolderFilter('All'),
                        ),
                      if (state.sortBy != BookSortBy.recent)
                        _buildActiveFilterTag(
                          state.sortBy.name.toUpperCase(),
                          () => notifier.setSortBy(BookSortBy.recent),
                        ),
                      if (state.searchQuery.isNotEmpty)
                        _buildActiveFilterTag(
                          'Search: ${state.searchQuery}',
                          () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusTab(
                'All',
                state.statusFilter == BookStatusFilter.all,
                () => notifier.setStatusFilter(BookStatusFilter.all),
              ),
              _buildStatusTab(
                'Reading',
                state.statusFilter == BookStatusFilter.reading,
                () => notifier.setStatusFilter(BookStatusFilter.reading),
              ),
              _buildStatusTab(
                'Unread',
                state.statusFilter == BookStatusFilter.unread,
                () => notifier.setStatusFilter(BookStatusFilter.unread),
              ),
              _buildStatusTab(
                'Finished',
                state.statusFilter == BookStatusFilter.finished,
                () => notifier.setStatusFilter(BookStatusFilter.finished),
              ),
              _buildStatusTab(
                'Favorites',
                state.onlyFavorites,
                () => notifier.toggleFavoriteOnly(),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, bool isSelected, VoidCallback onTap) {
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
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
    ref.read(currentlyReadingProvider.notifier).state = book;
    ref.read(libraryProvider.notifier).markBookAsOpened(book);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadingScreen()),
    );
  }

  Widget _buildAnimatedFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isMenuOpen) ...[
          FloatingActionButton.small(
            onPressed: () {
              _toggleMenu();
              ref.read(libraryProvider.notifier).scanFolder();
            },
            backgroundColor: YomuConstants.surface,
            child: const Icon(Icons.folder_open, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            onPressed: () {
              _toggleMenu();
              _handleSelectiveImport();
            },
            backgroundColor: YomuConstants.surface,
            child: const Icon(Icons.file_open, color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: _toggleMenu,
          backgroundColor: YomuConstants.accent,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animationController.value * (3.14159 / 4), // 45 degrees
                child: const Icon(Icons.add, color: Colors.black, size: 28),
              );
            },
          ),
        ),
      ],
    );
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

  int _getActiveFilterCount(LibraryState state) {
    int count = 0;
    if (state.selectedGenre != 'All') count++;
    if (state.selectedAuthor != 'All') count++;
    if (state.selectedFolder != 'All') count++;
    if (state.sortBy != BookSortBy.recent) count++;
    if (state.searchQuery.isNotEmpty) count++;
    return count;
  }

  Widget _buildActiveFilterTag(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  void _showFilterExplorer(
    BuildContext context,
    LibraryState state,
    LibraryNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final tempState = ref.watch(libraryProvider);
          return GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Explorer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_getActiveFilterCount(tempState) > 0)
                      TextButton(
                        onPressed: () {
                          notifier.clearFilters();
                          setModalState(() {});
                        },
                        child: Text(
                          'Reset All',
                          style: TextStyle(color: YomuConstants.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildExplorerSection(
                  'Genre',
                  tempState.selectedGenre,
                  [
                    'All',
                    ...tempState.allBooks
                        .map((b) => b.genre ?? 'Unknown')
                        .toSet(),
                  ],
                  (val) {
                    notifier.setGenreFilter(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 20),
                _buildExplorerSection(
                  'Author',
                  tempState.selectedAuthor,
                  ['All', ...tempState.allBooks.map((b) => b.author).toSet()],
                  (val) {
                    notifier.setAuthorFilter(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 20),
                _buildExplorerSection(
                  'Folder',
                  tempState.selectedFolder,
                  [
                    'All',
                    ...tempState.allBooks
                        .map((b) => b.folderPath)
                        .whereType<String>()
                        .toSet(),
                  ],
                  (val) {
                    notifier.setFolderFilter(val);
                    setModalState(() {});
                  },
                  labelBuilder: (path) =>
                      path == 'All' ? 'All Folders' : p.basename(path),
                ),
                const SizedBox(height: 20),
                _buildExplorerSection(
                  'Sort By',
                  tempState.sortBy.name.toUpperCase(),
                  BookSortBy.values.map((v) => v.name.toUpperCase()).toList(),
                  (val) {
                    notifier.setSortBy(
                      BookSortBy.values.firstWhere(
                        (e) => e.name.toUpperCase() == val,
                      ),
                    );
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YomuConstants.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Show ${tempState.filteredBooks.length} Results',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplorerSection(
    String title,
    String currentVal,
    List<String> options,
    Function(String) onSelected, {
    String Function(String)? labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = opt == currentVal;
              return GestureDetector(
                onTap: () => onSelected(opt),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? YomuConstants.accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? YomuConstants.accent : Colors.white10,
                    ),
                  ),
                  child: Text(
                    labelBuilder != null ? labelBuilder(opt) : opt,
                    style: TextStyle(
                      color: isSelected ? YomuConstants.accent : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
