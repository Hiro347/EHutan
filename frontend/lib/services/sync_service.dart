import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sqlite_service.dart';

class SyncService {
  final SqliteService _sqliteService;
  final _supabase = Supabase.instance.client;

  SyncService(this._sqliteService);

  Future<void> syncData() async {
    try {
      final unsyncedData = await _sqliteService.getUnsyncedObservasi();

      if (unsyncedData.isEmpty) return;

      for (var item in unsyncedData) {
        final dataToPush = Map<String, dynamic>.from(item);

        // 1. Upload foto lokal ke Supabase Storage dulu
        final localFotoPath = dataToPush['local_foto_path'] as String?;
        String storageUrl = dataToPush['foto_url'] ?? '';

        if (localFotoPath != null && localFotoPath.isNotEmpty) {
          final fotoFile = File(localFotoPath);

          if (await fotoFile.exists()) {
            final userId = _supabase.auth.currentUser!.id;
            final ext = localFotoPath.split('.').last;
            final storagePath = 'observasi/$userId/${item['id']}.$ext';

            await _supabase.storage
                .from('Foto_Observasi') // ← sesuai nama bucket kamu
                .upload(storagePath, fotoFile);

            storageUrl = storagePath;

            // Hapus foto lokal setelah berhasil upload
            await fotoFile.delete();
          }
        }

        // 2. Bersihkan kolom yang tidak ada di Supabase
        dataToPush.remove('is_synced');
        dataToPush.remove('local_foto_path');
        dataToPush['foto_url'] = storageUrl; // ← pakai storage path

        // 3. Push ke Supabase
        await _supabase.from('data_observasi').upsert(dataToPush);

        // 4. Tandai sudah sync + simpan storage URL ke SQLite
        await _sqliteService.markAsSynced(item['id'], storageUrl);
      }

      debugPrint('Sinkronisasi berhasil: ${unsyncedData.length} data');
    } catch (e) {
      debugPrint('Sinkronisasi gagal: $e');
    }
  }
}