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
import 'package:crypto/crypto.dart';

class BookService {
  final DatabaseService _dbService = DatabaseService();

  Future<Book?> processFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.epub') {
      return await _processEpub(file);
    } else if (extension == '.pdf') {
      return await _processPdf(file);
    }
    return null;
  }

  Future<bool> requestPermissions() async {
    // With SAF/FilePicker, we don't need manifest permissions for individual file access.
    // We only keep this for potential future features or older compatibility if needed.
    return true;
  }

  /// Consistently use a multi-file picker for all devices.
  /// This bypasses OS restrictions on folder access (like Downloads) 
  /// and provides a unified "Add Books" experience.
  Future<List<Book>> scanDirectory() async {
    return await pickBooks();
  }

  Future<List<Book>> pickBooks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('No files picked');
      return [];
    }

    final List<Book> importedBooks = [];
    final existingBooks = await _dbService.getBooks();

    for (var pickedFile in result.files) {
      if (pickedFile.path == null) continue;
      final file = File(pickedFile.path!);

      // Check if already in DB
      if (existingBooks.any((b) => b.filePath == file.path)) {
        debugPrint('Already in library: ${file.path}');
        continue;
      }

      final extension = p.extension(file.path).toLowerCase();
      Book? book;
      if (extension == '.epub') {
        book = await _processEpub(file);
      } else if (extension == '.pdf') {
        book = await _processPdf(file);
      }

      if (book != null) {
        final isDuplicate = existingBooks.any(
          (b) =>
              b.filePath == book!.filePath ||
              (book.contentHash != null && b.contentHash == book.contentHash),
        );

        if (!isDuplicate) {
          final id = await _dbService.insertBook(book);
          importedBooks.add(book.copyWith(id: id));
          debugPrint('Imported: ${book.title}');
        } else {
          debugPrint('Duplicate book found, skipping: ${book.title}');
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

      String author = epubBook.Author ?? 'Unknown';
      String title = epubBook.Title ?? p.basenameWithoutExtension(file.path);

      // Save cover
      String coverPath = '';
      if (epubBook.CoverImage != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) await coversDir.create();

        coverPath = p.join(
          coversDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final image = epubBook.CoverImage;
        if (image != null) {
          await File(coverPath).writeAsBytes(img.encodeJpg(image));
        }
      }

      return Book(
        title: title,
        author: author,
        coverPath: coverPath,
        filePath: file.path,
        addedAt: DateTime.now(),
        folderPath: p.dirname(file.path),
        contentHash: await _calculateFileHash(file),
      );
    } catch (e) {
      debugPrint('Error processing epub: $e');
      return null;
    }
  }

  // PDF processing
  Future<Book?> _processPdf(File file) async {
    try {
      return Book(
        title: p.basenameWithoutExtension(file.path),
        author: 'Unknown',
        coverPath: '', // PDF covers are harder, would need a dedicated package
        filePath: file.path,
        addedAt: DateTime.now(),
        folderPath: p.dirname(file.path),
        contentHash: await _calculateFileHash(file),
      );
    } catch (e) {
      debugPrint('Error processing pdf: $e');
      return null;
    }
  }

  // Cover search and download (simplified)
  Future<String> downloadCover(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) await coversDir.create();

        final coverPath = p.join(
          coversDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await File(coverPath).writeAsBytes(response.bodyBytes);
        return coverPath;
      }
    } catch (e) {
      debugPrint('Error downloading cover: $e');
    }
    return '';
  }

  Future<String> saveLocalCover(File file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) await coversDir.create();

      final coverPath = p.join(
        coversDir.path,
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}',
      );
      await file.copy(coverPath);
      return coverPath;
    } catch (e) {
      debugPrint('Error saving local cover: $e');
    }
    return '';
  }

  Future<String> _calculateFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (e) {
      debugPrint('Error calculating file hash: $e');
      return '';
    }
  }
}
