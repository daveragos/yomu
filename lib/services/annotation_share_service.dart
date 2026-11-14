import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_model.dart';
import '../models/highlight_model.dart';
import 'annotation_audio_service.dart';
import 'database_service.dart';

/// One annotation as it travels inside a `.yomu` package.
class SharedAnnotation {
  final String uid;
  final int chapterIndex;
  final String text;
  final String? note;
  final String color;
  final DateTime createdAt;
  final String position;
  final String? author;
  final String? audioEntry;
  final int? audioDurationMs;

  const SharedAnnotation({
    required this.uid,
    required this.chapterIndex,
    required this.text,
    this.note,
    required this.color,
    required this.createdAt,
    required this.position,
    this.author,
    this.audioEntry,
    this.audioDurationMs,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'chapterIndex': chapterIndex,
    'text': text,
    'note': note,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'position': position,
    'author': author,
    'audio': audioEntry,
    'audioDurationMs': audioDurationMs,
  };

  factory SharedAnnotation.fromJson(Map<String, dynamic> json) {
    final audio = json['audio'] as String?;
    return SharedAnnotation(
      uid: json['uid'] as String,
      chapterIndex: json['chapterIndex'] as int,
      text: json['text'] as String,
      note: json['note'] as String?,
      color: json['color'] as String? ?? '#F1C40F',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      position: json['position'] as String? ?? '',
      author: json['author'] as String?,
      audioEntry: audio != null && audio.startsWith('audio/') ? audio : null,
      audioDurationMs: json['audioDurationMs'] as int?,
    );
  }
}

/// Contents of `yomu.json`, the manifest at the root of a `.yomu` package.
class AnnotationPackageManifest {
  final int version;
  final String contentHash;
  final String title;
  final String author;
  final String bookFileName;

  /// Zip entry of the book file, or null when only annotations were shared.
  final String? bookEntry;
  final String? sharedBy;
  final DateTime sharedAt;
  final List<SharedAnnotation> annotations;

  const AnnotationPackageManifest({
    required this.version,
    required this.contentHash,
    required this.title,
    required this.author,
    required this.bookFileName,
    required this.bookEntry,
    required this.sharedBy,
    required this.sharedAt,
    required this.annotations,
  });

  int get voiceNoteCount => annotations.where((a) => a.audioEntry != null).length;

