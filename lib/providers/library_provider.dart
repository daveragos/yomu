import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/book_model.dart';
import '../services/database_service.dart';
import '../services/book_service.dart';

enum BookSortBy { title, author, recent }

enum BookStatusFilter { all, unread, reading, finished }

class LibraryState {
  final List<Book> allBooks;
  final List<Book> filteredBooks;
  final String searchQuery;
  final bool isLoading;
  final String selectedAuthor;
  final String selectedFolder;
  final BookStatusFilter statusFilter;
  final bool onlyFavorites;
  final String? selectedSeries;
  final String? selectedTag;
  final BookSortBy sortBy;
  final bool sortAscending;

  LibraryState({
    required this.allBooks,
    required this.filteredBooks,
    this.searchQuery = '',
    this.isLoading = false,
    this.selectedAuthor = 'All',
    this.selectedFolder = 'All',
    this.statusFilter = BookStatusFilter.all,
    this.onlyFavorites = false,
    this.selectedSeries = 'All',
    this.selectedTag = 'All',
    this.sortBy = BookSortBy.recent,
    this.sortAscending = false,
  });

  LibraryState copyWith({
    List<Book>? allBooks,
    List<Book>? filteredBooks,
    String? searchQuery,
    bool? isLoading,
    String? selectedAuthor,
    String? selectedFolder,
    BookStatusFilter? statusFilter,
    bool? onlyFavorites,
    String? selectedSeries,
    String? selectedTag,
    BookSortBy? sortBy,
    bool? sortAscending,
  }) {
    return LibraryState(
      allBooks: allBooks ?? this.allBooks,
      filteredBooks: filteredBooks ?? this.filteredBooks,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      selectedAuthor: selectedAuthor ?? this.selectedAuthor,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      statusFilter: statusFilter ?? this.statusFilter,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      selectedSeries: selectedSeries ?? this.selectedSeries,
      selectedTag: selectedTag ?? this.selectedTag,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  return LibraryNotifier();
});

class LibraryNotifier extends StateNotifier<LibraryState> {
  final DatabaseService _dbService = DatabaseService();
  final BookService _bookService = BookService();

  LibraryNotifier()
    : super(
        LibraryState(
          allBooks: [],
          filteredBooks: [],
          searchQuery: '',
          isLoading: true,
          selectedAuthor: 'All',
          selectedFolder: 'All',
          statusFilter: BookStatusFilter.all,
          onlyFavorites: false,
          selectedSeries: 'All',
          selectedTag: 'All',
          sortBy: BookSortBy.recent,
          sortAscending: false,
        ),
      ) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true);
    final books = await _dbService.getBooks();
    state = state.copyWith(
      allBooks: books,
      filteredBooks: _applyFilters(books, state),
      isLoading: false,
    );
  }

  void setSearchQuery(String query) {
    final newState = state.copyWith(searchQuery: query);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setSortBy(BookSortBy sortBy) {
    final newState = state.copyWith(sortBy: sortBy);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void toggleSortOrder() {
    final newState = state.copyWith(sortAscending: !state.sortAscending);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setStatusFilter(BookStatusFilter filter) {
    final newState = state.copyWith(statusFilter: filter);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void toggleFavoriteOnly() {
    final newState = state.copyWith(onlyFavorites: !state.onlyFavorites);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setAuthorFilter(String author) {
    final newState = state.copyWith(selectedAuthor: author);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setFolderFilter(String folder) {
    final newState = state.copyWith(selectedFolder: folder);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setSeriesFilter(String series) {
    final newState = state.copyWith(selectedSeries: series);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  void setTagFilter(String tag) {
    final newState = state.copyWith(selectedTag: tag);
    state = newState.copyWith(
      filteredBooks: _applyFilters(state.allBooks, newState),
    );
  }

  List<Book> _applyFilters(List<Book> books, LibraryState currentState) {
    List<Book> filtered = List.from(books);

    // 1. Search filter
    if (currentState.searchQuery.isNotEmpty) {
      final query = currentState.searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (b) =>
                b.title.toLowerCase().contains(query) ||
                b.author.toLowerCase().contains(query),
          )
          .toList();
    }

    // 2. Author filter
    if (currentState.selectedAuthor != 'All') {
      filtered = filtered
          .where((b) => b.author == currentState.selectedAuthor)
          .toList();
    }

    // 3. Status filter
    if (currentState.statusFilter != BookStatusFilter.all) {
      filtered = filtered.where((b) {
        switch (currentState.statusFilter) {
          case BookStatusFilter.unread:
            return b.progress == 0;
          case BookStatusFilter.reading:
            return b.progress > 0 && b.progress < 0.95;
          case BookStatusFilter.finished:
            return b.progress >= 0.95;
          default:
            return true;
        }
      }).toList();
    }

    // 4. Favorites filter
    if (currentState.onlyFavorites) {
      filtered = filtered.where((b) => b.isFavorite).toList();
    }

    // 5. Folder filter
    if (currentState.selectedFolder != 'All') {
      filtered = filtered
          .where((b) => b.folderPath == currentState.selectedFolder)
          .toList();
    }

    // 6. Series filter
    if (currentState.selectedSeries != 'All') {
      filtered = filtered
          .where((b) => b.series == currentState.selectedSeries)
          .toList();
    }

    // 7. Tags filter
    if (currentState.selectedTag != 'All') {
      filtered = filtered
          .where(
            (b) =>
                b.tags != null &&
                b.tags!.split(',').contains(currentState.selectedTag),
          )
          .toList();
    }

    // 8. Sorting
    filtered.sort((a, b) {
      int cmp;
      switch (currentState.sortBy) {
        case BookSortBy.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case BookSortBy.author:
          cmp = a.author.toLowerCase().compareTo(b.author.toLowerCase());
          break;
        case BookSortBy.recent:
          cmp = a.addedAt.compareTo(b.addedAt);
          break;
      }
      return currentState.sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  Future<void> importFiles(List<String> paths) async {
    state = state.copyWith(isLoading: true);
    for (var path in paths) {
      final file = io.File(path);
      final book = await _bookService.processFile(file);
      if (book != null) {
        final existing = await _dbService.getBooks();
        if (!existing.any((b) => b.filePath == book.filePath)) {
          final bookToInsert = book.copyWith(folderPath: p.dirname(path));
          await _dbService.insertBook(bookToInsert);
        }
      }
    }
    await loadBooks();
  }

  Future<void> scanFolder() async {
    state = state.copyWith(isLoading: true);
    final newBooks = await _bookService.scanDirectory();
    if (newBooks.isNotEmpty) {
      await loadBooks();
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteBook(int id) async {
    await _dbService.deleteBook(id);
    await loadBooks();
  }

  Future<void> toggleBookFavorite(Book book) async {
    final updatedBook = book.copyWith(isFavorite: !book.isFavorite);
    await _dbService.updateBook(updatedBook);
    await loadBooks();
  }

  void clearFilters() {
    state = LibraryState(
      allBooks: state.allBooks,
      filteredBooks: state.allBooks,
      isLoading: false,
      searchQuery: '',
      selectedAuthor: 'All',
      selectedFolder: 'All',
      statusFilter: BookStatusFilter.all,
      onlyFavorites: false,
      selectedSeries: 'All',
      selectedTag: 'All',
      sortBy: BookSortBy.recent,
      sortAscending: false,
    );
  }
}
