import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sqlite_service.dart';

// 1. Provider dasar untuk SqliteService
final sqliteServiceProvider = Provider<SqliteService>((ref) {
  return SqliteService();
});

// 2. AsyncNotifier untuk me-manage state data observasi lokal
class LocalObservationNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Saat pertama kali dirender, load data yang belum tersinkronisasi
    return _fetchUnsyncedData();
  }

  Future<List<Map<String, dynamic>>> _fetchUnsyncedData() async {
    final sqliteService = ref.read(sqliteServiceProvider);
    return await sqliteService.getUnsyncedObservasi();
  }

  // Fungsi yang dipanggil UI saat petugas menekan "Simpan Draft"
  Future<void> addObservation(Map<String, dynamic> newObservation) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      
      // Pastikan data diset sebagai unsynced
      newObservation['is_synced'] = 0; 
      
      await sqliteService.insertObservasi(newObservation);
      
      // Refresh list
      return _fetchUnsyncedData();
    });
  }
}

// 3. Provider yang akan di-watch oleh UI
final localObservationProvider = 
    AsyncNotifierProvider<LocalObservationNotifier, List<Map<String, dynamic>>>(() {
  return LocalObservationNotifier();
});