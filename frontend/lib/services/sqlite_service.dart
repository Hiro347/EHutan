// lib/services/sqlite_service.dart
// v3: tambah kolom nama_lokal, jumlah_individu, aktivitas_termati
// + method getAllObservasi() dan getObservasiByUser() untuk koleksi screen

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
      version: 3, // ← naik ke 3
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE data_observasi (
        id TEXT PRIMARY KEY,
        id_petugas TEXT,
        id_kegiatan INTEGER,
        nama_spesies TEXT,
        nama_lokal TEXT,
        kategori_takson TEXT,
        latitude REAL,
        longitude REAL,
        foto_url TEXT,
        local_foto_path TEXT,
        catatan_habitat TEXT,
        waktu_pengamatan TEXT,
        status_approval TEXT,
        id_kordinator TEXT,
        catatan_revisi TEXT,
        waktu_verifikasi TEXT,
        jumlah_individu INTEGER,
        aktivitas_termati TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE data_observasi ADD COLUMN local_foto_path TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE data_observasi ADD COLUMN nama_lokal TEXT',
      );
      await db.execute(
        'ALTER TABLE data_observasi ADD COLUMN jumlah_individu INTEGER',
      );
      await db.execute(
        'ALTER TABLE data_observasi ADD COLUMN aktivitas_termati TEXT',
      );
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> insertObservasi(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'data_observasi',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markAsSynced(String id, String storageUrl) async {
    final db = await database;
    await db.update(
      'data_observasi',
      {
        'is_synced': 1,
        'foto_url': storageUrl,
        'local_foto_path': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Hanya data yang belum tersinkron (untuk SyncService)
  Future<List<Map<String, dynamic>>> getUnsyncedObservasi() async {
    final db = await database;
    return await db.query(
      'data_observasi',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
  }

  /// Semua observasi lokal (untuk tab "Observasi Saya" di KoleksiScreen)
  Future<List<Map<String, dynamic>>> getAllObservasi() async {
    final db = await database;
    return await db.query(
      'data_observasi',
      orderBy: 'waktu_pengamatan DESC',
    );
  }

  /// Observasi milik satu user (filter by id_petugas)
  Future<List<Map<String, dynamic>>> getObservasiByUser(String userId) async {
    final db = await database;
    return await db.query(
      'data_observasi',
      where: 'id_petugas = ?',
      whereArgs: [userId],
      orderBy: 'waktu_pengamatan DESC',
    );
  }

  //Menghapus data observasi
  Future<void> deleteObservasi(String id) async {
    final db = await database;
    await db.delete(
      'data_observasi',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}