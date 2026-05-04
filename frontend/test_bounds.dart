import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
void main() {
  MapboxMap? m;
  m?.setBounds(CameraBoundsOptions(
    bounds: CoordinateBounds(
      southwest: Point(coordinates: Position(0, 0)),
      northeast: Point(coordinates: Position(0, 0)),
      infiniteBounds: false,
    ),
    minZoom: 11.0,
    maxZoom: 20.0,
  ));
}