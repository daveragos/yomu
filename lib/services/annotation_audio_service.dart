import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'file_storage_service.dart';
import '../models/highlight_model.dart';

/// Stores voice notes attached to annotations.
///
/// The database keeps only the file name; the absolute path is resolved
/// against the app documents folder, which can move between app updates.
class AnnotationAudioService {
  static const String folderName = 'annotation_audio';
  static const String fileExtension = '.m4a';

  static Directory? _cachedDir;

  static Future<Directory> directory() async {
    if (_cachedDir != null) return _cachedDir!;
    final docs = await FileStorageService.appDataDir();
    final dir = Directory(p.join(docs.path, folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  static Future<String> resolve(String fileName) async {
    final dir = await directory();
    return p.join(dir.path, p.basename(fileName));
  }

  /// Returns a fresh file name for a new recording.
  static String newFileName() => '${Highlight.generateUid()}$fileExtension';

  static Future<void> delete(String? fileName) async {
    if (fileName == null || fileName.isEmpty) return;
    try {
      final file = File(await resolve(fileName));
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to delete voice note $fileName: $e');
    }
  }

  static Future<void> deleteAll(Iterable<String?> fileNames) async {
    for (final name in fileNames) {
      await delete(name);
    }
  }
}
