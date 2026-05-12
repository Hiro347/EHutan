import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppColors {
  // Warna utama kehutanan
  static const Color primary = Color(0xFF609008);
  static const Color primaryDark = Color(0xFF3D5A05);
  static const Color primaryLight = Color(0xFF8BBF2A);

  // Warna background
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  // Warna status observasi
  static const Color statusMenunggu = Color(0xFFF59E0B);
  static const Color statusTerverifikasi = Color(0xFF10B981);
  static const Color statusRevisi = Color(0xFFEF4444);

  // Warna marker takson
  static const Color markerMamalia = Color(0xFF8B5CF6);
  static const Color markerFauna = Color(0xFFEC4899);
  static const Color markerFlora = Color(0xFF10B981);
  static const Color markerBurung = Color(0xFF3B82F6);
  static const Color markerReptil = Color(0xFFF97316);
  static const Color markerDefault = Color(0xFF6B7280);

  // Warna location marker (Pokémon GO style)
  static const Color locationDot = Color(0xFF3B82F6);
  static const Color locationPulse = Color(0x663B82F6);
  static const Color locationAccuracy = Color(0x223B82F6);
}

class AppStrings {
  static const String appName = 'E-Hutan';
  static const String taglinePeta = 'Peta Observasi';
  static const String taglineForm = 'Tambah Observasi';
  static const String taglineList = 'Daftar Verifikasi';

  // Status
  static const String menungguVerifikasi = 'Menunggu Verifikasi';
  static const String terverifikasi = 'Terverifikasi';
  static const String perluDirevisi = 'Perlu Direvisi';

  // Takson - Disesuaikan dengan Enum tipe_divisi di Supabase
  static const List<String> kategoriTakson = [
    'DK Karnivora',
    'DK Herbivora',
    'DK Primata',
    'DK Burung',
    'DK Reptil Amfibi',
    'DK Insekta',
    'DK Fauna Perairan',
    'DK Eksitu',
  ];
}

class AppMapbox {
  static const String styleUrl = 
    'mapbox://styles/arya347/cmor4slcc000c01s09xgmfbby';

  // Bounding box wilayah Bogor
  static const double boundsMinLat = -6.75;
  static const double boundsMaxLat = -6.45;
  static const double boundsMinLng = 106.65;
  static const double boundsMaxLng = 106.95;

  static const double minZoom = 11.0;
  static const double maxZoom = 20.0;
}

class AppSizes {
  static const double radiusCard = 16.0;
  static const double radiusButton = 12.0;
  static const double paddingPage = 16.0;
  static const double markerSize = 36.0;
  static const double locationDotSize = 18.0;
  static const double fabSize = 64.0;
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1F2937),
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1F2937),
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: Color(0xFF4B5563),
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Color(0xFF9CA3AF),
  );

  static const TextStyle species = TextStyle(
    fontSize: 14,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1F2937),
  );
}

/// Resolve foto_url ke URL lengkap Supabase Storage jika perlu.
/// Jika sudah http → return apa adanya.
/// Jika storage path (misal "observasi/uid/abc.jpg") → resolve ke public URL.
/// Jika kosong → return null.
String? resolveSupabaseFotoUrl(String? fotoUrl) {
  if (fotoUrl == null || fotoUrl.trim().isEmpty) return null;
  final url = fotoUrl.trim();
  if (url.startsWith('http')) return url;
  return Supabase.instance.client.storage
      .from('Foto_Observasi')
      .getPublicUrl(url);
}

// Helper: ambil warna marker berdasarkan kategori takson (Divisi)
Color markerColorForTakson(String takson) {
  final t = takson.toLowerCase();
  if (t.contains('burung')) return AppColors.markerBurung;
  if (t.contains('eksitu')) return AppColors.markerFlora;
  if (t.contains('reptil') || t.contains('amfibi')) return AppColors.markerReptil;
  if (t.contains('karnivora') || t.contains('herbivora') || t.contains('primata')) {
    return AppColors.markerMamalia;
  }
  if (t.contains('insekta') || t.contains('fauna perairan')) {
    return AppColors.markerFauna;
  }
  return AppColors.markerDefault;
}

// Helper: emoji icon per takson
String markerEmojiForTakson(String takson) {
  final t = takson.toLowerCase();
  if (t.contains('karnivora')) return '🐅';
  if (t.contains('herbivora')) return '🐘';
  if (t.contains('primata')) return '🐒';
  if (t.contains('burung')) return '🦅';
  if (t.contains('reptil') || t.contains('amfibi')) return '🦎';
  if (t.contains('fauna perairan')) return '🐟';
  if (t.contains('insekta')) return '🦋';
  if (t.contains('eksitu')) return '🌿';
  return '📍';
}
