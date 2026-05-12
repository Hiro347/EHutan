import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sqlite_service.dart';

class SyncService {
  final SqliteService _sqliteService;
  final _supabase = Supabase.instance.client;

  SyncService(this._sqliteService);

  Future<void> syncData() async {
    final unsyncedData = await _sqliteService.getUnsyncedObservasi();
    if (unsyncedData.isEmpty) return;

    int successCount = 0;

    for (var item in unsyncedData) {
      try {
        final dataToPush = Map<String, dynamic>.from(item);

        // 1. Upload foto lokal ke Supabase Storage
        final localFotoPath = dataToPush['local_foto_path'] as String?;
        String storageUrl = dataToPush['foto_url'] ?? '';
        bool fotoUploaded = false;

        if (localFotoPath != null && localFotoPath.isNotEmpty) {
          final fotoFile = File(localFotoPath);

          if (await fotoFile.exists()) {
            final userId = _supabase.auth.currentUser!.id;
            final ext = localFotoPath.split('.').last;
            final storagePath = 'observasi/$userId/${item['id']}.$ext';

            try {
              await _supabase.storage
                  .from('Foto_Observasi')
                  .upload(storagePath, fotoFile);
              storageUrl = storagePath;
              fotoUploaded = true;
            } catch (e) {
              debugPrint('Upload foto gagal [${item['id']}]: $e');
              // Foto gagal upload — tetap sync data tapi jangan hapus file lokal
            }
          }
        }

        // 2. Bersihkan kolom yang tidak ada di Supabase
        dataToPush.remove('is_synced');
        dataToPush.remove('local_foto_path');
        dataToPush['foto_url'] = storageUrl;

        // 3. Push ke Supabase
        await _supabase.from('data_observasi').upsert(dataToPush);

        // 4. Tandai sudah sync di SQLite
        await _sqliteService.markAsSynced(item['id'], storageUrl);

        // 5. Hapus foto lokal HANYA kalau upload berhasil
        if (fotoUploaded && localFotoPath != null) {
          try {
            await File(localFotoPath).delete();
          } catch (_) {}
        }

        successCount++;
      } catch (e) {
        debugPrint('Sync gagal untuk [${item['id']}]: $e');
        // Lanjut ke item berikutnya, jangan berhenti total
      }
    }

    debugPrint('Sinkronisasi: $successCount/${unsyncedData.length} berhasil');
  }
}