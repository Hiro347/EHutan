import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqliteService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ehutan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ← naik dari 1 ke 2
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // ← tambah ini
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE data_observasi (
        id TEXT PRIMARY KEY,
        id_petugas TEXT,
        id_kegiatan INTEGER,
        nama_spesies TEXT,
        kategori_takson TEXT,
        latitude REAL,
        longitude REAL,
        foto_url TEXT,           -- storage path Supabase (diisi setelah sync)
        local_foto_path TEXT,    -- path foto lokal di device (hanya saat offline)
        catatan_habitat TEXT,
        waktu_pengamatan TEXT,
        status_approval TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  // Migrasi database dari versi lama
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE data_observasi ADD COLUMN local_foto_path TEXT',
      );
    }
  }

  Future<void> insertObservasi(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'data_observasi',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedObservasi() async {
    final db = await database;
    return await db.query(
      'data_observasi',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markAsSynced(String id, String storageUrl) async {
    final db = await database;
    await db.update(
      'data_observasi',
      {
        'is_synced': 1,
        'foto_url': storageUrl,      // ← simpan storage path setelah sync
        'local_foto_path': null,     // ← bersihkan path lokal
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}