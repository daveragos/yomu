import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../models/highlight_model.dart';

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
    String path = join(await getDatabasesPath(), 'yomu.db');
    return await openDatabase(
      path,
      version: 16,
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
        position TEXT
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
    await db.transaction((txn) async {
      await txn.delete(
        'reading_sessions',
        where: 'bookId = ?',
        whereArgs: [id],
      );
      await txn.delete('bookmarks', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('highlights', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
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
    return await db.insert('highlights', highlight.toMap());
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

  Future<int> updateHighlight(Highlight highlight) async {
    final db = await database;
    return await db.update(
      'highlights',
      highlight.toMap(),
      where: 'id = ?',
      whereArgs: [highlight.id],
    );
  }

  Future<int> deleteHighlight(int id) async {
    final db = await database;
    return await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHighlightsForBook(int bookId) async {
    final db = await database;
    return await db.delete(
      'highlights',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }
}
