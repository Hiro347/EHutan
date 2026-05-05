// lib/providers/observation_provider.dart
// Update: tambah namaLokal, jumlahIndividu, aktivitasTermati ke addObservation()

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

    final dir = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final ext = picked.path.split('.').last;
    final dest = File('${dir.path}/pending_foto/$id.$ext');
    await dest.parent.create(recursive: true);
    await File(picked.path).copy(dest.path);

    return dest.path;
  }

  /// Submit observasi baru — simpan lokal dulu, sync kalau online
  Future<void> addObservation({
    required String namaSpesies,
    String? namaLokal,              // ← Baru
    required String kategoriTakson,
    required double latitude,
    required double longitude,
    required String idPetugas,
    String localFotoPath = '',
    int? idKegiatan,
    String? catatanHabitat,
    int? jumlahIndividu,            // ← Baru
    String? aktivitasTermati,       // ← Baru
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
        'nama_lokal': namaLokal,
        'kategori_takson': kategoriTakson,
        'latitude': latitude,
        'longitude': longitude,
        'foto_url': '',
        'local_foto_path': localFotoPath.isNotEmpty ? localFotoPath : null,
        'catatan_habitat': catatanHabitat,
        'waktu_pengamatan': now,
        'status_approval': 'MENUNGGU_VERIFIKASI',
        'jumlah_individu': jumlahIndividu,
        'aktivitas_termati': aktivitasTermati,
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

  //delete observation
  Future<void> deleteObservation(String id) async {
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      await sqliteService.deleteObservasi(id);
      return _fetchUnsyncedData();
    });
  }
}

final localObservationProvider =
    AsyncNotifierProvider<LocalObservationNotifier,
        List<Map<String, dynamic>>>(() {
  return LocalObservationNotifier();
});