import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/constants.dart';
import 'observation_card.dart';

class MapBottomSheet extends StatefulWidget {
  final List<Observation> observations;
  final String? selectedObservationId;
  final ValueNotifier<double> sheetExtent;
  final void Function(Observation) onObservationTap;
  final DraggableScrollableController? controller;

  const MapBottomSheet({
    super.key,
    required this.observations,
    required this.selectedObservationId,
    required this.sheetExtent,
    required this.onObservationTap,
    this.controller,
  });

  @override
  State<MapBottomSheet> createState() => _MapBottomSheetState();
}

class _MapBottomSheetState extends State<MapBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredObservations = widget.observations.where((obs) {
      return obs.namaSpesies.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          obs.kategoriTakson.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        widget.sheetExtent.value = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: widget.controller,
        initialChildSize: AppLayout.sheetInitialSize,
        minChildSize: AppLayout.sheetMinSize,
        maxChildSize: AppLayout.sheetMaxSize,
        snap: true,
        snapSizes: const [AppLayout.sheetMinSize, 0.45, AppLayout.sheetMaxSize],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: filteredObservations.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        // Handle Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Container(
                            width: 50,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Title Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'E-Hutan Explore',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF062A0E),
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  Text(
                                    'Temukan keanekaragaman hayati',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.observations.length}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  if (index == 1) {
                    // Search Bar
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Cari spesies atau takson...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Observation Cards
                  final obs = filteredObservations[index - 2];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: ObservationCard(
                      obs: obs,
                      isSelected: widget.selectedObservationId == obs.id,
                      onTap: () => widget.onObservationTap(obs),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
