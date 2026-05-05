import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../models/observation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/observation_provider.dart';
import 'koleksi_screen.dart';
import 'form_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Observation> _dummyObservations = [
    Observation(
      id: '1',
      idPetugas: 'user-1',
      namaSpesies: 'Panthera tigris sumatrae',
      kategoriTakson: 'Mamalia',
      latitude: -6.5744,
      longitude: 106.7892,
      fotoUrl: '',
      waktuPengamatan: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Observation(
      id: '2',
      idPetugas: 'user-1',
      namaSpesies: 'Rafflesia arnoldii',
      kategoriTakson: 'Flora',
      latitude: -6.5710,
      longitude: 106.7940,
      fotoUrl: '',
      waktuPengamatan: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Observation(
      id: '3',
      idPetugas: 'user-2',
      namaSpesies: 'Buceros rhinoceros',
      kategoriTakson: 'Burung',
      latitude: -6.5780,
      longitude: 106.7850,
      fotoUrl: '',
      waktuPengamatan: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Position _userPosition = Position(106.7892, -6.5744);
  Observation? _selectedObservation;
  StreamSubscription<geo.Position>? _locationSubscription;
  bool _firstLocationFixed = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // MAP CREATED
  // ─────────────────────────────────────────────────────────
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Batasi area peta hanya ke daerah Bogor untuk optimasi performa
    try {
      await _mapboxMap?.setBounds(CameraBoundsOptions(
        bounds: CoordinateBounds(
          southwest: Point(coordinates: Position(106.65, -6.75)),
          northeast: Point(coordinates: Position(107.05, -6.45)),
          infiniteBounds: false,
        ),
        minZoom: 10.0,
      ));
    } catch (e) {
      print('Set bounds error: $e');
    }

    try {
      await _mapboxMap?.style.setStyleImportConfigProperty(
        'basemap',
        'lightPreset',
        'day',
      );
    } catch (e) {
      print('Skip lightPreset: $e');
    }

    await _addObservationMarkers();
    await _setupPetugasModel();
    await _setupLocationIndicator();
  }

  // ─────────────────────────────────────────────────────────
  // EXTRACT GLB → TEMP FILE (selalu overwrite agar tidak stale)
  // ─────────────────────────────────────────────────────────
  Future<String> _extractGlbToTemp(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/petugas.glb');

    // Selalu overwrite agar file tidak stale saat GLB diganti
    await file.writeAsBytes(byteData.buffer.asUint8List());

    return file.path;
  }

  // ─────────────────────────────────────────────────────────
  // SETUP 3D MODEL PETUGAS
  // ─────────────────────────────────────────────────────────
  Future<void> _setupPetugasModel() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      // 1. Extract GLB ke temp, pakai file:// agar native bisa baca
      final glbPath = await _extractGlbToTemp('lib/assets/petugas.glb');
      final glbUri = 'file://$glbPath';

      // 2. Daftarkan model ke style
      await map.style.addStyleModel('petugas-model', glbUri);

      // 3. GeoJSON source — posisi karakter
      await map.style.addSource(
        GeoJsonSource(
          id: 'petugas-location-source',
          data: jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [_userPosition.lng, _userPosition.lat],
                },
              },
            ],
          }),
        ),
      );

      // 4. Tambahkan ModelLayer dulu (tanpa properties)
      await map.style.addLayer(
        ModelLayer(
          id: 'petugas-model-layer',
          sourceId: 'petugas-location-source',
        ),
      );

      // 5. Set properties via expression (required di v2.x)
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-id',
        ['literal', 'petugas-model'],
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-scale',
        [4.0, 4.0, 4.0], // sesuaikan skala model kamu
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-rotation',
        [0.0, 0.0, 90.0], // pitch, roll, bearing
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-translation',
        [0.0, 0.0, 3.6],
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-type',
        'common-3d',
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-cast-shadows',
        true,
      );
      await map.style.setStyleLayerProperty(
        'petugas-model-layer',
        'model-receive-shadows',
        true,
      );
    } catch (e) {
      print('Setup petugas model error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // OBSERVATION MARKERS (emoji pinpoint)
  // ─────────────────────────────────────────────────────────
  Future<void> _addObservationMarkers() async {
    _annotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();

    for (final obs in _dummyObservations) {
      final imageBytes = await _emojiToImageBytes(
        markerEmojiForTakson(obs.kategoriTakson),
        markerColorForTakson(obs.kategoriTakson),
      );
      await _annotationManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(obs.longitude, obs.latitude)),
          image: imageBytes,
          iconSize: 1.2,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    _annotationManager?.addOnPointAnnotationClickListener(
      _MarkerClickListener(
        observations: _dummyObservations,
        onTap: (obs) {
          setState(() => _selectedObservation = obs);
          _flyToObservation(obs);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LOCATION INDICATOR (pulsing dot)
  // ─────────────────────────────────────────────────────────
  Future<void> _setupLocationIndicator() async {
    try {
      await _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: AppColors.locationDot.value,
          pulsingMaxRadius: 50.0,
          showAccuracyRing: true,
          accuracyRingColor: AppColors.locationAccuracy.value,
        ),
      );
    } catch (e) {
      print('Location indicator error (non-fatal): $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────
  Future<void> _flyToObservation(Observation obs) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(obs.longitude, obs.latitude - 0.002),
        ),
        zoom: 17.0,
        pitch: 55.0,
        bearing: 15.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Location
  // ─────────────────────────────────────────────────────────
  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      _startLocationTracking();
    } else {
      print('Izin lokasi ditolak');
    }
  }

  void _startLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 2, // update setiap 2 meter
      ),
    ).listen((geo.Position position) {
      _updateUserPosition(position.latitude, position.longitude);
    });
  }

  Future<void> _updateUserPosition(double lat, double lng) async {
    if (!mounted) return;

    setState(() {
      _userPosition = Position(lng, lat);
    });

    final map = _mapboxMap;
    if (map == null) return;

    // Pindahkan kamera ke lokasi user saat pertama kali didapat
    if (!_firstLocationFixed) {
      _firstLocationFixed = true;
      map.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
      ));
    }

    // Update GeoJSON source untuk model 3D petugas
    try {
      await map.style.setStyleSourceProperty(
        'petugas-location-source',
        'data',
        jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [lng, lat],
              },
            },
          ],
        }),
      );
    } catch (e) {
      print('Update source error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // EMOJI → IMAGE BYTES (untuk marker)
  // ─────────────────────────────────────────────────────────
  Future<Uint8List> _emojiToImageBytes(String emoji, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 80.0;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = color.withOpacity(0.2),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final tp = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 36)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: AppMapbox.styleUrl,
            cameraOptions: CameraOptions(
              center: Point(coordinates: _userPosition),
              zoom: 16.0,
              pitch: 50.0,
              bearing: 0.0,
            ),
          ),
          _buildBottomSheet(),
          _buildTopOverlay(),
          if (_selectedObservation != null)
            _buildDetailCard(_selectedObservation!),
          _buildRecenterButton(),

          // --- 1. TOMBOL KOLEKSI (KIRI BAWAH) ---
          Positioned(
            left: 16,
            bottom: 32,
            child: FloatingActionButton.extended(
              heroTag: 'btn_koleksi',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              icon: const Icon(Icons.collections_bookmark_rounded),
              label: const Text('Koleksi', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const KoleksiScreen()));
              },
            ),
          ),

