import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/constants.dart';
import 'species_card.dart';

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
  DraggableScrollableController? _fallbackController;

  DraggableScrollableController get _effectiveController =>
      widget.controller ?? (_fallbackController ??= DraggableScrollableController());

  @override
  void dispose() {
    _searchController.dispose();
    _fallbackController?.dispose();
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
        controller: _effectiveController,
        initialChildSize: AppLayout.sheetInitialSize,
        minChildSize: 0.25,
        maxChildSize: AppLayout.sheetMaxSize,
        snap: true,
        snapSizes: const [0.25, 0.45, AppLayout.sheetMaxSize],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6EE),
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
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      final parentHeight = MediaQuery.of(context).size.height;
                      final delta = details.primaryDelta! / parentHeight;
                      final newSize = (_effectiveController.size - delta)
                          .clamp(0.25, AppLayout.sheetMaxSize);
                      _effectiveController.jumpTo(newSize);
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0.0;
                      final currentSize = _effectiveController.size;
                      const sizes = [0.25, 0.45, AppLayout.sheetMaxSize];

                      double targetSize = currentSize;
                      if (velocity < -500) {
                        targetSize = sizes.firstWhere((s) => s > currentSize,
                            orElse: () => AppLayout.sheetMaxSize);
                      } else if (velocity > 500) {
                        targetSize = sizes.lastWhere((s) => s < currentSize,
                            orElse: () => 0.25);
                      } else {
                        targetSize = sizes.reduce((a, b) =>
                            (a - currentSize).abs() < (b - currentSize).abs()
                                ? a
                                : b);
                      }

                      _effectiveController.animateTo(
                        targetSize,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                      // Search Bar
                      Padding(
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
                            onTap: () {
                              if (_effectiveController.isAttached) {
                                _effectiveController.animateTo(
                                  AppLayout.sheetMaxSize,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                );
                              }
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
                      ),
                    ],
                  ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          sliver: _buildGroupedList(filteredObservations),
                        ),
                      ],
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

  Widget _buildGroupedList(List<Observation> obsList) {
    if (obsList.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Tidak ada data ditemukan',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      );
    }

    final Map<String, List<Observation>> grouped = {};
    for (var o in obsList) {
      grouped.putIfAbsent(o.kategoriTakson, () => []).add(o);
    }

    final categories = grouped.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = categories[index];
          final items = grouped[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.replaceAll('DK ', '').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062A0E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (items.length > 1)
                      Row(
                        children: [
                          Text(
                            'Geser',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 250, // Reduced Height for SpeciesCard
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final obs = items[i];
                    return Container(
                      width: 175, // Reduced Width for SpeciesCard
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: SpeciesCard(
                        observation: obs,
                        disableFlip: true,
                        onTap: () => widget.onObservationTap(obs),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
        childCount: categories.length,
      ),
    );
  }
}
