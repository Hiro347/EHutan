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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabel lokal mirror dari Supabase dengan tambahan kolom is_synced
    await db.execute('''
      CREATE TABLE data_observasi (
        id TEXT PRIMARY KEY,
        id_petugas TEXT,
        id_kegiatan INTEGER,
        nama_spesies TEXT,
        kategori_takson TEXT,
        latitude REAL,
        longitude REAL,
        foto_url TEXT,          -- Menyimpan path lokal gambar saat offline
        catatan_habitat TEXT,
        waktu_pengamatan TEXT,  -- Simpan dalam format ISO8601 String
        status_approval TEXT,
        is_synced INTEGER DEFAULT 0, -- 0 = Belum Sync, 1 = Sudah Sync
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  // Insert data baru (selalu simpan ke lokal dulu)
  Future<void> insertObservasi(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'data_observasi',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Mengambil data yang belum di-sync untuk dilempar ke Supabase nanti
  Future<List<Map<String, dynamic>>> getUnsyncedObservasi() async {
    final db = await database;
    return await db.query(
      'data_observasi',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  // Update status sync setelah berhasil masuk ke Supabase
  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      'data_observasi',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}