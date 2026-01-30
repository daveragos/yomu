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
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => notifier.clearFilters(),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    borderRadius: 12,
                    color: YomuConstants.accent,
                    child: const Text(
                      'All',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  'Genre',
                  state.selectedGenre,
                  [
                    'All',
                    ...state.allBooks.map((b) => b.genre ?? 'Unknown').toSet(),
                  ],
                  (val) => notifier.setGenreFilter(val),
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  'Author',
                  state.selectedAuthor,
                  ['All', ...state.allBooks.map((b) => b.author).toSet()],
                  (val) => notifier.setAuthorFilter(val),
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  'Folder',
                  state.selectedFolder,
                  [
                    'All',
                    ...state.allBooks
                        .map((b) => b.folderPath)
                        .whereType<String>()
                        .toSet(),
                  ],
                  (val) => notifier.setFolderFilter(val),
                  labelBuilder: (path) =>
                      path == 'All' ? 'Folder' : p.basename(path),
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  'Sort',
                  state.sortBy.name.toUpperCase(),
                  BookSortBy.values.map((v) => v.name.toUpperCase()).toList(),
                  (val) => notifier.setSortBy(
                    BookSortBy.values.firstWhere(
                      (e) => e.name.toUpperCase() == val,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusTab(
                'All',
                state.statusFilter == BookStatusFilter.all,
                () => notifier.setStatusFilter(BookStatusFilter.all),
              ),
              const SizedBox(width: 12),
              _buildStatusTab(
                'Reading',
                state.statusFilter == BookStatusFilter.reading,
                () => notifier.setStatusFilter(BookStatusFilter.reading),
              ),
              const SizedBox(width: 12),
              _buildStatusTab(
                'Unread',
                state.statusFilter == BookStatusFilter.unread,
                () => notifier.setStatusFilter(BookStatusFilter.unread),
              ),
              const SizedBox(width: 12),
              _buildStatusTab(
                'Finished',
                state.statusFilter == BookStatusFilter.finished,
                () => notifier.setStatusFilter(BookStatusFilter.finished),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<String> options,
    Function(String) onChanged, {
    String Function(String)? labelBuilder,
  }) {
    final isDefault =
        selectedValue == 'All' ||
        selectedValue == 'TITLE' ||
        selectedValue == 'RECENT' ||
        selectedValue == 'AUTHOR';
    final displayText = isDefault
        ? label
        : (labelBuilder != null ? labelBuilder(selectedValue) : selectedValue);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      borderRadius: 12,
      color: isDefault ? YomuConstants.surface : YomuConstants.accent,
      opacity: isDefault ? 0.5 : 0.9,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: isDefault ? Colors.white54 : Colors.black54,
          ),
          style: TextStyle(
            color: isDefault ? Colors.white : Colors.black,
            fontSize: 13,
            fontWeight: isDefault ? FontWeight.normal : FontWeight.bold,
          ),
          dropdownColor: YomuConstants.surface,
          borderRadius: BorderRadius.circular(12),
          selectedItemBuilder: (context) {
            return options.map((opt) {
              return Center(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: isDefault ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList();
          },
          items: options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(labelBuilder != null ? labelBuilder(opt) : opt),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          hint: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _buildStatusTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: YomuConstants.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
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
}
