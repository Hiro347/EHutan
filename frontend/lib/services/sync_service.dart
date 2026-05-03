import 'package:supabase_flutter/supabase_flutter.dart';
import 'sqlite_service.dart';

class SyncService {
  final SqliteService _sqliteService;
  final _supabase = Supabase.instance.client;

  SyncService(this._sqliteService);

  // Fungsi utama untuk sinkronisasi
  Future<void> syncData() async {
    try {
      // 1. Ambil data yang berstatus "draft lokal" (is_synced = 0)
      final unsyncedData = await _sqliteService.getUnsyncedObservasi();
      
      if (unsyncedData.isEmpty) {
        print('Tidak ada data yang perlu disinkronisasi.');
        return; 
      }

      // 2. Loop setiap data dan lempar ke Supabase
      for (var item in unsyncedData) {
        // Buat copy data untuk memanipulasi isinya
        final dataToPush = Map<String, dynamic>.from(item);
        
        // Hapus kolom is_synced karena tidak ada di tabel Supabase
        dataToPush.remove('is_synced');

        // Gunakan upsert agar jika id sudah ada, data di-update (menghindari duplikasi)
        await _supabase.from('data_observasi').upsert(dataToPush);
        
        // 3. Jika berhasil terkirim tanpa error, update status di lokal
        await _sqliteService.markAsSynced(item['id']);
      }
      
      print("Sinkronisasi berhasil!");
    } catch (e) {
      // Jangan panik jika gagal, data masih aman di SQLite dan akan diulang di sync berikutnya
      print("Sinkronisasi gagal. Menunggu koneksi internet... Error: $e");
    }
  }
}