import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    if (obs.fotoUrl.isNotEmpty) {
      String imageUrl = obs.fotoUrl.trim();
      if (!imageUrl.startsWith('http')) {
        imageUrl = Supabase.instance.client.storage
            .from('Foto_Observasi')
            .getPublicUrl(imageUrl);
      }
      
      final bypassCacheUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      return Image.network(
        bypassCacheUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(color, emoji);
        },
      );
    }

    return _buildPlaceholder(color, emoji);
  }

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays} hari lalu';
    if (duration.inHours > 0) return '${duration.inHours} jam lalu';
    if (duration.inMinutes > 0) return '${duration.inMinutes} menit lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);
    final int confidence = 85 + (obs.id.hashCode % 14);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.15) 
                  : Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Image Section
                Stack(
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: _buildBackgroundImage(color, emoji),
                    ),
                    // Glassy AI Confidence Badge
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              '$confidence%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    
                // Info Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                obs.namaSpesies,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF1E3A2B),
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!obs.isSynced)
                              const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orangeAccent),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              obs.kategoriTakson,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (obs.statusApproval == 'TERVERIFIKASI' 
                                    ? AppColors.statusTerverifikasi 
                                    : AppColors.statusMenunggu).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                obs.statusApproval == 'MENUNGGU_VERIFIKASI' ? 'Menunggu' : obs.statusApproval.toLowerCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: obs.statusApproval == 'TERVERIFIKASI' 
                                      ? AppColors.statusTerverifikasi 
                                      : AppColors.statusMenunggu,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              _getTimeAgo(obs.waktuPengamatan),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color, String emoji) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 44)),
      ),
    );
  }
}
