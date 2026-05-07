import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../models/observation.dart';

class MarkerClickListener extends OnPointAnnotationClickListener {
  final List<Observation> observations;
  final void Function(Observation) onTap;

  MarkerClickListener({required this.observations, required this.onTap});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    final lon = annotation.geometry.coordinates.lng;
    final lat = annotation.geometry.coordinates.lat;
    final matched = observations.firstWhere(
      (o) =>
          (o.longitude - lon).abs() < 0.0001 &&
          (o.latitude - lat).abs() < 0.0001,
      orElse: () => observations.first,
    );
    onTap(matched);
  }
}
