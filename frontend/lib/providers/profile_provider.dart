// lib/providers/profile_provider.dart
//
// Riverpod provider untuk membaca & mengupdate profil user (nama_lengkap & avatar_url)
// dari/ke tabel `profiles` di Supabase dan bucket `avatars` di Supabase Storage.

import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model ringkas – hanya berisi data yang bisa diedit dari layar profil.
// Model lengkap UserProfile (dengan role, divisi, dll) tetap di user_profile.dart.
// ─────────────────────────────────────────────────────────────────────────────
class EditableProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? role;

  const EditableProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.role,
  });

  factory EditableProfile.fromJson(Map<String, dynamic> json, {String? email}) {
    return EditableProfile(
      id: json['id'] as String,
      email: email ?? '',
      fullName: json['nama_lengkap'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
    );
  }

  EditableProfile copyWith({String? fullName, String? avatarUrl}) {
    return EditableProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────
class ProfileNotifier extends AsyncNotifier<EditableProfile> {
  final _supabase = Supabase.instance.client;

  @override
  Future<EditableProfile> build() => _fetch();

  Future<EditableProfile> _fetch() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User belum login');

    // Coba ambil dari tabel `profiles`
    final data = await _supabase
        .from('profiles')
        .select('id, nama_lengkap, avatar_url, role')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      // Baris belum ada, kembalikan profil kosong dari data auth saja
      return EditableProfile(
        id: user.id,
        email: user.email ?? '',
      );
    }

    return EditableProfile.fromJson(data, email: user.email ?? '');
  }

  // ── Update nama lengkap ──────────────────────────────────────────────────
  Future<void> updateFullName(String newName) async {
    final current = state.requireValue;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supabase
          .from('profiles')
          .update({'nama_lengkap': newName.trim()})
          .eq('id', current.id);
      return current.copyWith(fullName: newName.trim());
    });
  }

  // ── Pick & crop foto, lalu upload ke Supabase Storage ─────────────────────
  Future<void> updateAvatar({bool fromCamera = false}) async {
    final current = state.requireValue;

    // 1. Ambil gambar dari kamera atau galeri
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    // 2. Crop ke rasio 1:1 (persegi)
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Potong Foto Profil',
          toolbarColor: const Color(0xFF2E604A),
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Potong Foto Profil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final file = File(cropped.path);
      final ext = cropped.path.split('.').last.toLowerCase();
      // Path dalam bucket: public/<userId>.<ext>
      final storagePath = 'public/${current.id}.$ext';

      // 3. Upload ke bucket `avatars` (upsert = overwrite jika sudah ada)
      await _supabase.storage.from('avatars').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // 4. Dapatkan public URL
      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(storagePath);

      // 5. Update kolom avatar_url di tabel `profiles`
      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', current.id);

      return current.copyWith(avatarUrl: publicUrl);
    });
  }

  /// Muat ulang data profil dari server
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, EditableProfile>(() {
  return ProfileNotifier();
});
