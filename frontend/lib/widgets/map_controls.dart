import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MapControls extends StatelessWidget {
  final ValueNotifier<double> sheetExtent;
  final bool is3DPov;
  final VoidCallback onTogglePov;
  final VoidCallback onRecenter;

  const MapControls({
    super.key,
    required this.sheetExtent,
    required this.is3DPov,
    required this.onTogglePov,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sheetExtent,
      builder: (context, extent, _) {
        final bottomPadding =
            (MediaQuery.of(context).size.height * extent) + 16;

        return Positioned(
          right: 16,
          bottom: bottomPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'pov',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 4,
                onPressed: onTogglePov,
                child: Icon(
                  is3DPov ? Icons.map_outlined : Icons.view_in_ar,
                ),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 4,
                onPressed: onRecenter,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        );
      },
    );
  }
}
