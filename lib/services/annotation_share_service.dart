import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_model.dart';
import '../models/annotation_reply_model.dart';
import '../models/highlight_model.dart';
import '../utils/voice_waveform.dart';
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
  final String? audioWaveform;

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
    this.audioWaveform,
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
    'audioWaveform': audioWaveform,
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
      audioWaveform: VoiceWaveform.decode(json['audioWaveform'] as String?) ==
              null
          ? null
          : json['audioWaveform'] as String,
    );
  }
}

/// A reply under a shared annotation.
class SharedReply {
  final String uid;
  final String highlightUid;
  final String? author;
  final String text;
  final DateTime createdAt;
  final String? audioEntry;
  final int? audioDurationMs;
  final String? audioWaveform;

  const SharedReply({
    required this.uid,
    required this.highlightUid,
    required this.author,
    required this.text,
    required this.createdAt,
    this.audioEntry,
    this.audioDurationMs,
    this.audioWaveform,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'highlightUid': highlightUid,
    'author': author,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'audio': audioEntry,
    'audioDurationMs': audioDurationMs,
    'audioWaveform': audioWaveform,
  };

  factory SharedReply.fromJson(Map<String, dynamic> json) {
    final audio = json['audio'] as String?;
    final waveform = json['audioWaveform'] as String?;
    return SharedReply(
      uid: json['uid'] as String,
      highlightUid: json['highlightUid'] as String,
      author: json['author'] as String?,
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      audioEntry: audio != null && audio.startsWith('audio/') ? audio : null,
      audioDurationMs: json['audioDurationMs'] as int?,
      audioWaveform: VoiceWaveform.decode(waveform) == null ? null : waveform,
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
  final List<SharedReply> replies;

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
    this.replies = const [],
  });

  int get voiceNoteCount =>
      annotations.where((a) => a.audioEntry != null).length;

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
    'replies': replies.map((r) => r.toJson()).toList(),
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
      replies: (json['replies'] as List<dynamic>? ?? const [])
          .take(AnnotationShareService.maxAnnotations)
          .map((r) => SharedReply.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Notes shared without their book, kept until that book is added.
class PendingNotes {
  final String path;
  final AnnotationPackageManifest manifest;
  final DateTime receivedAt;

  /// Another copy of the book in the library, if any.
  final Book? similarBook;

  const PendingNotes({
    required this.path,
    required this.manifest,
    required this.receivedAt,
    this.similarBook,
  });
}

class SharedImportResult {
  final AnnotationPackageManifest manifest;

  /// The library book the annotations were attached to. Null while pending.
  final Book? book;
  final int added;
  final int updated;
  final int repliesAdded;
  final int repliesUpdated;

  /// While pending: a book in the library that looks like the same title
  /// in another copy, which the notes could be placed on by their text.
  final Book? similarBook;

  /// While pending: where the notes are kept until the book is added.
  final String? pendingPath;

  const SharedImportResult({
    required this.manifest,
    required this.book,
    this.added = 0,
    this.updated = 0,
    this.repliesAdded = 0,
    this.repliesUpdated = 0,
    this.similarBook,
    this.pendingPath,
  });

  /// The recipient does not have this exact book yet; the annotations are
  /// kept and attached when they add it.
  bool get isPending => book == null;
}

/// Shares a book together with its annotations (notes, highlights and voice
/// notes) as a single file, and imports such files.
///
/// The notes travel in a small zip, the payload: `yomu.json` plus the voice
/// notes. It is shared one of two ways:
/// * appended to the book itself, as `Title.epub` or `Title.pdf`. Every phone
///   knows those types, so file and chat apps offer Yomu (and other readers
///   still open the book). The book's own bytes are untouched, so Yomu gets
///   back the exact original by cutting the file where the payload starts.
/// * on its own as a `.yomu` file, when the book is left out.
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

  /// Ends a book with appended notes, followed by the book's length and the
  /// payload's length (`YOMU-ANNOTATIONS 52113 8410`), in a PDF comment or in
  /// the EPUB's zip comment.
  static const String embeddedMarker = 'YOMU-ANNOTATIONS';

  final DatabaseService _db = DatabaseService();

  static bool isPackagePath(String path) =>
      p.extension(path).toLowerCase() == fileExtension;

  /// MIME type to share a built package under.
  static String mimeTypeFor(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.epub' => 'application/epub+zip',
        '.pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  /// Whether [path] holds shared annotations: a `.yomu` file, or an EPUB or
  /// PDF with notes appended. Files shared from other apps can lose their
  /// name, so anything else is checked for a package manifest too.
  static Future<bool> looksLikePackage(String path) async {
    if (isPackagePath(path)) return true;
    if (await _locateEmbedded(path) != null) return true;
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

  /// Builds the file to share for [book] in the temp folder and returns it:
  /// the book with its notes appended (`Title.epub` / `Title.pdf`) when
  /// [includeBook] is set, otherwise a `.yomu` file with just the notes.
  ///
  /// Private notes are always left out; [onlyUids] narrows the notes down
  /// further. Replies go along with their notes.
  Future<File> buildPackage({
    required Book book,
    required String sharerName,
    required bool includeBook,
    Set<String>? onlyUids,
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
      if (h.isPrivate) continue;
      if (h.uid == null) {
        h = h.copyWith(uid: Highlight.generateUid());
        await _db.updateHighlight(h);
      }
      if (onlyUids != null && !onlyUids.contains(h.uid)) continue;
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
          audioWaveform: audioEntry == null ? null : h.audioWaveform,
        ),
      );
    }

    final sharedUids = {for (final a in annotations) a.uid};
    final replies = <SharedReply>[];
    for (final r in await _db.getRepliesForBook(book.id!)) {
      if (!sharedUids.contains(r.highlightUid)) continue;
      String? audioEntry;
      if (r.hasAudio) {
        final path = await AnnotationAudioService.resolve(r.audioFile!);
        if (await File(path).exists()) {
          audioEntry =
              'audio/reply-${r.uid}${AnnotationAudioService.fileExtension}';
          files[audioEntry] = path;
        }
      }
      replies.add(
        SharedReply(
          uid: r.uid,
          highlightUid: r.highlightUid,
          author: r.author ?? sharerName,
          text: r.text,
          createdAt: r.createdAt,
          audioEntry: audioEntry,
          audioDurationMs: audioEntry == null ? null : r.audioDurationMs,
          audioWaveform: audioEntry == null ? null : r.audioWaveform,
        ),
      );
    }

    final bookFileName = _safeFileName(p.basename(book.filePath));
    final host = includeBook ? await _HostBook.inspect(bookFile) : null;
    String? bookEntry;
    if (includeBook && host == null) {
      // A book the notes can't be appended to (say a ZIP64 EPUB) travels
      // inside the .yomu file instead.
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
      replies: replies,
    );

    final tmp = await getTemporaryDirectory();
    final outDir = Directory(p.join(tmp.path, 'yomu_share'));
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);
    final stem = shareFileStem(book.title, sharerName);
    final manifestJson = jsonEncode(manifest.toJson());

    if (host == null) {
      final outPath = p.join(outDir.path, '$stem$fileExtension');
      await _runWritePackage(outPath, manifestJson, files);
      return File(outPath);
    }

    final payload = File(p.join(outDir.path, 'notes$fileExtension'));
    await _runWritePackage(payload.path, manifestJson, files);
    final out = File(
      p.join(outDir.path, '$stem${p.extension(book.filePath).toLowerCase()}'),
    );
    try {
      await host.writeWithPayload(bookFile, payload, out);
    } finally {
      await payload.delete();
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<AnnotationPackageManifest> readManifest(String packagePath) =>
      _withPayload(
        packagePath,
        (payloadPath, _) => _readManifestAt(payloadPath),
      );

  Future<AnnotationPackageManifest> _readManifestAt(String payloadPath) async {
    final json = await _runReadManifest(payloadPath);
    if (json == null) {
      throw const FormatException('Not a Yomu annotation package.');
    }
    return AnnotationPackageManifest.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Runs [action] on the package's payload zip. For a book with notes
  /// appended, the payload is copied out to a temp file first and
  /// `bookLength` says where the book's own bytes end; for a `.yomu` file it
  /// is the file itself and `bookLength` is null.
  Future<T> _withPayload<T>(
    String path,
    Future<T> Function(String payloadPath, int? bookLength) action,
  ) async {
    final embedded = await _locateEmbedded(path);
    if (embedded == null) return action(path, null);

    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'yomu_import'));
    await dir.create(recursive: true);
    final payloadPath = p.join(
      dir.path,
      '${DateTime.now().microsecondsSinceEpoch}$fileExtension',
    );
    await _copyRange(
      path,
      payloadPath,
      embedded.bookLength,
      embedded.payloadLength,
    );
    try {
      return await action(payloadPath, embedded.bookLength);
    } finally {
      try {
        await File(payloadPath).delete();
      } catch (_) {}
    }
  }

  /// Imports shared annotations: a book with notes appended, or a `.yomu`
  /// file.
  ///
  /// If the library already holds the exact book, the annotations are attached
  /// to it. Otherwise the shared book is added through [addBookToLibrary]
  /// first. Notes shared without the book, for a book the user does not have,
  /// are kept until that book is added (see [applyPendingFor]).
  Future<SharedImportResult> importPackage(
    String packagePath, {
    required Future<Book?> Function(String bookPath) addBookToLibrary,
  }) => _withPayload(packagePath, (payloadPath, bookLength) async {
    final manifest = await _readManifestAt(payloadPath);

    final books = await _db.getBooks();
    Book? book = books.firstWhereOrNull(
      (b) =>
          !b.isDeleted &&
          b.contentHash == manifest.contentHash &&
          File(b.filePath).existsSync(),
    );

    if (book == null) {
      final String bookPath;
      if (bookLength != null) {
        bookPath = await _extractHostBook(packagePath, bookLength, manifest);
      } else if (manifest.bookEntry != null) {
        bookPath = await _extractBook(payloadPath, manifest);
      } else {
        final pendingPath = await _savePending(payloadPath, manifest);
        return SharedImportResult(
          manifest: manifest,
          book: null,
          pendingPath: pendingPath,
          similarBook: await _similarBook(manifest, books),
        );
      }
      book = await addBookToLibrary(bookPath);
      if (book?.id == null) {
        throw const FormatException('The shared book could not be opened.');
      }
    }

    final counts = await _applyAnnotations(payloadPath, manifest, book!.id!);
    return _result(manifest, book, counts);
  });

  SharedImportResult _result(
    AnnotationPackageManifest manifest,
    Book book,
    _ApplyCounts counts,
  ) => SharedImportResult(
    manifest: manifest,
    book: book,
    added: counts.added,
    updated: counts.updated,
    repliesAdded: counts.repliesAdded,
    repliesUpdated: counts.repliesUpdated,
  );

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
        results.add(_result(manifest, book, counts));
        await entity.delete();
      } catch (e) {
        debugPrint('Failed to apply pending annotations ${entity.path}: $e');
      }
    }
    if (await dir.list().isEmpty) await dir.delete();
    return results;
  }

  /// Adds or updates the package's annotations and replies on [bookId].
  /// With [byText], the book is another copy of the shared one: the notes
  /// are marked to be found by their text when the book is opened.
  Future<_ApplyCounts> _applyAnnotations(
    String packagePath,
    AnnotationPackageManifest manifest,
    int bookId, {
    bool byText = false,
  }) async {
    final toWrite = <SharedAnnotation, Highlight?>{};
    for (final a in manifest.annotations) {
      final existing = await _db.getHighlightByUid(bookId, a.uid);
      // The user's own annotation (e.g. their share coming back to them)
      // always wins over the shared copy.
      if (existing != null && !existing.isShared) continue;
      toWrite[a] = existing;
    }

    // Replies to notes that are in this book, or arrive with this package.
    final noteUids = {
      for (final a in manifest.annotations) a.uid,
    };
    final repliesToWrite = <SharedReply, AnnotationReply?>{};
    for (final r in manifest.replies) {
      if (!noteUids.contains(r.highlightUid) &&
          await _db.getHighlightByUid(bookId, r.highlightUid) == null) {
        continue;
      }
      final existing = await _db.getReplyByUid(bookId, r.uid);
      // The reader's own replies coming back to them stay as they are.
      if (existing != null && existing.isMine) continue;
      repliesToWrite[r] = existing;
    }

    final audioTargets = <String, String>{}; // zip entry -> destination path
    final audioNames = <String, String>{}; // zip entry -> stored file name
    final audioEntries = [
      for (final a in toWrite.keys) a.audioEntry,
      for (final r in repliesToWrite.keys) r.audioEntry,
    ];
    for (final entry in audioEntries) {
      if (entry == null) continue;
      final name = AnnotationAudioService.newFileName();
      audioNames[entry] = name;
      audioTargets[entry] = await AnnotationAudioService.resolve(name);
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
        audioWaveform: audioFile == null ? null : a.audioWaveform,
        sharedBy: a.author ?? manifest.sharedBy ?? 'Another reader',
        anchorState: byText ? Highlight.anchorByText : null,
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

    var repliesAdded = 0;
    var repliesUpdated = 0;
    for (final entry in repliesToWrite.entries) {
      final r = entry.key;
      final existing = entry.value;
      final audioFile = r.audioEntry != null && extracted.contains(r.audioEntry)
          ? audioNames[r.audioEntry]
          : null;
      final reply = AnnotationReply(
        id: existing?.id,
        bookId: bookId,
        highlightUid: r.highlightUid,
        uid: r.uid,
        author: r.author ?? manifest.sharedBy ?? 'Another reader',
        text: r.text,
        audioFile: audioFile,
        audioDurationMs: audioFile == null ? null : r.audioDurationMs,
        audioWaveform: audioFile == null ? null : r.audioWaveform,
        createdAt: r.createdAt,
      );
      if (existing != null) {
        await AnnotationAudioService.delete(existing.audioFile);
        await _db.updateReply(reply);
        repliesUpdated++;
      } else {
        await _db.insertReply(reply);
        repliesAdded++;
      }
    }
    return _ApplyCounts(added, updated, repliesAdded, repliesUpdated);
  }

  /// Where a shared book is kept: `<docs>/shared_books/<hash>/<file name>`.
  Future<String> _sharedBookPath(AnnotationPackageManifest manifest) async {
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
    return p.join(dir.path, fileName);
  }

  /// Cuts the notes off a shared book, leaving the sender's exact file.
  Future<String> _extractHostBook(
    String path,
    int bookLength,
    AnnotationPackageManifest manifest,
  ) async {
    final dest = await _sharedBookPath(manifest);
    await _copyRange(path, dest, 0, bookLength);
    if (await fileMd5(File(dest)) != manifest.contentHash) {
      await File(dest).parent.delete(recursive: true);
      throw const FormatException(
        'The book in this file does not match its notes.',
      );
    }
    return dest;
  }

  /// Unpacks the book from a `.yomu` file that carries one.
  Future<String> _extractBook(
    String packagePath,
    AnnotationPackageManifest manifest,
  ) async {
    final dest = await _sharedBookPath(manifest);
    final dir = File(dest).parent;

    final entry = manifest.bookEntry!;
    final extracted = await _runExtract(packagePath, {
      entry: dest,
    }, _maxBookBytes);
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

  Future<String> _savePending(
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
    return dest;
  }

  static String _normalizedTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u00c0-\uffff]'), '');

  /// A library book with the same title (and author, when both are known)
  /// as the shared one: likely another copy of it.
  Future<Book?> _similarBook(
    AnnotationPackageManifest manifest, [
    List<Book>? books,
  ]) async {
    final title = _normalizedTitle(manifest.title);
    if (title.isEmpty) return null;
    final author = _normalizedTitle(manifest.author);
    for (final b in books ?? await _db.getBooks()) {
      if (b.isDeleted || b.contentHash == manifest.contentHash) continue;
      if (_normalizedTitle(b.title) != title) continue;
      final bookAuthor = _normalizedTitle(b.author);
      final authorsKnown =
          author.isNotEmpty &&
          bookAuthor.isNotEmpty &&
          author != 'unknown' &&
          bookAuthor != 'unknown';
      if (authorsKnown && bookAuthor != author) continue;
      if (!File(b.filePath).existsSync()) continue;
      return b;
    }
    return null;
  }

  /// Notes shared without their book, waiting for that exact book.
  Future<List<PendingNotes>> listPending() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'pending_annotations'));
    if (!await root.exists()) return const [];
    final books = await _db.getBooks();
    final pending = <PendingNotes>[];
    await for (final entity in root.list(recursive: true)) {
      if (entity is! File || !isPackagePath(entity.path)) continue;
      try {
        final manifest = await readManifest(entity.path);
        pending.add(
          PendingNotes(
            path: entity.path,
            manifest: manifest,
            receivedAt: (await entity.stat()).modified,
            similarBook: await _similarBook(manifest, books),
          ),
        );
      } catch (e) {
        debugPrint('Unreadable pending notes ${entity.path}: $e');
      }
    }
    pending.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return pending;
  }

  Future<void> discardPending(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    final dir = file.parent;
    if (await dir.exists() && await dir.list().isEmpty) await dir.delete();
  }

  /// Puts waiting notes on [book], another copy of the book they were made
  /// in. They are found by their text when the book is next opened.
  Future<SharedImportResult> placePendingOn(String path, Book book) async {
    final manifest = await readManifest(path);
    final counts = await _applyAnnotations(
      path,
      manifest,
      book.id!,
      byText: true,
    );
    await discardPending(path);
    return _result(manifest, book, counts);
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

  /// "Title (notes by Dawit)", safe to use as a file name. Letters of any
  /// script are kept, so non-Latin titles stay readable.
  static String shareFileStem(String title, String sharerName) {
    String clean(String s) => s
        .replaceAll(RegExp(r'[/\\]'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s.\-()]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^\.+'), '');
    final cleanTitle = clean(title);
    final cleanName = clean(sharerName);
    final base = cleanTitle.isEmpty ? 'Book' : cleanTitle;
    final stem = cleanName.isEmpty ? base : '$base (notes by $cleanName)';
    return stem.length > 120 ? stem.substring(0, 120).trim() : stem;
  }

  /// Bytes each note's voice notes take (its own plus its replies'), by
  /// note uid, for estimating the size of a share.
  Future<Map<String, int>> voiceNoteBytes(Book book) async {
    final bytes = <String, int>{};
    Future<void> add(String? uid, String? audioFile) async {
      if (uid == null || audioFile == null) return;
      final file = File(await AnnotationAudioService.resolve(audioFile));
      if (await file.exists()) {
        bytes[uid] = (bytes[uid] ?? 0) + await file.length();
      }
    }

    for (final h in await _db.getHighlightsForBook(book.id!)) {
      await add(h.uid, h.audioFile);
    }
    for (final r in await _db.getRepliesForBook(book.id!)) {
      await add(r.highlightUid, r.audioFile);
    }
    return bytes;
  }

  static String _safeFileName(String name) {
    final cleaned = p
        .basename(name)
        .replaceAll(RegExp(r'[^\w\s.\-()]'), '')
        .trim();
    return cleaned.isEmpty || cleaned.startsWith('.')
        ? 'book$cleaned'
        : cleaned;
  }
}

class _ApplyCounts {
  const _ApplyCounts(
    this.added,
    this.updated,
    this.repliesAdded,
    this.repliesUpdated,
  );
  final int added;
  final int updated;
  final int repliesAdded;
  final int repliesUpdated;
}

// Voice notes have no length limit; this only guards against broken files.
const int _maxAudioBytes = 1024 * 1024 * 1024;
const int _maxBookBytes = 2 * 1024 * 1024 * 1024;

Future<Uint8List> _readTail(File file, int length, int size) async {
  final raf = await file.open();
  try {
    final start = math.max(0, length - size);
    await raf.setPosition(start);
    return await raf.read(length - start);
  } finally {
    await raf.close();
  }
}

Future<void> _copyRange(
  String source,
  String dest,
  int start,
  int length,
) async {
  final sink = File(dest).openWrite();
  try {
    await sink.addStream(File(source).openRead(start, start + length));
  } finally {
    await sink.close();
  }
}

/// Finds the notes appended to a shared EPUB or PDF: the book's own bytes
/// are `[0, bookLength)` and the payload zip follows them.
Future<({int bookLength, int payloadLength})?> _locateEmbedded(
  String path,
) async {
  try {
    final file = File(path);
    final length = await file.length();
    final tail = latin1.decode(await _readTail(file, length, 512));
    final match = RegExp(
      '${AnnotationShareService.embeddedMarker} (\\d{1,15}) (\\d{1,15})',
    ).allMatches(tail).lastOrNull;
    if (match == null) return null;
    final bookLength = int.parse(match.group(1)!);
    final payloadLength = int.parse(match.group(2)!);
    if (bookLength <= 0 ||
        payloadLength <= 0 ||
        bookLength + payloadLength > length) {
      return null;
    }
    // The payload is a zip, so it starts with a local file header.
    final raf = await file.open();
    try {
      await raf.setPosition(bookLength);
      final signature = await raf.read(4);
      if (signature.length != 4 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b ||
          signature[2] != 0x03 ||
          signature[3] != 0x04) {
        return null;
      }
    } finally {
      await raf.close();
    }
    return (bookLength: bookLength, payloadLength: payloadLength);
  } catch (_) {
    return null;
  }
}

/// A book file that notes can be appended to while it stays a valid EPUB or
/// PDF for every other app. The book's own bytes are left as they are.
class _HostBook {
  _HostBook._(
    this.length,
    this._startXref,
    this._centralDirectory,
    this._entryCount,
  );

  final int length;

  /// PDF: where its cross-reference table starts.
  final int? _startXref;

  /// EPUB: its zip central directory, and how many entries that lists.
  final Uint8List? _centralDirectory;
  final int _entryCount;

  /// Reads what's needed to append to [file], or returns null when it isn't
  /// an EPUB or PDF this can handle (a ZIP64 EPUB, a PDF with no
  /// `startxref`).
  static Future<_HostBook?> inspect(File file) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final length = await file.length();
      if (ext == '.pdf') {
        final tail = latin1.decode(await _readTail(file, length, 2048));
        final match = RegExp(
          r'startxref\s+(\d+)\s+%%EOF',
        ).allMatches(tail).lastOrNull;
        if (match == null) return null;
        return _HostBook._(length, int.parse(match.group(1)!), null, 0);
      }
      if (ext != '.epub') return null;

      // The end-of-central-directory record: 22 bytes plus a comment.
      final tail = await _readTail(file, length, 22 + 0xFFFF);
      for (var i = tail.length - 22; i >= 0; i--) {
        if (tail[i] != 0x50 ||
            tail[i + 1] != 0x4b ||
            tail[i + 2] != 0x05 ||
            tail[i + 3] != 0x06) {
          continue;
        }
        final end = ByteData.sublistView(tail, i);
        if (i + 22 + end.getUint16(20, Endian.little) != tail.length) continue;
        final entries = end.getUint16(10, Endian.little);
        final cdSize = end.getUint32(12, Endian.little);
        final cdOffset = end.getUint32(16, Endian.little);
        if (entries == 0xFFFF ||
            cdSize == 0xFFFFFFFF ||
            cdOffset == 0xFFFFFFFF ||
            cdOffset + cdSize > length) {
          return null;
        }
        final raf = await file.open();
        try {
          await raf.setPosition(cdOffset);
          final cd = await raf.read(cdSize);
          if (cd.length != cdSize) return null;
          return _HostBook._(length, null, cd, entries);
        } finally {
          await raf.close();
        }
      }
    } catch (e) {
      debugPrint('Cannot append notes to ${file.path}: $e');
    }
    return null;
  }

  /// Writes [book] followed by [payload] to [out], then what keeps it a
  /// valid book: for a PDF, a pointer back to its cross-reference table; for
  /// an EPUB, a copy of its central directory and a new end record pointing
  /// at that copy. Both end with [AnnotationShareService.embeddedMarker].
  Future<void> writeWithPayload(File book, File payload, File out) async {
    final payloadLength = await payload.length();
    final marker =
        '${AnnotationShareService.embeddedMarker} $length $payloadLength';
    final cd = _centralDirectory;
    if (cd != null && length + payloadLength + cd.length > 0xFFFFFFFF) {
      throw const FileSystemException('The book is too large to share.');
    }
    final sink = out.openWrite();
    try {
      await sink.addStream(book.openRead(0, length));
      await sink.addStream(payload.openRead());
      if (cd == null) {
        sink.add(latin1.encode('\n%$marker\nstartxref\n$_startXref\n%%EOF\n'));
      } else {
        final comment = latin1.encode(marker);
        final end = ByteData(22)
          ..setUint32(0, 0x06054b50, Endian.little)
          ..setUint16(8, _entryCount, Endian.little)
          ..setUint16(10, _entryCount, Endian.little)
          ..setUint32(12, cd.length, Endian.little)
          ..setUint32(16, length + payloadLength, Endian.little)
          ..setUint16(20, comment.length, Endian.little);
        sink
          ..add(cd)
          ..add(end.buffer.asUint8List())
          ..add(comment);
      }
    } finally {
      await sink.close();
    }
  }
}

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
      await encoder.addFile(File(entry.value), entry.key, ZipFileEncoder.store);
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
