import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/sqlite_service.dart';
import '../services/sync_service.dart';

final sqliteServiceProvider = Provider<SqliteService>((ref) {
  return SqliteService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final sqliteService = ref.read(sqliteServiceProvider);
  return SyncService(sqliteService);
});

// Provider untuk jumlah data belum sync (ditampilkan di UI)
final unsyncedCountProvider = FutureProvider<int>((ref) async {
  final sqliteService = ref.read(sqliteServiceProvider);
  final data = await sqliteService.getUnsyncedObservasi();
  return data.length;
});

class LocalObservationNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchUnsyncedData();
  }

  Future<List<Map<String, dynamic>>> _fetchUnsyncedData() async {
    final sqliteService = ref.read(sqliteServiceProvider);
    return await sqliteService.getUnsyncedObservasi();
  }

  /// Ambil foto dari kamera/galeri, simpan ke local storage permanen
  Future<String?> pickAndSaveFoto({bool fromCamera = true}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return null;

    // Simpan ke folder permanen (bukan temp, supaya tidak dihapus OS)
    final dir = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final ext = picked.path.split('.').last;
    final dest = File('${dir.path}/pending_foto/$id.$ext');
    await dest.parent.create(recursive: true);
    await File(picked.path).copy(dest.path);

    return dest.path; // kembalikan local path
  }

  /// Submit observasi baru — simpan lokal dulu, sync kalau online
  Future<void> addObservation({
    required String namaSpesies,
    required String kategoriTakson,
    required double latitude,
    required double longitude,
    required String idPetugas,
    required String localFotoPath, // dari pickAndSaveFoto()
    int? idKegiatan,
    String? catatanHabitat,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      final now = DateTime.now().toIso8601String();
      final id = const Uuid().v4();

      await sqliteService.insertObservasi({
        'id': id,
        'id_petugas': idPetugas,
        'id_kegiatan': idKegiatan,
        'nama_spesies': namaSpesies,
        'kategori_takson': kategoriTakson,
        'latitude': latitude,
        'longitude': longitude,
        'foto_url': '',             // ← kosong dulu, diisi setelah sync
        'local_foto_path': localFotoPath, // ← path lokal foto
        'catatan_habitat': catatanHabitat,
        'waktu_pengamatan': now,
        'status_approval': 'MENUNGGU_VERIFIKASI',
        'is_synced': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Coba sync langsung kalau online
      final conn = await Connectivity().checkConnectivity();
      if (!conn.contains(ConnectivityResult.none)) {
        await ref.read(syncServiceProvider).syncData();
      }

      return _fetchUnsyncedData();
    });
  }
}

final localObservationProvider =
    AsyncNotifierProvider<LocalObservationNotifier,
        List<Map<String, dynamic>>>(() {
  return LocalObservationNotifier();
});