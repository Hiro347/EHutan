import 'package:flutter/material.dart';
import '../../../models/observation.dart';
import 'observation_card.dart';

class MapBottomSheet extends StatelessWidget {
  final List<Observation> observations;
  final String? selectedObservationId;
  final ValueNotifier<double> sheetExtent;
  final void Function(Observation) onObservationTap;

  const MapBottomSheet({
    super.key,
    required this.observations,
    required this.selectedObservationId,
    required this.sheetExtent,
    required this.onObservationTap,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        sheetExtent.value = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.15,
        minChildSize: 0.15,
        maxChildSize: 0.40,
        snap: true,
        snapSizes: const [0.15, 0.40],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Di Sekitar',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A2B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dalam radius 100 meter',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3ED),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Color(0xFF2E604A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${observations.length} titik',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E604A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: observations.length,
                      itemBuilder: (_, i) {
                        final obs = observations[i];
                        return ObservationCard(
                          obs: obs,
                          isSelected: selectedObservationId == obs.id,
                          onTap: () => onObservationTap(obs),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
