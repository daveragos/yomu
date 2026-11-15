import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/platform_caps.dart';
import 'file_storage_service.dart';

/// Where book files live once they're in the library.
///
/// Yomu keeps its own copy of a book whenever the picked file can't be
/// relied on:
/// - On a desktop, the macOS sandbox only lets the app read a file the user
///   picked (or opened from Finder) until the app quits, so a library entry
///   pointing at the original file would stop opening after a relaunch.
/// - On Android, file_picker hands back a copy in the app's cache dir,
///   which the OS or "Clear cache" may wipe at any time.
/// - On iOS, a picked or opened file is a copy in the app's `tmp` or caches
///   folder, which iOS clears when it needs space.
abstract final class LibraryFiles {
  /// Whether [path] is already in Yomu's own storage.
  static Future<bool> isStored(String path) async {
    final appDir = (await getApplicationDocumentsDirectory()).path;
    return p.isWithin(appDir, path);
  }

  /// The path to record for a book imported from [path]: a copy in the
  /// app's `books` folder (reusing an identical earlier copy) on a desktop,
  /// on iOS, or when [path] is in the cache dir; elsewhere, [path] itself.
  static Future<String> keep(String path) async {
    if (await isStored(path)) return path;
    if (!PlatformCaps.keepsOwnBookCopies &&
        !await FileStorageService.isInCache(path)) {
      return path;
    }

    final source = File(path);
    final dir = await FileStorageService.booksDir();
    final earlier = await _identicalCopy(source, dir);
    if (earlier != null) return earlier;
    return (await FileStorageService.copyInto(source, dir)).path;
  }

  /// An earlier copy of [source] in [dir] under its name or a numbered
  /// variant of it, judged by size.
  static Future<String?> _identicalCopy(File source, Directory dir) async {
    final size = await source.length();
    final base = p.basenameWithoutExtension(source.path);
    final ext = p.extension(source.path);
    var candidate = p.join(dir.path, '$base$ext');
    for (var n = 1; await File(candidate).exists(); n++) {
      if (await File(candidate).length() == size) return candidate;
      candidate = p.join(dir.path, '$base ($n)$ext');
    }
    return null;
  }

  /// Whether an entry stored at [storedPath] should be pointed at a fresh
  /// import of the same book: its file can't be read any more, or (on a
  /// desktop or iOS) it was never copied into Yomu's storage.
  static Future<bool> needsRelink(String storedPath) async {
    if (!await isReadable(storedPath)) return true;
    return PlatformCaps.keepsOwnBookCopies && !await isStored(storedPath);
  }

  /// Whether the file at [path] exists and the app may read it.
  static Future<bool> isReadable(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final handle = await file.open();
      await handle.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