// --- 2. TOMBOL PROTOTYPE SUBMIT (KANAN BAWAH) ---
          Positioned(
            right: 16,
            bottom: 32,
            child: FloatingActionButton.extended(
              heroTag: 'btn_lapor',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Lapor!', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                // BUKA LAYAR FORM YANG BARU DIBUAT
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormScreen(
                      lat: _userPosition.lat.toDouble(),
                      lng: _userPosition.lng.toDouble(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BOTTOM SHEET
  // ─────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.13,
      minChildSize: 0.08,
      maxChildSize: 0.50,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text('Di Sekitar', style: AppTextStyles.heading2),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_dummyObservations.length} observasi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _dummyObservations.length,
                  itemBuilder: (_, i) =>
                      _buildObservationCard(_dummyObservations[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // OBSERVATION CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildObservationCard(Observation obs) {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);
    final isSelected = _selectedObservation?.id == obs.id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedObservation = obs);
        _flyToObservation(obs);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(obs.namaSpesies, style: AppTextStyles.species),
                  const SizedBox(height: 2),
                  Text(obs.kategoriTakson, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (!obs.isSynced)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusMenunggu.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Draft',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.statusMenunggu,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // DETAIL CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildDetailCard(Observation obs) {
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
                onPressed: () => setState(() => _selectedObservation = null),
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

  // ─────────────────────────────────────────────────────────
  // TOP OVERLAY
  // ─────────────────────────────────────────────────────────
  Widget _buildTopOverlay() {
    final unsyncedCount = _dummyObservations.where((o) => !o.isSynced).length;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
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
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  // ─────────────────────────────────────────────────────────
  // RECENTER BUTTON
  // ─────────────────────────────────────────────────────────
  Widget _buildRecenterButton() {
    return Positioned(
      right: 16,
      bottom: 160, // Angkat sedikit karena ada tombol lapor di bawah
      child: FloatingActionButton.small(
        heroTag: 'recenter',
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: _userPosition),
            zoom: 19.5,
            pitch: 80.0,
            bearing: 0.0,
          ),
          MapAnimationOptions(duration: 800),
        ),
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MARKER CLICK LISTENER
// ─────────────────────────────────────────────────────────
class _MarkerClickListener extends OnPointAnnotationClickListener {
  final List<Observation> observations;
  final void Function(Observation) onTap;

  _MarkerClickListener({required this.observations, required this.onTap});

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