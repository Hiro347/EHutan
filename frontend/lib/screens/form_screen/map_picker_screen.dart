import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../utils/constants.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  double _selectedLat = 0.0;
  double _selectedLng = 0.0;

  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateMarker(double lng, double lat) async {
    if (_annotationManager == null) return;
    await _annotationManager!.deleteAll();
    final pinBytes = await _createPinImage();
    await _annotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: pinBytes,
      iconAnchor: IconAnchor.CENTER,
    ));
  }

  Future<Uint8List> _createPinImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(25, 25), 14, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(25, 25), 14, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(50, 50);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    final client = HttpClient();
    client.userAgent = 'EHutanApp/1.0 (contact: support@ehutan.org)';
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=5'
        '&countrycodes=id',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(responseBody) as List;
        if (mounted) {
          setState(() {
            _searchResults = decoded.map((e) {
              return {
                'display_name': e['display_name'] as String,
                'lat': double.tryParse(e['lat'] as String) ?? 0.0,
                'lng': double.tryParse(e['lon'] as String) ?? 0.0,
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _zoomIn() async {
    final state = await _mapboxMap?.getCameraState();
    if (state != null) {
      _mapboxMap?.flyTo(
        CameraOptions(zoom: state.zoom + 1.0),
        MapAnimationOptions(duration: 300),
      );
    }
  }

  void _zoomOut() async {
    final state = await _mapboxMap?.getCameraState();
    if (state != null) {
      _mapboxMap?.flyTo(
        CameraOptions(zoom: state.zoom - 1.0),
        MapAnimationOptions(duration: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Peta Fullscreen Flat 2D (pitch & bearing di-lock ke 0.0)
          MapWidget(
            styleUri: AppMapbox.styleUrl,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            onMapCreated: (mapboxMap) async {
              _mapboxMap = mapboxMap;
              _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();

              await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
              await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
              await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
              await mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false));

              mapboxMap.setCamera(CameraOptions(
                center: Point(coordinates: Position(_selectedLng, _selectedLat)),
                zoom: 15.0,
                pitch: 0.0,
                bearing: 0.0,
              ));
              _updateMarker(_selectedLng, _selectedLat);
            },
            onTapListener: (context) {
              final pos = context.point.coordinates;
              setState(() {
                _selectedLat = pos.lat.toDouble();
                _selectedLng = pos.lng.toDouble();
              });
              _updateMarker(_selectedLng, _selectedLat);
            },
          ),

          // Search Bar Overlay di atas
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _performSearch(),
                          decoration: const InputDecoration(
                            hintText: 'Cari lokasi / alamat...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      _isSearching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: AppColors.primary),
                              onPressed: _performSearch,
                            ),
                    ],
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final res = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            res['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final lat = res['lat'] as double;
                            final lng = res['lng'] as double;
                            setState(() {
                              _selectedLat = lat;
                              _selectedLng = lng;
                              _searchResults.clear();
                              _searchController.clear();
                            });
                            _mapboxMap?.setCamera(CameraOptions(
                              center: Point(coordinates: Position(lng, lat)),
                              zoom: 16.0,
                              pitch: 0.0,
                              bearing: 0.0,
                            ));
                            _updateMarker(lng, lat);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tombol Zoom +/- di samping kanan
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'picker_zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'picker_zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Tombol Konfirmasi di bagian bawah
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'lat': _selectedLat,
                  'lng': _selectedLng,
                });
              },
              child: const Text(
                'PILIH LOKASI INI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
