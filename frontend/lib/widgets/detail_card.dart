import 'dart:io';
import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/constants.dart';
import '../utils/tcg_style_utils.dart';

class ObservationDetailCard extends StatelessWidget {
  final Observation obs;
  final VoidCallback onClose;

  const ObservationDetailCard({
    super.key,
    required this.obs,
    required this.onClose,
  });

  List<Color> _gradientFor(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('flora') || lower.contains('tumbuhan') || lower.contains('plantae')) {
      return const [Color(0xFF81C784), Color(0xFF388E3C)]; // Hijau muda
    }
    if (lower.contains('herbivora')) return const [Color(0xFF2E7D32), Color(0xFF1B5E20)];
    if (lower.contains('karnivora')) return const [Color(0xFFC62828), Color(0xFF8E0000)];
    if (lower.contains('primata')) return const [Color(0xFF8D6E63), Color(0xFF4E342E)]; // Coklat
    if (lower.contains('aves')) return const [Color(0xFF0277BD), Color(0xFF01579B)];
    if (lower.contains('amfibi')) return const [Color(0xFF00695C), Color(0xFF004D40)];
    if (lower.contains('reptil')) return const [Color(0xFF4E342E), Color(0xFF3E2723)];
    if (lower.contains('serangga') || lower.contains('insekta')) {
      return const [Color(0xFFEF6C00), Color(0xFFE65100)];
    }
    if (lower.contains('pisces') || lower.contains('ikan')) {
      return const [Color(0xFF00838F), Color(0xFF006064)];
    }
    return const [Color(0xFF424242), Color(0xFF212121)]; // Default
  }

  Widget _buildBackgroundImage(Color color, String emoji) {
    if (obs.localFotoPath != null && obs.localFotoPath!.isNotEmpty) {
      final file = File(obs.localFotoPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholder(color, emoji),
        );
      }
    }

    final resolvedUrl = resolveSupabaseFotoUrl(obs.fotoUrl);
    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(color, emoji);
        },
      );
    }

    return _buildPlaceholder(color, emoji);
  }

  Widget _buildPlaceholder(Color color, String emoji) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradientFor(obs.kategoriTakson);
    final fallbackColor = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);
    final int confidence = 85 + (obs.id.hashCode % 14); 

    return Positioned(
      bottom: 110,
      left: 16,
      right: 72, // Diberi jarak agar tidak tertutup FAB
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 120, // Ketinggian kartu TCG Horizontal
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                grad[0].withValues(alpha: 0.9),
                grad[0],
                grad[1],
                grad[0],
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
            // Shadow outer subtle dihapus untuk detail card juga
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  // --- KIRI: Frame Gambar ---
                  AspectRatio(
                    aspectRatio: 1.0, // Tetap persegi
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBDBDBD), width: 2),
                        color: Colors.black,
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: _buildBackgroundImage(fallbackColor, emoji),
                          ),
                          // Glassy AI Confidence Badge
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha:0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white.withValues(alpha:0.2)),
                                ),
                                child: Text(
                                  '$confidence%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // --- KANAN: Informasi ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFFE8E8E8), Color(0xFFBDBDBD)],
                                ),
                                border: Border.all(color: const Color(0xFFAAAAAA)),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                                ],
                              ),
                              child: Text(
                                obs.kategoriTakson.replaceAll('DK ', '').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Nama Spesies
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            obs.namaSpesies,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Koordinat
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 10, color: Colors.white70),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${obs.latitude.toStringAsFixed(5)}, ${obs.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const Spacer(),
                        
                        // Footer Status & Tanggal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(obs.waktuPengamatan),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              obs.statusApproval == 'MENUNGGU_VERIFIKASI' ? 'MENUNGGU' : obs.statusApproval,
                              style: TextStyle(
                                color: _statusColor(obs.statusApproval),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                shadows: const [Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(1, 1))],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Space untuk icon close
                  const SizedBox(width: 16),
                ],
              ),
              
              // Tombol Close (Dipindah ke dalam card)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _statusColor(String status) {
    if (status == 'TERVERIFIKASI') return const Color(0xFF69F0AE); // Hijau terang
    if (status == 'PERLU_DIREVISI') return const Color(0xFFFFAB40); // Orange
    return const Color(0xFF80D8FF); // Biru muda
  }
}