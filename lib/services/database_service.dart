import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:path/path.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../models/annotation_reply_model.dart';
import '../models/highlight_model.dart';
import '../models/vocabulary_model.dart';
import 'annotation_audio_service.dart';
import 'file_storage_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // sqflite has no Linux/Windows plugin; there it runs on SQLite via FFI,
    // whose default folder is relative to the working directory, so the
    // database lives in Yomu's data folder instead.
    final usesFfi = Platform.isLinux || Platform.isWindows;
    if (usesFfi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    String path = join(
      usesFfi
          ? (await FileStorageService.appDataDir()).path
          : await getDatabasesPath(),
      'yomu.db',
    );
    return await openDatabase(
      path,
      version: 21,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        coverPath TEXT,
        filePath TEXT,
        progress REAL,
        addedAt TEXT,
        lastReadAt TEXT,
        isFavorite INTEGER DEFAULT 0,
        series TEXT,
        tags TEXT,
        folderPath TEXT,
        genre TEXT,
        currentPage INTEGER DEFAULT 0,
        totalPages INTEGER DEFAULT 0,
        estimatedReadingMinutes INTEGER DEFAULT 0,
        lastPosition TEXT,
        audioPath TEXT,
        audioLastPosition INTEGER,
        audioLastIndex INTEGER,
        audioTracks TEXT,

        contentHash TEXT,
        isDeleted INTEGER DEFAULT 0
      )

    ''');
    await db.execute('''
      CREATE TABLE reading_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        date TEXT,
        pagesRead INTEGER,
        durationMinutes INTEGER,
        timestamp TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        title TEXT,
        progress REAL,
        createdAt TEXT,
        position TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE quests(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        type INTEGER,
        targetValue INTEGER,
        currentValue INTEGER,
        xpReward INTEGER,
        isCompleted INTEGER,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE highlights(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        chapterIndex INTEGER,
        text TEXT,
        note TEXT,
        color TEXT,
        createdAt TEXT,
        position TEXT,
        uid TEXT,
        audioFile TEXT,
        audioDurationMs INTEGER,
        audioWaveform TEXT,
        sharedBy TEXT,
        isPrivate INTEGER DEFAULT 0,
        anchorState TEXT
      )
    ''');
    await _createRepliesTable(db);
    await db.execute('''
      CREATE TABLE dictionary_lookups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        word TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN isFavorite INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE books ADD COLUMN series TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN folderPath TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN genre TEXT DEFAULT "Unknown"',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE reading_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bookId INTEGER,
          date TEXT,
          pagesRead INTEGER,
          durationMinutes INTEGER
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN currentPage INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN totalPages INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN estimatedReadingMinutes INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE books ADD COLUMN lastPosition TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE books ADD COLUMN audioPath TEXT');
      await db.execute(
        'ALTER TABLE books ADD COLUMN audioLastPosition INTEGER',
      );
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE bookmarks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bookId INTEGER,
          title TEXT,
          progress REAL,
          createdAt TEXT,
          position TEXT
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE books ADD COLUMN contentHash TEXT');
    }
    if (oldVersion < 11) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN isDeleted INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE quests(
          id TEXT PRIMARY KEY,
          title TEXT,
          description TEXT,
          type INTEGER,
          targetValue INTEGER,
          currentValue INTEGER,
          xpReward INTEGER,
          isCompleted INTEGER,
          date TEXT
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute(
        'ALTER TABLE reading_sessions ADD COLUMN timestamp TEXT',
      );
    }
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE highlights(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bookId INTEGER,
          chapterIndex INTEGER,
          text TEXT,
          note TEXT,
          color TEXT,
          createdAt TEXT
        )
      ''');
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE books ADD COLUMN audioTracks TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN audioLastIndex INTEGER');
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE highlights ADD COLUMN position TEXT DEFAULT ""');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE dictionary_lookups(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT,
          timestamp TEXT
        )
      ''');
    }
    if (oldVersion < 18) {
      await db.execute(
        'ALTER TABLE dictionary_lookups ADD COLUMN bookId INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 19) {
      await db.execute('ALTER TABLE highlights ADD COLUMN uid TEXT');
      await db.execute('ALTER TABLE highlights ADD COLUMN audioFile TEXT');
      await db.execute(
        'ALTER TABLE highlights ADD COLUMN audioDurationMs INTEGER',
      );
      await db.execute('ALTER TABLE highlights ADD COLUMN sharedBy TEXT');
    }
    if (oldVersion < 20) {
      await db.execute('ALTER TABLE highlights ADD COLUMN audioWaveform TEXT');
    }
    if (oldVersion < 21) {
      await db.execute(
        'ALTER TABLE highlights ADD COLUMN isPrivate INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE highlights ADD COLUMN anchorState TEXT');
      // Replies point at their note's uid, so every note needs one.
      await db.execute(
        'UPDATE highlights SET uid = lower(hex(randomblob(16))) '
        'WHERE uid IS NULL',
      );
      await _createRepliesTable(db);
    }
  }

  Future<void> _createRepliesTable(Database db) async {
    await db.execute('''
      CREATE TABLE annotation_replies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER,
        highlightUid TEXT,
        uid TEXT,
        author TEXT,
        text TEXT,
        audioFile TEXT,
        audioDurationMs INTEGER,
        audioWaveform TEXT,
        createdAt TEXT
      )
    ''');
  }

  // Book CRUD
  Future<int> insertBook(Book book) async {
    final db = await database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      orderBy: 'addedAt DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<int> updateBook(Book book) async {
    final db = await database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> deleteBook(int id) async {
    return await softDeleteBook(id);
  }

  Future<int> softDeleteBook(int id) async {
    final db = await database;
    return await db.update(
      'books',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDeleteBook(int id) async {
    final db = await database;
    final audioFiles = await _audioFilesForBook(db, id);
    await db.transaction((txn) async {
      await txn.delete(
        'reading_sessions',
        where: 'bookId = ?',
        whereArgs: [id],
      );
      await txn.delete('bookmarks', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('highlights', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete(
        'annotation_replies',
        where: 'bookId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'dictionary_lookups',
        where: 'bookId = ?',
        whereArgs: [id],
      );
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
    await AnnotationAudioService.deleteAll(audioFiles);
  }

  static const _appFolderKey = 'ios_app_folder';

  /// Points stored file paths at the app's folder after iOS moved it.
  ///
  /// iOS keeps an app's files in a folder whose path has an ID in it
  /// (`.../Data/Application/<ID>/Documents`), and gives the folder a new ID
  /// when the app is reinstalled or updated, so every absolute path in the
  /// database (books, covers, audio, voice notes) would point at the old
  /// one. The last folder is remembered, and when it changes, every text
  /// column has the old folder's path replaced by the new one.
  Future<void> followMovedAppFolder() async {
    if (!Platform.isIOS) return;
    final current = dirname(
      (await getApplicationDocumentsDirectory()).path,
    );
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_appFolderKey);
    if (previous != null && previous != current) {
      final db = await database;
      var changed = 0;
      await db.transaction((txn) async {
        final tables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
        );
        for (final table in tables.map((t) => t['name'] as String)) {
          final columns = await txn.rawQuery('PRAGMA table_info("$table")');
          for (final column in columns) {
            final type = (column['type'] as String? ?? '').toUpperCase();
            if (!type.contains('TEXT')) continue;
            final name = column['name'] as String;
            // The same folder is sometimes written /private/var/...
            for (final old in ['/private$previous', previous]) {
              changed += await txn.rawUpdate(
                'UPDATE "$table" SET "$name" = replace("$name", ?, ?) '
                'WHERE instr("$name", ?) > 0',
                [old, current, old],
              );
            }
          }
        }
      });
      debugPrint('App folder moved; updated $changed stored paths');
    }
    if (previous != current) await prefs.setString(_appFolderKey, current);
  }

  static const _cacheMigrationKey = 'migrated_files_out_of_cache';

  /// One-time move of book and audio files that still point at
  /// file_picker's copy in the cache dir, which Android may clear.
  ///
  /// Entries whose file is already gone are left as they are. If any copy
  /// fails, the migration runs again on the next start.
  Future<void> migrateCachedFilePaths() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cacheMigrationKey) ?? false) return;

    final db = await database;
    final rows = await db.query('books'); // soft-deleted books too
    final moved = <String, String>{}; // cache path -> durable path
    var failed = false;

    // Returns the durable path for [path], copying the file if needed, or
    // null when it isn't in the cache or no longer exists.
    Future<String?> relocate(
      Object? path,
      Future<Directory> Function() targetDir,
    ) async {
      if (path is! String || path.isEmpty) return null;
      if (moved.containsKey(path)) return moved[path];
      if (!await FileStorageService.isInCache(path)) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      try {
        final stored = await FileStorageService.copyInto(
          file,
          await targetDir(),
        );
        return moved[path] = stored.path;
      } catch (e) {
        debugPrint('Could not move $path out of the cache: $e');
        failed = true;
        return null;
      }
    }

    for (final row in rows) {
      final id = row['id'] as int;
      Future<Directory> audioDir() => FileStorageService.audioDir(id);
      final changes = <String, Object?>{};

      final filePath = row['filePath'];
      final newFilePath = await relocate(
        filePath,
        FileStorageService.booksDir,
      );
      if (newFilePath != null) {
        changes['filePath'] = newFilePath;
        if (row['folderPath'] == dirname(filePath as String)) {
          changes['folderPath'] = dirname(newFilePath);
        }
      }

      final newAudioPath = await relocate(row['audioPath'], audioDir);
      if (newAudioPath != null) changes['audioPath'] = newAudioPath;

      final tracksJson = row['audioTracks'];
      if (tracksJson is String && tracksJson.isNotEmpty) {
        try {
          final tracks = json.decode(tracksJson) as List<dynamic>;
          var tracksChanged = false;
          for (final track in tracks) {
            if (track is! Map) continue;
            final newPath = await relocate(track['path'], audioDir);
            if (newPath != null) {
              track['path'] = newPath;
              tracksChanged = true;
            }
          }
          if (tracksChanged) changes['audioTracks'] = json.encode(tracks);
        } catch (e) {
          debugPrint('Skipping unreadable audio tracks of book $id: $e');
        }
      }

      if (changes.isNotEmpty) {
        await db.update('books', changes, where: 'id = ?', whereArgs: [id]);
      }
    }

    if (failed) return;
    for (final path in moved.keys) {
      await FileStorageService.deleteCachedCopy(path);
    }
    await prefs.setBool(_cacheMigrationKey, true);
    debugPrint('Moved ${moved.length} files out of the cache dir');
  }

  Future<int> restoreBook(int id) async {
    final db = await database;
    return await db.update(
      'books',
      {'isDeleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Bookmark CRUD
  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.insert('bookmarks', bookmark.toMap());
  }

  Future<List<Bookmark>> getBookmarks(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Bookmark.fromMap(maps[i]));
  }

  Future<int> deleteBookmark(int id) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // Activity CRUD
  Future<int> insertReadingSession(int bookId, int pages, int duration) async {
    final db = await database;
    final now = DateTime.now();
    final date = now.toIso8601String().split('T')[0];
    return await db.insert('reading_sessions', {
      'bookId': bookId,
      'date': date,
      'pagesRead': pages,
      'durationMinutes': duration,
      'timestamp': now.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getReadingSessions() async {
    final db = await database;
    return await db.query('reading_sessions', orderBy: 'date DESC');
  }

  // Quest CRUD
  Future<int> insertQuest(Map<String, dynamic> quest) async {
    final db = await database;
    return await db.insert(
      'quests',
      quest,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQuestsForDate(String date) async {
    final db = await database;
    return await db.query('quests', where: 'date = ?', whereArgs: [date]);
  }

  Future<int> updateQuestProgress(
    String id,
    int currentValue,
    bool isCompleted,
  ) async {
    final db = await database;
    return await db.update(
      'quests',
      {'currentValue': currentValue, 'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getTotalQuestXP() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(xpReward) as total FROM quests WHERE isCompleted = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Highlight CRUD
  Future<int> insertHighlight(Highlight highlight) async {
    final db = await database;
    final withUid = highlight.uid == null
        ? highlight.copyWith(uid: Highlight.generateUid())
        : highlight;
    return await db.insert('highlights', withUid.toMap());
  }

  Future<List<Highlight>> getHighlightsForBook(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'highlights',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Highlight.fromMap(maps[i]));
  }

  Future<Highlight?> getHighlightByUid(int bookId, String uid) async {
    final db = await database;
    final maps = await db.query(
      'highlights',
      where: 'bookId = ? AND uid = ?',
      whereArgs: [bookId, uid],
      limit: 1,
    );
    return maps.isEmpty ? null : Highlight.fromMap(maps.first);
  }

  Future<int> updateHighlight(Highlight highlight) async {
    final db = await database;
    return await db.update(
      'highlights',
      highlight.toMap(),
      where: 'id = ?',
      whereArgs: [highlight.id],
    );
  }

  /// Deletes a highlight with its voice note and the replies under it.
  Future<int> deleteHighlight(int id) async {
    final db = await database;
    final rows = await db.query(
      'highlights',
      columns: ['audioFile', 'uid', 'bookId'],
      where: 'id = ?',
      whereArgs: [id],
    );
    final audioFiles = rows.map((r) => r['audioFile'] as String?).toList();
    for (final row in rows) {
      final uid = row['uid'] as String?;
      if (uid == null) continue;
      final where = 'bookId = ? AND highlightUid = ?';
      final args = [row['bookId'], uid];
      final replies = await db.query(
        'annotation_replies',
        columns: ['audioFile'],
        where: where,
        whereArgs: args,
      );
      audioFiles.addAll(replies.map((r) => r['audioFile'] as String?));
      await db.delete('annotation_replies', where: where, whereArgs: args);
    }
    final count = await db.delete(
      'highlights',
      where: 'id = ?',
      whereArgs: [id],
    );
    await AnnotationAudioService.deleteAll(audioFiles);
    return count;
  }

  Future<int> deleteHighlightsForBook(int bookId) async {
    final db = await database;
    final audioFiles = await _audioFilesForBook(db, bookId);
    final count = await db.delete(
      'highlights',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    await db.delete(
      'annotation_replies',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
    await AnnotationAudioService.deleteAll(audioFiles);
    return count;
  }

  Future<List<String?>> _audioFilesForBook(Database db, int bookId) async {
    final files = <String?>[];
    for (final table in ['highlights', 'annotation_replies']) {
      final rows = await db.query(
        table,
        columns: ['audioFile'],
        where: 'bookId = ? AND audioFile IS NOT NULL',
        whereArgs: [bookId],
      );
      files.addAll(rows.map((r) => r['audioFile'] as String?));
    }
    return files;
  }

  // Reply CRUD
  Future<List<AnnotationReply>> getRepliesForBook(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'annotation_replies',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'createdAt ASC',
    );
    return maps.map(AnnotationReply.fromMap).toList();
  }

  Future<AnnotationReply?> getReplyByUid(int bookId, String uid) async {
    final db = await database;
    final maps = await db.query(
      'annotation_replies',
      where: 'bookId = ? AND uid = ?',
      whereArgs: [bookId, uid],
      limit: 1,
    );
    return maps.isEmpty ? null : AnnotationReply.fromMap(maps.first);
  }

  Future<int> insertReply(AnnotationReply reply) async {
    final db = await database;
    return db.insert('annotation_replies', reply.toMap());
  }

  Future<int> updateReply(AnnotationReply reply) async {
    final db = await database;
    return db.update(
      'annotation_replies',
      reply.toMap(),
      where: 'id = ?',
      whereArgs: [reply.id],
    );
  }

  Future<int> deleteReply(int id) async {
    final db = await database;
    final rows = await db.query(
      'annotation_replies',
      columns: ['audioFile'],
      where: 'id = ?',
      whereArgs: [id],
    );
    final count = await db.delete(
      'annotation_replies',
      where: 'id = ?',
      whereArgs: [id],
    );
    await AnnotationAudioService.deleteAll(
      rows.map((r) => r['audioFile'] as String?),
    );
    return count;
  }

  // Dictionary Lookup CRUD
  Future<int> insertDictionaryLookup(String word, int bookId) async {
    final db = await database;

    // Deduplication: Check if this word was already looked up in this book
    final existing = await db.query(
      'dictionary_lookups',
      where: 'word = ? AND bookId = ?',
      whereArgs: [word, bookId],
    );

    if (existing.isNotEmpty) {
      // Just update the timestamp
      return await db.update(
        'dictionary_lookups',
        {'timestamp': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }

    return await db.insert('dictionary_lookups', {
      'bookId': bookId,
      'word': word,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<VocabularyLookup>> getDictionaryLookupsForBook(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'dictionary_lookups',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => VocabularyLookup.fromMap(maps[i]));
  }

  Future<int> getDictionaryLookupCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM dictionary_lookups',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
