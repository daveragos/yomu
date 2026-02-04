import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../components/book_card.dart';

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
          // Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
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
          const SizedBox(height: 16),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected:
                      state.selectedGenre == 'All' &&
                      state.selectedAuthor == 'All' &&
                      state.selectedFolder == 'All' &&
                      !state.onlyFavorites,
                  onTap: () => notifier.clearFilters(),
                ),
                _buildFilterChip(
                  label: 'Favorites',
                  isSelected: state.onlyFavorites,
                  icon: state.onlyFavorites
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onTap: () => notifier.toggleFavoriteOnly(),
                ),
                _buildFilterChip(
                  label: state.selectedGenre == 'All'
                      ? 'Genre'
                      : state.selectedGenre,
                  isSelected: state.selectedGenre != 'All',
                  hasDropdown: true,
                  dropdownOptions: [
                    'All',
                    ...state.allBooks.map((b) => b.genre ?? 'Unknown').toSet(),
                  ].toList(),
                  onSelected: (val) => notifier.setGenreFilter(val),
                  onTap: () {},
                ),
                _buildFilterChip(
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
                _buildFilterChip(
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
              _buildStatusTab(
                'Reading',
                state.statusFilter == BookStatusFilter.reading,
                () => notifier.setStatusFilter(BookStatusFilter.reading),
              ),
              _buildStatusTab(
                'To Read',
                state.statusFilter == BookStatusFilter.unread,
                () => notifier.setStatusFilter(BookStatusFilter.unread),
              ),
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    bool hasDropdown = false,
    List<String>? dropdownOptions,
    Function(String)? onSelected,
    required VoidCallback onTap,
  }) {
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
        itemBuilder: (context) => dropdownOptions.map((opt) {
          final isItemSelected =
              opt == label ||
              (label == 'Genre' && opt == 'All') ||
              (label == 'Author' && opt == 'All');
          return PopupMenuItem<String>(
            value: opt,
            child: Text(
              opt,
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
                'Remove Book',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Book'),
                    content: Text(
                      'Are you sure you want to remove "${book.title}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Remove',
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
