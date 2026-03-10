import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/download_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'dirxplore_downloads.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloads(
        id TEXT PRIMARY KEY,
        url TEXT,
        fileName TEXT,
        savePath TEXT,
        batchId TEXT,
        batchName TEXT,
        status INTEGER,
        totalBytes INTEGER,
        downloadedBytes INTEGER,
        retryCount INTEGER,
        errorMessage TEXT,
        addedAt TEXT
      )
    ''');
    await _createTorrentsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTorrentsTable(db);
    }
  }

  Future<void> _createTorrentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE torrents(
        id TEXT PRIMARY KEY,
        name TEXT,
        hash TEXT,
        magnetLink TEXT,
        savePath TEXT,
        status INTEGER,
        progress REAL,
        size TEXT,
        speed TEXT,
        addedAt TEXT
      )
    ''');
  }

  Future<int> insertDownload(DownloadItem item) async {
    final db = await database;
    return await db.insert(
      'downloads',
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DownloadItem>> getDownloads() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloads');
    return List.generate(maps.length, (i) {
      return DownloadItem.fromJson(maps[i]);
    });
  }

  Future<int> updateDownload(DownloadItem item) async {
    final db = await database;
    return await db.update(
      'downloads',
      item.toJson(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteDownload(String id) async {
    final db = await database;
    return await db.delete(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('downloads');
    await db.delete('torrents');
  }

  // --- Torrent Methods ---
  Future<int> insertTorrent(Map<String, dynamic> torrent) async {
    final db = await database;
    return await db.insert(
      'torrents',
      torrent,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTorrents() async {
    final db = await database;
    return await db.query('torrents', orderBy: 'addedAt DESC');
  }

  Future<int> updateTorrent(Map<String, dynamic> torrent) async {
    final db = await database;
    return await db.update(
      'torrents',
      torrent,
      where: 'id = ?',
      whereArgs: [torrent['id']],
    );
  }

  Future<int> deleteTorrent(String id) async {
    final db = await database;
    return await db.delete(
      'torrents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
