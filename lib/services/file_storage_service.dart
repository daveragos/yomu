import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/book_model.dart';

/// Keeps imported books and audio in the app's documents directory.
///
/// On Android, file_picker hands back a copy inside the app's cache dir
/// (`cache/file_picker/<timestamp>/<name>`), which the OS or the user's
/// "Clear cache" can wipe at any time, so we never store those paths.
class FileStorageService {
  static Future<Directory> booksDir() => _appSubDir(['books']);

  static Future<Directory> audioDir(int? bookId) =>
      _appSubDir(['audio', '${bookId ?? 'unassigned'}']);

  static Future<Directory> _appSubDir(List<String> parts) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.joinAll([appDir.path, ...parts]));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static List<String>? _cacheRoots;

  /// Whether [path] lives inside the app's cache directory, or on iOS its
  /// `tmp` folder, where file_picker puts the files it hands back.
  static Future<bool> isInCache(String path) async {
    _cacheRoots ??= [
      (await getTemporaryDirectory()).path,
      if (Platform.isIOS) Directory.systemTemp.path,
    ].map(_withoutPrivatePrefix).toList();
    final target = _withoutPrivatePrefix(path);
    return _cacheRoots!.any((root) => p.isWithin(root, target));
  }

  /// iOS reports some app folders as `/private/var/...` and others as
  /// `/var/...`; both are the same place.
  static String _withoutPrivatePrefix(String path) =>
      path.startsWith('/private/var/') ? path.substring('/private'.length) : path;

  /// Copies [source] into [dir] under its own file name, adding a " (n)"
  /// suffix when that name is already taken.
  static Future<File> copyInto(File source, Directory dir) async {
    final name = p.basename(source.path);
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var dest = p.join(dir.path, name);
    for (var n = 1; await File(dest).exists(); n++) {
      dest = p.join(dir.path, '$base ($n)$ext');
    }

    // Copy under a temporary name first so an interrupted copy never
    // leaves a truncated file where a real one is expected.
    final partial = '$dest.part';
    try {
      await source.copy(partial);
      return await File(partial).rename(dest);
    } catch (_) {
      try {
        await File(partial).delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Best-effort removal of a file_picker cache copy we no longer need,
  /// along with its per-pick folder once that is empty.
  static Future<void> deleteCachedCopy(String path) async {
    try {
      if (!await isInCache(path)) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
      final parent = file.parent;
      if (await isInCache(parent.path) &&
          await parent.exists() &&
          await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (e) {
      debugPrint('Could not remove cached copy $path: $e');
    }
  }

  /// What file_picker should list when picking a book's audio. On iOS,
  /// [FileType.audio] opens the Music library, which can't see the
  /// audiobook files people keep in Files, so Files is shown instead,
  /// filtered to [audioPickerExtensions].
  static FileType get audioPickerType =>
      Platform.isIOS ? FileType.custom : FileType.audio;

  static List<String>? get audioPickerExtensions => Platform.isIOS
      ? const ['mp3', 'm4a', 'm4b', 'aac', 'wav', 'aiff', 'flac', 'caf']
      : null;

  /// Copies audio files picked for [bookId] into durable storage.
  ///
  /// Files that are already among [existing] tracks are skipped and counted
  /// as duplicates.
  static Future<({List<AudioTrack> added, int duplicates})> importAudioTracks(
    List<String?> pickedPaths,
    int? bookId,
    List<AudioTrack> existing,
  ) async {
    final dir = await audioDir(bookId);
    final added = <AudioTrack>[];
    var duplicates = 0;

    for (final path in pickedPaths) {
      if (path == null) continue;
      final name = p.basename(path);
      final knownPaths = [...existing, ...added].map((t) => t.path);
      if (knownPaths.contains(path) ||
          knownPaths.contains(p.join(dir.path, name))) {
        duplicates++;
      } else {
        final stored = await copyInto(File(path), dir);
        added.add(AudioTrack(path: stored.path, title: name));
      }
      await deleteCachedCopy(path);
    }

    return (added: added, duplicates: duplicates);
  }
}
