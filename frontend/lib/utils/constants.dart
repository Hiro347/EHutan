import 'package:flutter/material.dart';

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

  // Takson
  static const List<String> kategoriTakson = [
    'Mamalia',
    'Burung',
    'Reptil',
    'Amfibi',
    'Ikan',
    'Serangga',
    'Flora',
    'Lainnya',
  ];
}

class AppMapbox {
  static const String styleUrl = 
    'mapbox://styles/arya347/cmoq35vej001t01qr8yjgfkx8/draft';

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

// Helper: ambil warna marker berdasarkan kategori takson
// Helper: ambil warna marker berdasarkan kategori takson
Color markerColorForTakson(String takson) {
  switch (takson) {
    case 'DK Karnivora': return const Color(0xFFD84315); // Oranye Buas
    case 'DK Herbivora': return const Color(0xFF7CB342); // Hijau Daun
    case 'DK Primata': return const Color(0xFF8D6E4A);   // Coklat
    case 'DK Burung': return const Color(0xFF039BE5);    // Biru Langit
    case 'DK Reptil Amfibi': return const Color(0xFF2E7D32); // Hijau Gelap
    case 'DK Insekta': return const Color(0xFFF9A825);   // Emas Serangga
    case 'DK Fauna Perairan': return const Color(0xFF1565C0); // Biru Air Laut
    default: return AppColors.markerDefault;
  }
}

// Helper: emoji icon per takson
String markerEmojiForTakson(String takson) {
  switch (takson) {
    case 'DK Karnivora': return '🐯';
    case 'DK Herbivora': return '🦌';
    case 'DK Primata': return '🐒';
    case 'DK Burung': return '🦅';
    case 'DK Reptil Amfibi': return '🦎';
    case 'DK Insekta': return '🦋';
    case 'DK Fauna Perairan': return '🐟';
    default: return '📍';
  }
}
