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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _scanKey = GlobalKey();
  final GlobalKey _importKey = GlobalKey();
  final GlobalKey _firstBookMenuKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();

  bool _fabTutorialShown = true;
  bool _menuTutorialShown = true;
  bool _bookCardTutorialShown = true;

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
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final isMainFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (isMainFirstLaunch) return;

    _fabTutorialShown = !(prefs.getBool('is_first_launch_library_fab') ?? true);
    _menuTutorialShown =
        !(prefs.getBool('is_first_launch_library_menu') ?? true);
    _bookCardTutorialShown =
        !(prefs.getBool('is_first_launch_library_book_card') ?? true);

    if (!_fabTutorialShown) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showFabTutorial();
      });
    } else if (!_bookCardTutorialShown) {
      final state = ref.read(libraryProvider);
      if (state.allBooks.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showBookCardTutorial();
        });
      }
    }
  }

  void _showFabTutorial() {
    final targets = [
      TargetFocus(
        identify: "filter_target",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    "Filter & Sort",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to filter your library by genre, author, folder, or sorting method.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.right,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "fab_target",
        keyTarget: _fabKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    "Add Books",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap the + button to add new books to your library.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.right,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: YomuConstants.background,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _setFabTutorialShown,
      onSkip: () {
        _setFabTutorialShown();
        return true;
      },
    ).show(context: context);
  }

  void _setFabTutorialShown() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_first_launch_library_fab', false);
    });
    _fabTutorialShown = true;
    final state = ref.read(libraryProvider);
    if (!_bookCardTutorialShown && state.allBooks.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showBookCardTutorial();
      });
    }
  }

  void _showMenuTutorial() {
    final targets = [
      TargetFocus(
        identify: "scan_target",
        keyTarget: _scanKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  "Scan Folder",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Automatically detects and adds all supported books from a folder you choose.",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "import_target",
        keyTarget: _importKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  "Select Files",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Manually pick specific EPUB or PDF files to import.",
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: YomuConstants.background,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _setMenuTutorialShown,
      onSkip: () {
        _setMenuTutorialShown();
        return true;
      },
    ).show(context: context);
  }

  void _setMenuTutorialShown() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_first_launch_library_menu', false);
    });
    _menuTutorialShown = true;
  }

  void _showBookCardTutorial() {
    final targets = [
      TargetFocus(
        identify: "book_menu_target",
        keyTarget: _firstBookMenuKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Edit Book Info",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Tap the three dots to edit the book's cover, title, or author.\n\nLong-pressing the card is used to select multiple books!",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: YomuConstants.background,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _setBookCardTutorialShown,
      onSkip: () {
        _setBookCardTutorialShown();
        return true;
      },
    ).show(context: context);
  }

  void _setBookCardTutorialShown() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_first_launch_library_book_card', false);
    });
    _bookCardTutorialShown = true;
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
        if (!_menuTutorialShown) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showMenuTutorial();
          });
        }
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

    ref.listen(libraryProvider, (previous, next) {
      if (_fabTutorialShown &&
          !_bookCardTutorialShown &&
          (previous == null || previous.allBooks.isEmpty) &&
          next.allBooks.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showBookCardTutorial();
        });
      }
    });

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
                  LibraryHeader(
                    searchController: _searchController,
                    filterKey: _filterKey,
                  ),
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
          key: _fabKey,
          scanKey: _scanKey,
          importKey: _importKey,
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
          menuKey: index == 0 ? _firstBookMenuKey : null,
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
