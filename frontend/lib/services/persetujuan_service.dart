import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observation.dart';
import '../models/user_profile.dart';

class PersetujuanService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> fetchCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromMap(response);
  }

  Future<List<Observation>> fetchPersetujuanPetugas(String userId) async {
    final response = await _client
        .from('data_observasi')
        .select('*, profiles!id_petugas(nama_lengkap, avatar_url)')
        .eq('id_petugas', userId)
        .order('waktu_pengamatan', ascending: false);

    return (response as List)
        .map((json) => Observation.fromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Observation>> fetchMenungguVerifikasi({
    required bool isAdmin,
    String? divisi,
  }) async {
    var query = _client
        .from('data_observasi')
        .select('*, profiles!id_petugas(nama_lengkap, avatar_url)')
        .eq('status_approval', 'MENUNGGU_VERIFIKASI');

    if (!isAdmin && divisi != null) {
      query = query.eq('kategori_takson', divisi);
    }

    final response = await query.order('waktu_pengamatan', ascending: true);

    return (response as List)
        .map((json) => Observation.fromSupabase(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus({
    required String obsId,
    required String statusApproval,
    String? catatanRevisi,
  }) async {
    final kordinatorId = _client.auth.currentUser?.id;

    await _client
        .from('data_observasi')
        .update({
          'status_approval': statusApproval,
          'catatan_revisi': catatanRevisi,
          'id_kordinator': kordinatorId,
          'waktu_verifikasi': DateTime.now().toIso8601String(),
        })
        .eq('id', obsId);
  }
}