  Map<String, dynamic> toJson() => {
    'format': AnnotationShareService.formatId,
    'version': version,
    'book': {
      'contentHash': contentHash,
      'title': title,
      'author': author,
      'fileName': bookFileName,
      'entry': bookEntry,
    },
    'sharedBy': sharedBy,
    'sharedAt': sharedAt.toIso8601String(),
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  factory AnnotationPackageManifest.fromJson(Map<String, dynamic> json) {
    if (json['format'] != AnnotationShareService.formatId) {
      throw const FormatException('Not a Yomu annotation package.');
    }
    final version = json['version'] as int? ?? 0;
    if (version < 1 || version > AnnotationShareService.formatVersion) {
      throw const FormatException(
        'This package was made by a newer version of Yomu. Update the app to open it.',
      );
    }
    final book = json['book'] as Map<String, dynamic>;
    final hash = book['contentHash'] as String? ?? '';
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(hash)) {
      throw const FormatException('The package does not identify its book.');
    }
    final entry = book['entry'] as String?;
    return AnnotationPackageManifest(
      version: version,
      contentHash: hash,
      title: book['title'] as String? ?? 'Untitled',
      author: book['author'] as String? ?? 'Unknown',
      bookFileName: book['fileName'] as String? ?? 'book',
      bookEntry: entry != null && entry.startsWith('book/') ? entry : null,
      sharedBy: json['sharedBy'] as String?,
      sharedAt:
          DateTime.tryParse(json['sharedAt'] as String? ?? '') ??
          DateTime.now(),
      annotations: (json['annotations'] as List<dynamic>? ?? const [])
          .take(AnnotationShareService.maxAnnotations)
          .map((a) => SharedAnnotation.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SharedImportResult {
  final AnnotationPackageManifest manifest;

  /// The library book the annotations were attached to. Null while pending.
  final Book? book;
  final int added;
  final int updated;

  const SharedImportResult({
    required this.manifest,
    required this.book,
    this.added = 0,
    this.updated = 0,
  });

  /// The recipient does not have this exact book yet; the annotations are
  /// kept and attached when they add it.
  bool get isPending => book == null;
}

/// Shares a book together with its annotations (notes, highlights and voice
/// notes) as a single `.yomu` file, and imports such files.
///
/// Annotations are tied to the exact book file through its MD5 content hash,
/// so they only ever attach to an identical copy of the book.
class AnnotationShareService {
  static const String fileExtension = '.yomu';
  static const String formatId = 'yomu-annotated-book';
  static const int formatVersion = 1;
  static const String manifestEntry = 'yomu.json';
  static const int maxAnnotations = 20000;
  static const String _sharerNameKey = 'annotation_share_name';

  final DatabaseService _db = DatabaseService();

  static bool isPackagePath(String path) =>
      p.extension(path).toLowerCase() == fileExtension;

  /// Whether [path] is a `.yomu` package. Files shared from other apps can lose
  /// their extension, so anything that is not plainly a book is checked for
  /// a package manifest.
  static Future<bool> looksLikePackage(String path) async {
    if (isPackagePath(path)) return true;
    final ext = p.extension(path).toLowerCase();
    if (ext == '.epub' || ext == '.pdf') return false;
    return await _runReadManifest(path) != null;
  }

  static Future<String?> savedSharerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sharerNameKey);
  }

  static Future<void> saveSharerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharerNameKey, name);
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Builds a `.yomu` package for [book] in the temp folder and returns it.
  Future<File> buildPackage({
    required Book book,
    required String sharerName,
    required bool includeBook,
  }) async {
    final bookFile = File(book.filePath);
    if (includeBook && !await bookFile.exists()) {
      throw const FileSystemException('The book file could not be found.');
    }

    var contentHash = book.contentHash;
    if (contentHash == null || contentHash.isEmpty) {
      contentHash = await fileMd5(bookFile);
      await _db.updateBook(book.copyWith(contentHash: contentHash));
    }

    final highlights = await _db.getHighlightsForBook(book.id!);
    final files = <String, String>{}; // zip entry -> source path
    final annotations = <SharedAnnotation>[];

    for (var h in highlights) {
      if (h.uid == null) {
        h = h.copyWith(uid: Highlight.generateUid());
        await _db.updateHighlight(h);
      }
      String? audioEntry;
      if (h.hasAudio) {
        final path = await AnnotationAudioService.resolve(h.audioFile!);
        if (await File(path).exists()) {
          audioEntry = 'audio/${h.uid}${AnnotationAudioService.fileExtension}';
          files[audioEntry] = path;
        }
      }
      annotations.add(
        SharedAnnotation(
          uid: h.uid!,
          chapterIndex: h.chapterIndex,
          text: h.text,
          note: h.note,
          color: h.color,
          createdAt: h.createdAt,
          position: h.position,
          author: h.sharedBy ?? sharerName,
          audioEntry: audioEntry,
          audioDurationMs: audioEntry == null ? null : h.audioDurationMs,
        ),
      );
    }

    final bookFileName = _safeFileName(p.basename(book.filePath));
    String? bookEntry;
    if (includeBook) {
      bookEntry = 'book/$bookFileName';
      files[bookEntry] = bookFile.path;
    }

    final manifest = AnnotationPackageManifest(
      version: formatVersion,
      contentHash: contentHash,
      title: book.title,
      author: book.author,
      bookFileName: bookFileName,
      bookEntry: bookEntry,
      sharedBy: sharerName,
      sharedAt: DateTime.now(),
      annotations: annotations,
    );

    final tmp = await getTemporaryDirectory();
    final outDir = Directory(p.join(tmp.path, 'yomu_share'));
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);
    final baseName = _safeFileName(book.title).replaceAll(' ', '_');
    final outPath = p.join(
      outDir.path,
      '${baseName.isEmpty ? 'book' : baseName}$fileExtension',
    );

    final manifestJson = jsonEncode(manifest.toJson());
    await _runWritePackage(outPath, manifestJson, files);
    return File(outPath);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<AnnotationPackageManifest> readManifest(String packagePath) async {
    final json = await _runReadManifest(packagePath);
    if (json == null) {
      throw const FormatException('Not a Yomu annotation package.');
    }
    return AnnotationPackageManifest.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Imports a `.yomu` package.
  ///
  /// If the library already holds the exact book, the annotations are attached
  /// to it. Otherwise the bundled book file is added through [addBookToLibrary]
  /// first. A package without a book file, for a book the user does not have,
  /// is kept until that book is added (see [applyPendingFor]).
  Future<SharedImportResult> importPackage(
    String packagePath, {
    required Future<Book?> Function(String bookPath) addBookToLibrary,
  }) async {
    final manifest = await readManifest(packagePath);

    final books = await _db.getBooks();
    Book? book = books.firstWhereOrNull(
      (b) =>
          !b.isDeleted &&
          b.contentHash == manifest.contentHash &&
          File(b.filePath).existsSync(),
    );

    if (book == null) {
      if (manifest.bookEntry == null) {
        await _savePending(packagePath, manifest);
        return SharedImportResult(manifest: manifest, book: null);
      }
      final bookPath = await _extractBook(packagePath, manifest);
      book = await addBookToLibrary(bookPath);
      if (book?.id == null) {
        throw const FormatException('The shared book could not be opened.');
      }
    }

    final counts = await _applyAnnotations(packagePath, manifest, book!.id!);
    return SharedImportResult(
      manifest: manifest,
      book: book,
      added: counts.$1,
      updated: counts.$2,
    );
  }

  /// Attaches annotations that were shared before the user had [book].
  Future<List<SharedImportResult>> applyPendingFor(Book book) async {
    final hash = book.contentHash;
    if (book.id == null || hash == null || hash.isEmpty) return const [];
    final dir = await _pendingDir(hash);
    if (!await dir.exists()) return const [];

    final results = <SharedImportResult>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !isPackagePath(entity.path)) continue;
      try {
        final manifest = await readManifest(entity.path);
        final counts = await _applyAnnotations(entity.path, manifest, book.id!);
        results.add(
          SharedImportResult(
            manifest: manifest,
            book: book,
            added: counts.$1,
            updated: counts.$2,
          ),
        );
        await entity.delete();
      } catch (e) {
        debugPrint('Failed to apply pending annotations ${entity.path}: $e');
      }
    }
    if (await dir.list().isEmpty) await dir.delete();
    return results;
  }

