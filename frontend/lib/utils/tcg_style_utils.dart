import 'package:flutter/material.dart';

class TcgStyleUtils {
  /// Warna dominan card (untuk gradient back + glow)
  static List<Color> getGradientFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora')) {
      return [const Color(0xFFD4451A), const Color(0xFF8B2010)];
    }
    if (s.contains('herbivora')) {
      return [const Color(0xFF2E9B5E), const Color(0xFF1A6B3E)];
    }
    if (s.contains('primata')) {
      return [const Color(0xFFA0522D), const Color(0xFF6B3418)];
    }
    if (s.contains('burung')) {
      return [const Color(0xFF2196F3), const Color(0xFF0D47A1)];
    }
    if (s.contains('reptil') || s.contains('amfibi')) {
      return [const Color(0xFF00897B), const Color(0xFF004D40)];
    }
    if (s.contains('insekta')) {
      return [const Color(0xFFFF8F00), const Color(0xFFE65100)];
    }
    if (s.contains('fauna perairan')) {
      return [const Color(0xFF5C6BC0), const Color(0xFF283593)];
    }
    if (s.contains('eksitu') || s.contains('flora')) {
      return [const Color(0xFF7CB342), const Color(0xFF33691E)];
    }
    return [const Color(0xFF609008), const Color(0xFF3D5A05)];
  }

  static String getEmojiFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora')) return '🐅';
    if (s.contains('herbivora')) return '🐘';
    if (s.contains('primata')) return '🐒';
    if (s.contains('burung')) return '🦅';
    if (s.contains('reptil') || s.contains('amfibi')) return '🦎';
    if (s.contains('insekta')) return '🦋';
    if (s.contains('fauna perairan')) return '🐟';
    if (s.contains('eksitu') || s.contains('flora')) return '🌿';
    return '🔍';
  }

  /// Warna ring/bingkai card sesuai material (Emas, Besi, Perunggu, dll)
  static Color getRingColorFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora')) {
      return const Color(0xFF8A9AAB); // Besi / Realistic Steel Metallic
    }
    if (s.contains('herbivora')) {
      return const Color(0xFFCD7F32); // Perunggu / Bronze
    }
    if (s.contains('primata')) {
      return const Color(0xFFC84C09); // Tembaga / Rich Copper
    }
    if (s.contains('burung')) {
      return const Color(0xFFE2E2E2); // Perak / Bright Silver
    }
    if (s.contains('reptil') || s.contains('amfibi')) {
      return const Color(0xFF50C878); // Zamrud / Emerald
    }
    if (s.contains('insekta')) {
      return const Color(0xFFFFBF00); // Batu Ambar / Amber
    }
    if (s.contains('fauna perairan')) {
      return const Color(0xFFE0E5E5); // Mutiara / Pearl White
    }
    if (s.contains('eksitu') || s.contains('flora')) {
      return const Color(0xFFD4AF37); // Emas / Classic Gold
    }
    return const Color(0xFFB5A642); // Kuningan / Brass (Default)
  }
}
