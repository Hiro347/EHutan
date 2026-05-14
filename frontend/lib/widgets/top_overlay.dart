import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MapTopOverlay extends StatelessWidget {
  final int unsyncedCount;

  const MapTopOverlay({super.key, required this.unsyncedCount});

  @override
  Widget build(BuildContext context) {
    // Positioned must be a descendant of a Stack widget
    return Positioned(
      top: MediaQuery.of(context).padding.top + 24,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _glassChip(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forest, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  'E-Hutan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (unsyncedCount > 0)
            _glassChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: AppColors.statusMenunggu,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$unsyncedCount belum sync',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusMenunggu,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.92),
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}