import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import '../models/book_model.dart';
import 'database_service.dart';
import 'package:http/http.dart' as http;

class BookService {
  final DatabaseService _dbService = DatabaseService();

  Future<List<Book>> importBooks() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
      allowMultiple: true,
    );

    List<Book> importedBooks = [];

    if (result != null) {
      for (var path in result.paths) {
        if (path == null) continue;
        File file = File(path);

        // Extract metadata based on extension
        final extension = p.extension(file.path).toLowerCase();
        Book? book;
        if (extension == '.epub') {
          book = await _processEpub(file);
        } else if (extension == '.pdf') {
          book = await _processPdf(file);
        }

        if (book != null) {
          // Check if already in DB
          final existing = await _dbService.getBooks();
          if (!existing.any((b) => b.filePath == book!.filePath)) {
            final id = await _dbService.insertBook(book);
            importedBooks.add(book.copyWith(id: id));
          }
        }
      }
    }
    return importedBooks;
  }

  // Helper method for EPUB processing
  Future<Book?> _processEpub(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      String? coverPath;
      if (epubBook.CoverImage != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final coverFile = File(p.join(directory.path, fileName));

        final image = epubBook.CoverImage!;
        final encodedImage = img.encodeJpg(image);
        await coverFile.writeAsBytes(encodedImage);
        coverPath = coverFile.path;
      }

      return Book(
        title: epubBook.Title ?? p.basenameWithoutExtension(file.path),
        author: epubBook.Author ?? 'Unknown',
        coverPath: coverPath ?? '',
        filePath: file.path,
        folderPath: p.dirname(file.path),
        progress: 0,
        addedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error processing EPUB: $e');
      return null;
    }
  }

  // Helper method for PDF processing
  Future<Book?> _processPdf(File file) async {
    return Book(
      title: p.basenameWithoutExtension(file.path),
      author: 'Unknown',
      coverPath: '',
      filePath: file.path,
      folderPath: p.dirname(file.path),
      progress: 0,
      addedAt: DateTime.now(),
    );
  }

  Future<String?> downloadCover(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(p.join(directory.path, fileName));
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      debugPrint('Error downloading cover: $e');
    }
    return null;
  }
}
