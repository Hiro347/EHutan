// lib/models/observation.dart
// Update: tambah namaLokal, jumlahIndividu, aktivitasTermati
// SQL Migration (Supabase):
//   ALTER TABLE data_observasi
//     ADD COLUMN IF NOT EXISTS nama_lokal TEXT,
//     ADD COLUMN IF NOT EXISTS jumlah_individu INTEGER,
//     ADD COLUMN IF NOT EXISTS aktivitas_termati TEXT;

class Observation {
  final String id;
  final String idPetugas;
  final int? idKegiatan;
  final String namaSpesies;
  final String? namaLokal;         // ← Baru
  final String kategoriTakson;
  final double latitude;
  final double longitude;
  final String fotoUrl;
  final String? catatanHabitat;
  final DateTime waktuPengamatan;
  final String statusApproval;
  final String? idKordinator;
  final String? catatanRevisi;
  final DateTime? waktuVerifikasi;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? jumlahIndividu;       // ← Baru
  final String? aktivitasTermati;  // ← Baru

  // Hanya ada di SQLite lokal — tidak dikirim ke Supabase
  final bool isSynced;

  const Observation({
    required this.id,
    required this.idPetugas,
    this.idKegiatan,
    required this.namaSpesies,
    this.namaLokal,
    required this.kategoriTakson,
    required this.latitude,
    required this.longitude,
    required this.fotoUrl,
    this.catatanHabitat,
    required this.waktuPengamatan,
    this.statusApproval = 'MENUNGGU_VERIFIKASI',
    this.idKordinator,
    this.catatanRevisi,
    this.waktuVerifikasi,
    required this.createdAt,
    required this.updatedAt,
    this.jumlahIndividu,
    this.aktivitasTermati,
    this.isSynced = false,
  });

  factory Observation.fromSQLite(Map<String, dynamic> map) {
    return Observation(
      id: map['id'] as String,
      idPetugas: map['id_petugas'] as String,
      idKegiatan: map['id_kegiatan'] as int?,
      namaSpesies: map['nama_spesies'] as String,
      namaLokal: map['nama_lokal'] as String?,
      kategoriTakson: map['kategori_takson'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      fotoUrl: map['foto_url'] as String? ?? '',
      catatanHabitat: map['catatan_habitat'] as String?,
      waktuPengamatan: DateTime.parse(map['waktu_pengamatan'] as String),
      statusApproval:
          map['status_approval'] as String? ?? 'MENUNGGU_VERIFIKASI',
      idKordinator: map['id_kordinator'] as String?,
      catatanRevisi: map['catatan_revisi'] as String?,
      waktuVerifikasi: map['waktu_verifikasi'] != null
          ? DateTime.parse(map['waktu_verifikasi'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      jumlahIndividu: map['jumlah_individu'] as int?,
      aktivitasTermati: map['aktivitas_termati'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  factory Observation.fromSupabase(Map<String, dynamic> map) {
    return Observation(
      id: map['id'] as String,
      idPetugas: map['id_petugas'] as String,
      idKegiatan: map['id_kegiatan'] as int?,
      namaSpesies: map['nama_spesies'] as String,
      namaLokal: map['nama_lokal'] as String?,
      kategoriTakson: map['kategori_takson'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      fotoUrl: map['foto_url'] as String? ?? '',
      catatanHabitat: map['catatan_habitat'] as String?,
      waktuPengamatan: DateTime.parse(map['waktu_pengamatan'] as String),
      statusApproval:
          map['status_approval'] as String? ?? 'MENUNGGU_VERIFIKASI',
      idKordinator: map['id_kordinator'] as String?,
      catatanRevisi: map['catatan_revisi'] as String?,
      waktuVerifikasi: map['waktu_verifikasi'] != null
          ? DateTime.parse(map['waktu_verifikasi'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      jumlahIndividu: map['jumlah_individu'] as int?,
      aktivitasTermati: map['aktivitas_termati'] as String?,
      isSynced: true,
    );
  }

  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'id_petugas': idPetugas,
      'id_kegiatan': idKegiatan,
      'nama_spesies': namaSpesies,
      'nama_lokal': namaLokal,
      'kategori_takson': kategoriTakson,
      'latitude': latitude,
      'longitude': longitude,
      'foto_url': fotoUrl,
      'catatan_habitat': catatanHabitat,
      'waktu_pengamatan': waktuPengamatan.toIso8601String(),
      'status_approval': statusApproval,
      'id_kordinator': idKordinator,
      'catatan_revisi': catatanRevisi,
      'waktu_verifikasi': waktuVerifikasi?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'jumlah_individu': jumlahIndividu,
      'aktivitas_termati': aktivitasTermati,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabase() {
    final map = toSQLite();
    map.remove('is_synced');
    map.remove('local_foto_path');
    return map;
  }

  Observation copyWith({
    String? namaLokal,
    String? statusApproval,
    String? idKordinator,
    String? catatanRevisi,
    DateTime? waktuVerifikasi,
    int? jumlahIndividu,
    String? aktivitasTermati,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return Observation(
      id: id,
      idPetugas: idPetugas,
      idKegiatan: idKegiatan,
      namaSpesies: namaSpesies,
      namaLokal: namaLokal ?? this.namaLokal,
      kategoriTakson: kategoriTakson,
      latitude: latitude,
      longitude: longitude,
      fotoUrl: fotoUrl,
      catatanHabitat: catatanHabitat,
      waktuPengamatan: waktuPengamatan,
      statusApproval: statusApproval ?? this.statusApproval,
      idKordinator: idKordinator ?? this.idKordinator,
      catatanRevisi: catatanRevisi ?? this.catatanRevisi,
      waktuVerifikasi: waktuVerifikasi ?? this.waktuVerifikasi,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      jumlahIndividu: jumlahIndividu ?? this.jumlahIndividu,
      aktivitasTermati: aktivitasTermati ?? this.aktivitasTermati,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}