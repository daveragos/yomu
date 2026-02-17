import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../components/book_card.dart';
import '../components/glass_container.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'reading_screen.dart';
import 'file_selection_screen.dart';
import './library/widgets/empty_library_view.dart';
import './library/widgets/library_header.dart';
import './library/widgets/add_book_fab.dart';
import 'edit_book_screen.dart';
import '../components/book_overlay_menu.dart';

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
  final Set<int> _selectedBookIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(Book book) {
    if (book.id == null) return;
    setState(() {
      if (_selectedBookIds.contains(book.id)) {
        _selectedBookIds.remove(book.id);
        if (_selectedBookIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBookIds.add(book.id!);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBookIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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
                if (_isSelectionMode)
                  _buildSelectionHeader()
                else
                  LibraryHeader(searchController: _searchController),
                Expanded(
                  child: state.allBooks.isEmpty
                      ? EmptyLibraryView(onImportFiles: _handleSelectiveImport)
                      : _buildBookGrid(state.filteredBooks),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom - 30,
        ),
        child: AddBookFab(
          isMenuOpen: _isMenuOpen,
          animationController: _animationController,
          onToggleMenu: _toggleMenu,
          onScanFolder: () {
            _toggleMenu();
            ref.read(libraryProvider.notifier).scanFolder();
          },
          onImportFiles: () {
            _toggleMenu();
            _handleSelectiveImport();
          },
        ),
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isSelected = _selectedBookIds.contains(book.id);
        return BookCard(
          book: book,
          isSelected: isSelected,
          selectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(book);
            } else {
              _showBookDetails(book);
            }
          },
          onLongPress: (pos) {
            if (!_isSelectionMode) {
              _toggleSelection(book);
            } else {
              _showBookOptions(book, pos);
            }
          },
          onMenuPressed: (pos) => _showBookOptions(book, pos),
        );
      },
    );
  }

  Widget _buildSelectionHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 12,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _clearSelection,
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedBookIds.length} selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Select All',
              icon: const Icon(Icons.select_all, color: Colors.white70),
              onPressed: () {
                setState(() {
                  final filteredBooks = ref.read(libraryProvider).filteredBooks;
                  for (final book in filteredBooks) {
                    if (book.id != null) _selectedBookIds.add(book.id!);
                  }
                  _isSelectionMode = true;
                });
              },
            ),
            IconButton(
              tooltip: 'Remove Selected',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _handleBatchDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _handleBatchDelete() async {
    if (_selectedBookIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: YomuConstants.surface,
        title: const Text(
          'Remove Books',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${_selectedBookIds.length} books? Your reading progress and history will be kept if you re-import them.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = ref.read(libraryProvider.notifier);
      for (final id in _selectedBookIds) {
        notifier.deleteBook(id);
      }
      _clearSelection();
    }
  }

  void _showBookDetails(Book book) {
    ref.read(currentlyReadingProvider.notifier).state = book;
    ref.read(libraryProvider.notifier).markBookAsOpened(book);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadingScreen()),
    );
  }

  void _showBookOptions(Book book, Offset tapPosition) {
    BookOverlayMenu.show(
      context: context,
      book: book,
      position: tapPosition,
      onAction: (action) {
        switch (action) {
          case 'favorite':
            ref.read(libraryProvider.notifier).toggleBookFavorite(book);
            break;
          case 'edit':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditBookScreen(book: book),
              ),
            );
            break;
          case 'delete':
            _showDeleteConfirmation(book);
            break;
        }
      },
    );
  }

  void _showDeleteConfirmation(Book book) async {
    bool deleteHistory = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: YomuConstants.surface,
            title: const Text(
              'Remove Book',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to remove "${book.title}"?',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Remove reading history',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  value: deleteHistory,
                  activeColor: YomuConstants.accent,
                  onChanged: (val) {
                    setDialogState(() {
                      deleteHistory = val ?? false;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      ref
          .read(libraryProvider.notifier)
          .deleteBook(book.id!, deleteHistory: deleteHistory);
    }
  }
}
