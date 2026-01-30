import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book_model.dart';

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
      version: 3,
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
        folderPath TEXT
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
    final db = await database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