  Future<(int, int)> _applyAnnotations(
    String packagePath,
    AnnotationPackageManifest manifest,
    int bookId,
  ) async {
    final toWrite = <SharedAnnotation, Highlight?>{};
    for (final a in manifest.annotations) {
      final existing = await _db.getHighlightByUid(bookId, a.uid);
      // The user's own annotation (e.g. their share coming back to them)
      // always wins over the shared copy.
      if (existing != null && !existing.isShared) continue;
      toWrite[a] = existing;
    }

    final audioTargets = <String, String>{}; // zip entry -> destination path
    final audioNames = <String, String>{}; // zip entry -> stored file name
    for (final a in toWrite.keys) {
      if (a.audioEntry == null) continue;
      final name = AnnotationAudioService.newFileName();
      audioNames[a.audioEntry!] = name;
      audioTargets[a.audioEntry!] = await AnnotationAudioService.resolve(name);
    }
    final extracted = audioTargets.isEmpty
        ? const <String>{}
        : await _runExtract(packagePath, audioTargets, _maxAudioBytes);

    var added = 0;
    var updated = 0;
    for (final entry in toWrite.entries) {
      final a = entry.key;
      final existing = entry.value;
      final audioFile = a.audioEntry != null && extracted.contains(a.audioEntry)
          ? audioNames[a.audioEntry]
          : null;
      final highlight = Highlight(
        id: existing?.id,
        bookId: bookId,
        chapterIndex: a.chapterIndex,
        text: a.text,
        note: a.note,
        color: a.color,
        createdAt: a.createdAt,
        position: a.position,
        uid: a.uid,
        audioFile: audioFile,
        audioDurationMs: audioFile == null ? null : a.audioDurationMs,
        sharedBy: a.author ?? manifest.sharedBy ?? 'Another reader',
      );
      if (existing != null) {
        await AnnotationAudioService.delete(existing.audioFile);
        await _db.updateHighlight(highlight);
        updated++;
      } else {
        await _db.insertHighlight(highlight);
        added++;
      }
    }
    return (added, updated);
  }

