import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../utils/constants.dart';
import '../../models/observation.dart';
import '../../widgets/navbar.dart';
import '../../widgets/map_bottom_sheet.dart';
import '../../widgets/detail_card.dart';
import '../../widgets/top_overlay.dart';
import '../../widgets/map_controls.dart';
import '_marker_click_listener.dart';
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
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
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _heading = 0.0;
  bool _firstLocationFixed = false;
  bool _is3DPov = true;
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.15);

  // ─────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // MAP CREATED
  // ─────────────────────────────────────────────────────────
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

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
    await _setupBeamEffect();      // ← tambahkan ini SEBELUM setupPetugasModel
    await _setupPetugasModel();    // supaya model 3D render di atas beam
    await _setupLocationIndicator();
  }

  // ─────────────────────────────────────────────────────────
  // GLB ASSET HELPER
  // ─────────────────────────────────────────────────────────
  Future<String> _extractGlbToTemp(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/petugas.glb');
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
      final glbPath = await _extractGlbToTemp('lib/assets/petugas.glb');
      await map.style.addStyleModel('petugas-model', 'file://$glbPath');

      await map.style.addSource(
        GeoJsonSource(
          id: 'petugas-location-source',
          data: _buildGeoJsonPoint(
            _userPosition.lng.toDouble(),
            _userPosition.lat.toDouble(),
          ),
        ),
      );

      await map.style.addLayer(
        ModelLayer(
          id: 'petugas-model-layer',
          sourceId: 'petugas-location-source',
        ),
      );

      final props = {
        'model-id': ['literal', 'petugas-model'],
        'model-scale': [8.0, 8.0, 8.0],
        'model-rotation': [0.0, 0.0, -180.0],
        'model-translation': [0.0, 0.0, 5.0],
        'model-type': 'common-3d',
        'model-cast-shadows': true,
        'model-receive-shadows': true,
      };

      for (final entry in props.entries) {
        await map.style.setStyleLayerProperty(
          'petugas-model-layer',
          entry.key,
          entry.value,
        );
      }
    } catch (e) {
      print('Setup petugas model error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // OBSERVATION MARKERS
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
      MarkerClickListener(
        observations: _dummyObservations,
        onTap: (obs) {
          setState(() => _selectedObservation = obs);
          _flyToObservation(obs);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LOCATION INDICATOR
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
  // BEAM EFFECT SETUP
  // ─────────────────────────────────────────────────────────
  Future<void> _setupBeamEffect() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final lng = _userPosition.lng.toDouble();
      final lat = _userPosition.lat.toDouble();

      // ── Layer 1: Outer glow (lebar, sangat transparan) ──
      await map.style.addSource(GeoJsonSource(
        id: 'beam-outer-source',
        data: _buildBeamGeoJson(lng, lat, _heading, 0.0012),
      ));
      await map.style.addLayer(FillLayer(
        id: 'beam-outer-layer',
        sourceId: 'beam-outer-source',
      ));
      await map.style.setStyleLayerProperty('beam-outer-layer', 'fill-color', '#B3E5FC');
      await map.style.setStyleLayerProperty('beam-outer-layer', 'fill-opacity', 0.08);

      // ── Layer 2: Mid beam ──
      await map.style.addSource(GeoJsonSource(
        id: 'beam-mid-source',
        data: _buildBeamGeoJson(lng, lat, _heading, 0.0007),
      ));
      await map.style.addLayer(FillLayer(
        id: 'beam-mid-layer',
        sourceId: 'beam-mid-source',
      ));
      await map.style.setStyleLayerProperty('beam-mid-layer', 'fill-color', '#E1F5FE');
      await map.style.setStyleLayerProperty('beam-mid-layer', 'fill-opacity', 0.14);

      // ── Layer 3: Inner core (sempit, paling terang) ──
      await map.style.addSource(GeoJsonSource(
        id: 'beam-inner-source',
        data: _buildBeamGeoJson(lng, lat, _heading, 0.0004),
      ));
      await map.style.addLayer(FillLayer(
        id: 'beam-inner-layer',
        sourceId: 'beam-inner-source',
      ));
      await map.style.setStyleLayerProperty('beam-inner-layer', 'fill-color', '#FFFFFF');
      await map.style.setStyleLayerProperty('beam-inner-layer', 'fill-opacity', 0.22);

      // ── Line edge: tepi beam ──
      await map.style.addLayer(LineLayer(
        id: 'beam-edge-layer',
        sourceId: 'beam-inner-source',
      ));
      await map.style.setStyleLayerProperty('beam-edge-layer', 'line-color', '#90CAF9');
      await map.style.setStyleLayerProperty('beam-edge-layer', 'line-opacity', 0.35);
      await map.style.setStyleLayerProperty('beam-edge-layer', 'line-width', 1.0);

    } catch (e) {
      print('Beam setup error: $e');
    }
  }

  String _buildBeamGeoJson(double lng, double lat, double headingDeg, double radiusDeg) {
  const int segments = 20;
  const double beamWidth = 45.0; // Total lebar sorotan (derajat)

  // Konversi heading kompas ke standar matematika (0° = Timur)
  // Formula: MathAngle = 90 - CompassHeading
  final double centerRad = (90.0 - headingDeg) * math.pi / 180.0;
  final double halfRad = (beamWidth / 2) * math.pi / 180.0;

  final List<List<double>> ring = [[lng, lat]]; // Titik pusat di posisi user
  
  for (int i = 0; i <= segments; i++) {
    // Kita iterasi dari sisi kiri beam ke sisi kanan
    final double angle = (centerRad + halfRad) - (i * (2 * halfRad) / segments);
    ring.add([
      lng + radiusDeg * math.cos(angle),
      lat + radiusDeg * math.sin(angle),
    ]);
  }
  
  ring.add([lng, lat]); // Tutup kembali ke pusat

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [{
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [ring],
      },
    }],
  });
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
        zoom: _is3DPov ? 18.5 : 16.0,
        pitch: _is3DPov ? 65.0 : 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  void _togglePov() {
    setState(() => _is3DPov = !_is3DPov);
    _mapboxMap?.flyTo(
      CameraOptions(
        zoom: _is3DPov ? 18.5 : 16.0,
        pitch: _is3DPov ? 65.0 : 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _recenterCamera() {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: _userPosition),
        zoom: _is3DPov ? 17.5 : 16.0, 
        pitch: _is3DPov ? 70.0 : 0.0, 
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LOCATION TRACKING
  // ─────────────────────────────────────────────────────────
  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      _startLocationTracking();
    } else {
      print('Izin lokasi ditolak');
    }
  }

  void _startLocationTracking() async {
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    
    try {
      final initialPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      _updateUserPosition(initialPosition.latitude, initialPosition.longitude);
    } catch (e) {
      print('Gagal mendapatkan lokasi awal: $e');
    }

    _locationSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((geo.Position position) {
      _updateUserPosition(position.latitude, position.longitude);
    });

    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final heading = event.heading ?? 0.0;
      _updateHeading(heading);
    });
  }

  Future<void> _updateHeading(double heading) async {
  if (!mounted) return;
  setState(() => _heading = heading);

  final map = _mapboxMap;
  if (map == null) return;

  try {
    // Jika muka karakter masih tidak pas, ubah angka 0.0 di bawah ini (offset).
    // Misal: heading + 180 jika model menghadap ke belakang.
    double modelYaw = heading; 

    await map.style.setStyleLayerProperty(
      'petugas-model-layer',
      'model-rotation',
      [0.0, 0.0, heading - 180.0], 
    );
  } catch (e) {
    print('Update heading model error: $e');
  }

  // Update Beam (posisi tetap di user, arah mengikuti heading)
  final lng = _userPosition.lng.toDouble();
  final lat = _userPosition.lat.toDouble();
  
  final layers = {
    'beam-outer-source': 0.0012,
    'beam-mid-source': 0.0007,
    'beam-inner-source': 0.0004,
  };

  for (var entry in layers.entries) {
    try {
      await map.style.setStyleSourceProperty(
        entry.key, 
        'data',
        _buildBeamGeoJson(lng, lat, heading, entry.value),
      );
    } catch (_) {}
  }
}

  Future<void> _updateUserPosition(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _userPosition = Position(lng, lat));

    final map = _mapboxMap;
    if (map == null) return;

    if (!_firstLocationFixed) {
      _firstLocationFixed = true;
      map.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: _is3DPov ? 18.5 : 16.0,
        pitch: _is3DPov ? 65.0 : 0.0,
        bearing: _is3DPov ? _heading : 0.0,
      ));
    }

    try {
      await map.style.setStyleSourceProperty(
        'petugas-location-source',
        'data',
        _buildGeoJsonPoint(lng, lat),
      );
    } catch (e) {
      print('Update source error: $e');
    }

    // Update beam position ketika GPS bergerak
    try {
      final beamLng = _userPosition.lng.toDouble();
      final beamLat = _userPosition.lat.toDouble();
      await map.style.setStyleSourceProperty(
        'beam-outer-source', 'data',
        _buildBeamGeoJson(beamLng, beamLat, _heading, 0.0012),
      );
      await map.style.setStyleSourceProperty(
        'beam-mid-source', 'data',
        _buildBeamGeoJson(beamLng, beamLat, _heading, 0.0007),
      );
      await map.style.setStyleSourceProperty(
        'beam-inner-source', 'data',
        _buildBeamGeoJson(beamLng, beamLat, _heading, 0.0004),
      );
    } catch (e) {
      print('Update beam position error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────
  String _buildGeoJsonPoint(double lng, double lat) {
    return jsonEncode({
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
    });
  }

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
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unsyncedCount = _dummyObservations.where((o) => !o.isSynced).length;

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: AppMapbox.styleUrl,
            cameraOptions: CameraOptions(
              center: Point(coordinates: _userPosition),
              zoom: _is3DPov ? 18.5 : 16.0,
              pitch: _is3DPov ? 65.0 : 0.0,
              bearing: 0.0,
            ),
          ),
          MapBottomSheet(
            observations: _dummyObservations,
            selectedObservationId: _selectedObservation?.id,
            sheetExtent: _sheetExtent,
            onObservationTap: (obs) {
              setState(() => _selectedObservation = obs);
              _flyToObservation(obs);
            },
          ),
          MapTopOverlay(unsyncedCount: unsyncedCount),
          if (_selectedObservation != null)
            ObservationDetailCard(
              obs: _selectedObservation!,
              onClose: () => setState(() => _selectedObservation = null),
            ),
          MapControls(
            sheetExtent: _sheetExtent,
            is3DPov: _is3DPov,
            onTogglePov: _togglePov,
            onRecenter: _recenterCamera,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Navbar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              onAddTap: () => print('Tombol Add ditekan dari Map Screen!'),
            ),
          ),
        ],
      ),
    );
  }
}