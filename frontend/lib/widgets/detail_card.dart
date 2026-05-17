import 'dart:io';
import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/constants.dart';

class ObservationDetailCard extends StatelessWidget {
  final Observation obs;
  final VoidCallback onClose;

  const ObservationDetailCard({
    super.key,
    required this.obs,
    required this.onClose,
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
        color: color.withValues(alpha:0.12),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);

    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            border: Border.all(color: color.withValues(alpha:0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _buildBackgroundImage(color, emoji),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(obs.namaSpesies, style: AppTextStyles.species),
                    const SizedBox(height: 2),
                    Text(
                      '${obs.kategoriTakson} • ${obs.latitude.toStringAsFixed(4)}, ${obs.longitude.toStringAsFixed(4)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
