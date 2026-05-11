import 'dart:io'; // <-- Tambahan untuk membaca file lokal
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Tambahan untuk Supabase Storage
import '../../../models/observation.dart';
import '../../../utils/constants.dart';

class ObservationCard extends StatelessWidget {
  final Observation obs;
  final bool isSelected;
  final VoidCallback onTap;

  const ObservationCard({
    super.key,
    required this.obs,
    required this.isSelected,
    required this.onTap,
  });

  // Fungsi khusus untuk menangani logika gambar (Lokal vs Supabase)
  Widget _buildBackgroundImage(Color color, String emoji) {
    // 1. Cek apakah ada foto offline di memori lokal HP (belum di-sync)
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

    // 2. Jika tersinkron dan memiliki path Supabase
    if (obs.fotoUrl.isNotEmpty) {
      // Generate Public URL dari path storage Supabase
      String imageUrl = obs.fotoUrl.trim(); // Hapus spasi jika ada
      if (!imageUrl.startsWith('http')) {
        imageUrl = Supabase.instance.client.storage
            .from('Foto_Observasi') // Sesuai nama bucket Supabase Anda
            .getPublicUrl(imageUrl);
      }
      
      // Bypass cache Flutter dengan menambahkan random query parameter
      final bypassCacheUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      return Image.network(
        bypassCacheUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ ERROR LOAD GAMBAR [${obs.namaSpesies}]: $error');
          print('🔗 URL YANG DICOBA: $bypassCacheUrl');
          return _buildPlaceholder(color, emoji);
        },
      );
    }

    // 3. Fallback jika tidak ada foto sama sekali
    return _buildPlaceholder(color, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);

    // Simulate distance
    final int distance = (10 + (obs.id.hashCode % 90));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildBackgroundImage(color, emoji),
              ),

              // Gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            obs.kategoriTakson.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (!obs.isSynced)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      obs.namaSpesies,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$distance m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color, String emoji) {
    return Container(
      color: color.withOpacity(0.2),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 40)),
      ),
    );
  }
}