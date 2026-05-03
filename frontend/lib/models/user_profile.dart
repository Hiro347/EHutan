class UserProfile {
  final String id;
  final String namaLengkap;
  final UserRole role;
  final String? divisiTakson;
  final bool statusAktivitas;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.namaLengkap,
    required this.role,
    this.divisiTakson,
    this.statusAktivitas = true,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      namaLengkap: map['nama_lengkap'] as String,
      role: UserRole.fromString(map['role'] as String),
      divisiTakson: map['divisi_takson'] as String?,
      statusAktivitas: map['status_aktivitas'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_lengkap': namaLengkap,
      'role': role.value,
      'divisi_takson': divisiTakson,
      'status_aktivitas': statusAktivitas,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper untuk cek role
  bool get isPetugasLapangan => role == UserRole.petugasLapangan;
  bool get isKordinator => role == UserRole.kordinatorDivisi;
  bool get isAdmin => role == UserRole.admin;
  bool get canVerify => isKordinator || isAdmin;
}

enum UserRole {
  petugasLapangan('Petugas_Lapangan'),
  kordinatorDivisi('Kordinator_Divisi'),
  admin('Admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.petugasLapangan,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.petugasLapangan:
        return 'Petugas Lapangan';
      case UserRole.kordinatorDivisi:
        return 'Kordinator Divisi';
      case UserRole.admin:
        return 'Admin';
    }
  }
}