  Future<String> _extractBook(
    String packagePath,
    AnnotationPackageManifest manifest,
  ) async {
    final fileName = _safeFileName(manifest.bookFileName);
    final ext = p.extension(fileName).toLowerCase();
    if (ext != '.epub' && ext != '.pdf') {
      throw const FormatException('The shared book is not an EPUB or PDF.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(docs.path, 'shared_books', manifest.contentHash),
    );
    await dir.create(recursive: true);
    final dest = p.join(dir.path, fileName);

    final entry = manifest.bookEntry!;
    final extracted = await _runExtract(
      packagePath,
      {entry: dest},
      _maxBookBytes,
    );
    if (!extracted.contains(entry)) {
      throw const FormatException('The package is missing its book file.');
    }

    if (await fileMd5(File(dest)) != manifest.contentHash) {
      await dir.delete(recursive: true);
      throw const FormatException(
        'The book in this package does not match its annotations.',
      );
    }
    return dest;
  }

  Future<void> _savePending(
    String packagePath,
    AnnotationPackageManifest manifest,
  ) async {
    final dir = await _pendingDir(manifest.contentHash);
    await dir.create(recursive: true);
    final dest = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}$fileExtension',
    );
    await File(packagePath).copy(dest);
  }

  Future<Directory> _pendingDir(String hash) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'pending_annotations', hash));
  }

  // Zip work runs off the UI isolate. These are static so the closures sent to
  // the isolate capture only their arguments.
  static Future<void> _runWritePackage(
    String outPath,
    String manifestJson,
    Map<String, String> files,
  ) => Isolate.run(() => _writePackage(outPath, manifestJson, files));

  static Future<String?> _runReadManifest(String packagePath) =>
      Isolate.run(() => _readManifestJson(packagePath));

  static Future<Set<String>> _runExtract(
    String packagePath,
    Map<String, String> targets,
    int maxBytes,
  ) => Isolate.run(() => _extractEntries(packagePath, targets, maxBytes));

  static Future<String> fileMd5(File file) async {
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  }

  static String _safeFileName(String name) {
    final cleaned = p
        .basename(name)
        .replaceAll(RegExp(r'[^\w\s.\-()]'), '')
        .trim();
    return cleaned.isEmpty || cleaned.startsWith('.') ? 'book$cleaned' : cleaned;
  }
}

const int _maxAudioBytes = 50 * 1024 * 1024;
const int _maxBookBytes = 2 * 1024 * 1024 * 1024;

// Isolate entry points: top-level so they capture nothing from the UI isolate.

Future<void> _writePackage(
  String outPath,
  String manifestJson,
  Map<String, String> files,
) async {
  final encoder = ZipFileEncoder();
  encoder.create(outPath);
  try {
    encoder.addArchiveFile(
      ArchiveFile.string(AnnotationShareService.manifestEntry, manifestJson),
    );
    for (final entry in files.entries) {
      // Books and AAC audio are already compressed; store them as-is.
      await encoder.addFile(
        File(entry.value),
        entry.key,
        ZipFileEncoder.store,
      );
    }
  } finally {
    await encoder.close();
  }
}

String? _readManifestJson(String packagePath) {
  final input = InputFileStream(packagePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final file = archive.findFile(AnnotationShareService.manifestEntry);
    if (file == null || !file.isFile || file.size > 32 * 1024 * 1024) {
      return null;
    }
    return utf8.decode(file.content);
  } catch (_) {
    return null;
  } finally {
    input.closeSync();
  }
}

/// Extracts the named zip entries to the given destination paths. Entry names
/// never become paths themselves. Returns the entries that were written.
Set<String> _extractEntries(
  String packagePath,
  Map<String, String> targets,
  int maxBytes,
) {
  final written = <String>{};
  final input = InputFileStream(packagePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    for (final target in targets.entries) {
      final file = archive.findFile(target.key);
      if (file == null || !file.isFile || file.size > maxBytes) continue;
      final output = OutputFileStream(target.value);
      try {
        file.writeContent(output);
      } finally {
        output.closeSync();
      }
      written.add(target.key);
    }
  } finally {
    input.closeSync();
  }
  return written;
}
