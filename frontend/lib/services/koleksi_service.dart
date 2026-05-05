// lib/services/koleksi_service.dart
// Service khusus untuk fitur Koleksi (fetch "Observasi Saya" & "Observasi UKF").
// Sengaja dipisah dari supabase_service.dart agar tidak conflict dengan task form.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observation.dart';

class KoleksiService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'data_observasi';

  // ─── Kolom yang di-select ────────────────────────────────────────────────
  // Pastikan field baru sudah ada di schema Supabase (lihat migration di observation.dart)
  static const String _selectColumns = '''
    id,
    id_petugas,
    id_kegiatan,
    nama_spesies,
    nama_lokal,
    kategori_takson,
    latitude,
    longitude,
    foto_url,
    catatan_habitat,
    waktu_pengamatan,
    status_approval,
    id_kordinator,
    catatan_revisi,
    waktu_verifikasi,
    created_at,
    updated_at,
    jumlah_individu,
    aktivitas_termati,
    profiles!id_petugas(nama_lengkap)
  ''';

  /// Fetch observasi milik user yang sedang login (tab "Observasi Saya")
  Future<List<Observation>> fetchObservasiSaya() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from(_table)
        .select(_selectColumns)
        .eq('id_petugas', userId)
        .order('waktu_pengamatan', ascending: false);

    return (response as List)
        .map((json) => Observation.fromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch semua observasi dari seluruh anggota (tab "Observasi UKF")
  Future<List<Observation>> fetchObservasiUKF({String? searchQuery}) async {
    var query = _client
        .from(_table)
        .select(_selectColumns)
        .eq('status_approval', 'TERVERIFIKASI'); // Hanya tampilkan yang sudah terverifikasi

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or(
        'nama_spesies.ilike.%$searchQuery%,nama_lokal.ilike.%$searchQuery%,kategori_takson.ilike.%$searchQuery%',
      );
    }

    final response = await query.order('waktu_pengamatan', ascending: false);

    return (response as List)
        .map((json) => Observation.fromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch observasi UKF, dikelompokkan per kategori_takson
  Future<Map<String, List<Observation>>> fetchObservasiUKFGrouped({
    String? searchQuery,
  }) async {
    final list = await fetchObservasiUKF(searchQuery: searchQuery);

    final Map<String, List<Observation>> grouped = {};
    for (final obs in list) {
      final key = obs.kategoriTakson.toUpperCase();
      grouped.putIfAbsent(key, () => []).add(obs);
    }

    // Urutkan key secara alfabetis supaya consistent
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Fetch satu detail observasi berdasarkan ID
  Future<Observation?> fetchObservasiById(String id) async {
    final response = await _client
        .from(_table)
        .select(_selectColumns)
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Observation.fromSupabase(response as Map<String, dynamic>);
  }
}