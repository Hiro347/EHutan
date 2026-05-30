// lib/providers/observation_provider.dart
// Update: tambah namaLokal, jumlahIndividu, aktivitasTermati ke addObservation()

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/sqlite_service.dart';
import '../services/sync_service.dart';

final sqliteServiceProvider = Provider<SqliteService>((ref) {
  return SqliteService();
});

class RefreshTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() {
    state++;
  }
}

final refreshTriggerProvider = NotifierProvider<RefreshTriggerNotifier, int>(() {
  return RefreshTriggerNotifier();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final sqliteService = ref.read(sqliteServiceProvider);
  return SyncService(sqliteService, onSyncCompleted: () {
    ref.read(refreshTriggerProvider.notifier).trigger();
  });
});

// Provider untuk jumlah data belum sync (ditampilkan di UI)
final unsyncedCountProvider = FutureProvider<int>((ref) async {
  final sqliteService = ref.read(sqliteServiceProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;
  final data = await sqliteService.getUnsyncedObservasi(userId);
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    return await sqliteService.getUnsyncedObservasi(userId);
  }

  static const int _maxPhotoBytes = 10 * 1024 * 1024; // 10 MB

  /// Ambil foto dari kamera/galeri, simpan ke local storage permanen.
  /// Throws Exception jika file > 10MB (TC_OBS_003 fix).
  Future<String?> pickAndSaveFoto({bool fromCamera = true}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return null;

    // Validasi ukuran file sebelum disimpan (max 10MB)
    final fileSize = await File(picked.path).length();
    if (fileSize > _maxPhotoBytes) {
      throw Exception(
        'Ukuran foto terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maksimum 10 MB. Silakan ambil foto ulang.',
      );
    }
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
    String? namaLokal, // ← Baru
    required String kategoriTakson,
    required double latitude,
    required double longitude,
    required String idPetugas,
    String localFotoPath = '',
    int? idKegiatan,
    String? catatanHabitat,
    int? jumlahIndividu, // ← Baru
    String? aktivitasTermati, // ← Baru
    DateTime? waktuPengamatan,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      final now = DateTime.now().toIso8601String();
      final waktu = (waktuPengamatan ?? DateTime.now()).toIso8601String();
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
        'waktu_pengamatan': waktu,
        'status_approval': 'MENUNGGU_VERIFIKASI',
        'jumlah_individu': jumlahIndividu,
        'aktivitas_termati': aktivitasTermati,
        'is_synced': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Pemicu global refresh setelah sukses insert lokal
      ref.read(refreshTriggerProvider.notifier).trigger();

      // Coba sync langsung kalau online - jika gagal, data tetap aman di SQLite
      try {
        final conn = await Connectivity().checkConnectivity();
        if (!conn.contains(ConnectivityResult.none)) {
          await ref.read(syncServiceProvider).syncData();
        }
      } catch (e) {
        debugPrint('Sync gagal setelah addObservation: $e');
      }

      return _fetchUnsyncedData();
    });
  }

  /// Update observasi yang sudah ada (mode edit) — status direset ke MENUNGGU_VERIFIKASI
  Future<void> updateObservation({
    required String id,
    required String namaSpesies,
    String? namaLokal,
    required String kategoriTakson,
    required double latitude,
    required double longitude,
    String localFotoPath = '',
    String existingFotoUrl = '',
    String? catatanHabitat,
    int? jumlahIndividu,
    String? aktivitasTermati,
    required DateTime waktuPengamatan,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      final now = DateTime.now().toIso8601String();

      await sqliteService.updateObservasi(id, {
        'nama_spesies': namaSpesies,
        'nama_lokal': namaLokal,
        'kategori_takson': kategoriTakson,
        'latitude': latitude,
        'longitude': longitude,
        // Jika user mengganti foto, pakai path baru; jika tidak, tetap pakai foto lama
        'local_foto_path': localFotoPath.isNotEmpty ? localFotoPath : null,
        'foto_url': localFotoPath.isNotEmpty ? '' : existingFotoUrl,
        'catatan_habitat': catatanHabitat,
        'waktu_pengamatan': waktuPengamatan.toIso8601String(),
        // Reset ke menunggu verifikasi ulang
        'status_approval': 'MENUNGGU_VERIFIKASI',
        'id_kordinator': null,
        'catatan_revisi': null,
        'waktu_verifikasi': null,
        'jumlah_individu': jumlahIndividu,
        'aktivitas_termati': aktivitasTermati,
        'is_synced': 0,
        'updated_at': now,
      });

      // Pemicu global refresh setelah sukses update lokal
      ref.read(refreshTriggerProvider.notifier).trigger();

      // Coba sync langsung kalau online - jika gagal, data tetap aman di SQLite
      try {
        final conn = await Connectivity().checkConnectivity();
        if (!conn.contains(ConnectivityResult.none)) {
          await ref.read(syncServiceProvider).syncData();
        }
      } catch (e) {
        debugPrint('Sync gagal setelah updateObservation: $e');
      }

      return _fetchUnsyncedData();
    });
  }

  //delete observation
  Future<void> deleteObservation(String id) async {
    state = await AsyncValue.guard(() async {
      final sqliteService = ref.read(sqliteServiceProvider);
      await sqliteService.deleteObservasi(id);

      try {
        await Supabase.instance.client
            .from('data_observasi')
            .delete()
            .eq('id', id);
      } catch (e) {
        print('Error deleting from Supabase: $e');
      }

      // Pemicu global refresh setelah hapus
      ref.read(refreshTriggerProvider.notifier).trigger();
      return _fetchUnsyncedData();
    });
  }
}

final localObservationProvider =
    AsyncNotifierProvider<LocalObservationNotifier, List<Map<String, dynamic>>>(
      () {
        return LocalObservationNotifier();
      },
    );
