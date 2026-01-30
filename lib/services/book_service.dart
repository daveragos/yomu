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
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BookService {
  final DatabaseService _dbService = DatabaseService();

  Future<List<File>> findBookFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    final List<File> files = [];
    if (!await directory.exists()) return [];

    try {
      final Stream<FileSystemEntity> entityStream = directory.list(
        recursive: true,
        followLinks: false,
      );

      await for (var entity in entityStream.handleError(
        (e) => debugPrint('Skip: $e'),
      )) {
        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          if (extension == '.epub' || extension == '.pdf') {
            files.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding files: $e');
    }
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  Future<Book?> processFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.epub') {
      return await _processEpub(file);
    } else if (extension == '.pdf') {
      return await _processPdf(file);
    }
    return null;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        if (await Permission.manageExternalStorage.isGranted) return true;
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        if (await Permission.storage.isGranted) return true;
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<List<Book>> scanDirectory() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      debugPrint('Permission denied for storage scanning');
      return [];
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      debugPrint('No directory selected');
      return [];
    }

    debugPrint('Scanning directory: $selectedDirectory');
    final directory = Directory(selectedDirectory);
    final List<Book> importedBooks = [];
    final existingBooks = await _dbService.getBooks();

    try {
      final Stream<FileSystemEntity> entityStream = directory.list(
        recursive: true,
        followLinks: false,
      );

      await for (var entity in entityStream.handleError((e) {
        debugPrint('Skip restricted folder/file: $e');
      })) {
        if (entity is File) {
          final path = entity.path;
          final extension = p.extension(path).toLowerCase();

          if (extension == '.epub' || extension == '.pdf') {
            debugPrint('Processing: $path');

            // Check if already in DB
            if (existingBooks.any((b) => b.filePath == path)) {
              debugPrint('Already in library: $path');
              continue;
            }

            Book? book;
            if (extension == '.epub') {
              book = await _processEpub(entity);
            } else if (extension == '.pdf') {
              book = await _processPdf(entity);
            }

            if (book != null) {
              final bookToInsert = book.copyWith(folderPath: p.dirname(path));
              final id = await _dbService.insertBook(bookToInsert);
              importedBooks.add(bookToInsert.copyWith(id: id));
              debugPrint('Imported: ${book.title}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error during directory scanning: $e');
    }

    debugPrint('Scanning finished. Imported ${importedBooks.length} books.');
    return importedBooks;
  }

  Future<List<Book>> scanPath(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) return [];

    final List<Book> importedBooks = [];
    final existingBooks = await _dbService.getBooks();

    try {
      final Stream<FileSystemEntity> entityStream = directory.list(
        recursive: true,
        followLinks: false,
      );

      await for (var entity in entityStream.handleError((e) {
        debugPrint('Skip: $e');
      })) {
        if (entity is File) {
          final filePath = entity.path;
          final extension = p.extension(filePath).toLowerCase();

          if (extension == '.epub' || extension == '.pdf') {
            if (existingBooks.any((b) => b.filePath == filePath)) continue;

            Book? book;
            if (extension == '.epub') {
              book = await _processEpub(entity);
            } else if (extension == '.pdf') {
              book = await _processPdf(entity);
            }

            if (book != null) {
              final bookToInsert = book.copyWith(
                folderPath: p.dirname(filePath),
              );
              final id = await _dbService.insertBook(bookToInsert);
              importedBooks.add(bookToInsert.copyWith(id: id));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning path: $e');
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
}
