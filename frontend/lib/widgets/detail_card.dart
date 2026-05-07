import 'package:flutter/material.dart';
import '../../../models/observation.dart';
import '../../../utils/constants.dart';

class ObservationDetailCard extends StatelessWidget {
  final Observation obs;
  final VoidCallback onClose;

  const ObservationDetailCard({
    super.key,
    required this.obs,
    required this.onClose,
  });

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
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
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
