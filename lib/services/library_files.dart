import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/platform_caps.dart';

/// Where book files live once they're in the library.
///
/// On a desktop, Yomu keeps its own copy of every book. The macOS sandbox
/// only lets the app read a file the user picked (or opened from Finder)
/// until the app quits, so a library entry pointing at the original file
/// would stop opening after a relaunch.
abstract final class LibraryFiles {
  static Future<Directory> _booksDir() async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'books'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Whether [path] is already in Yomu's own storage.
  static Future<bool> isStored(String path) async {
    final appDir = (await getApplicationDocumentsDirectory()).path;
    return p.isWithin(appDir, path);
  }

  /// The path to record for a book imported from [path]: on a desktop, a
  /// copy in the app's `books` folder (reusing an identical earlier copy);
  /// elsewhere, [path] itself.
  static Future<String> keep(String path) async {
    if (!PlatformCaps.isDesktop || await isStored(path)) return path;

    final source = File(path);
    final dir = await _booksDir();
    final size = await source.length();
    final base = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    var dest = p.join(dir.path, '$base$ext');
    for (var n = 1; await File(dest).exists(); n++) {
      if (await File(dest).length() == size) return dest;
      dest = p.join(dir.path, '$base ($n)$ext');
    }
    await source.copy(dest);
    return dest;
  }

  /// Whether an entry stored at [storedPath] should be pointed at a fresh
  /// import of the same book: its file can't be read any more, or (on a
  /// desktop) it was never copied into Yomu's storage.
  static Future<bool> needsRelink(String storedPath) async {
    if (!await isReadable(storedPath)) return true;
    return PlatformCaps.isDesktop && !await isStored(storedPath);
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
