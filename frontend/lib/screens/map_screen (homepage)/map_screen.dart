import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

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

class _MapScreenState extends State<MapScreen> {
  int _currentIndex = 0;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  List<Observation> _observations = [];
  bool _isLoadingData = true;

  Position? _userPosition;
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
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // FETCH DATA DARI SUPABASE
  // ─────────────────────────────────────────────────────────
  Future<void> _fetchObservations() async {
    try {
      // Melakukan SELECT ALL dari tabel data_observasi
      final response = await Supabase.instance.client
          .from('data_observasi')
          .select();

      // Mapping data JSON ke model Observation
      final List<Observation> fetchedData = response
          .map((data) => Observation.fromSupabase(data))
          .toList();

      setState(() {
        _observations = fetchedData;
        _isLoadingData = false;
      });

      // Setelah data didapat, tambahkan marker ke peta
      if (_mapboxMap != null) {
        await _addObservationMarkers();
      }
    } catch (e) {
      print('Gagal mengambil data dari Supabase: $e');
      setState(() => _isLoadingData = false);
    }
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

    await _fetchObservations();
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
            _userPosition!.lng.toDouble(),
            _userPosition!.lat.toDouble(),
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
  // Hapus marker lama jika ada (mencegah duplikat kalau fetch diulang)
    if (_annotationManager != null) {
      await _annotationManager?.deleteAll();
    } else {
      _annotationManager = await _mapboxMap?.annotations.createPointAnnotationManager();
    }

    for (final obs in _observations) {
      final imageBytes = await _createCustomMarkerImage(obs);
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
        observations: _observations,
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
      final lng = _userPosition!.lng.toDouble();
      final lat = _userPosition!.lat.toDouble();

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
        bearing: _is3DPov ? _heading : 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _recenterCamera() {
    if (_userPosition == null) return;
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: _userPosition!),
        zoom: _is3DPov ? 17.5 : 16.0, 
        pitch: _is3DPov ? 70.0 : 0.0, 
        bearing: _is3DPov ? _heading : 0.0,
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
  
  // Optimisasi: Batasi pembaruan visual agar tidak dipanggil terlalu sering (misal 60fps)
  double diff = (_heading - heading).abs();
  if (diff > 180) diff = 360 - diff;
  if (diff < 2.0) return; // Hanya update jika perubahan > 2 derajat

  _heading = heading; // Tanpa setState untuk mencegah rebuild UI berulang kali

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
  if (_userPosition == null) return;
  final lng = _userPosition!.lng.toDouble();
  final lat = _userPosition!.lat.toDouble();
  
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

    if (_userPosition == null) {
      setState(() {
        _userPosition = Position(lng, lat);
      });
      // Skip the rest for the first fix because MapWidget is just about to be created
      // and _onMapCreated will initialize everything at this _userPosition.
      return;
    }
    
    // Optimisasi: Tanpa setState untuk mencegah rebuild Scaffold dan widget lain 
    // secara berulang setiap kali ada perubahan lokasi kecil.
    _userPosition = Position(lng, lat);

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
      final beamLng = _userPosition!.lng.toDouble();
      final beamLat = _userPosition!.lat.toDouble();
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

  Future<Uint8List> _createCustomMarkerImage(Observation obs) async {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);

    ui.Image? markerImage;

    // 1. Try to load local file if exists
    if (obs.localFotoPath != null && obs.localFotoPath!.isNotEmpty) {
      final file = File(obs.localFotoPath!);
      if (file.existsSync()) {
        try {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
          final frameInfo = await codec.getNextFrame();
          markerImage = frameInfo.image;
        } catch (e) {
          print('Error loading local image for marker: $e');
        }
      }
    }

    // 2. Try to load from Supabase if network url exists and no local image loaded
    if (markerImage == null && obs.fotoUrl.isNotEmpty) {
      String imageUrl = obs.fotoUrl.trim(); // Hapus spasi jika ada
      if (!imageUrl.startsWith('http')) {
        imageUrl = Supabase.instance.client.storage
            .from('Foto_Observasi')
            .getPublicUrl(imageUrl);
      }
      
      // Bypass cache
      final bypassCacheUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(bypassCacheUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
          final frameInfo = await codec.getNextFrame();
          markerImage = frameInfo.image;
        } else {
          print('❌ HTTP Error ${response.statusCode} saat download marker: $bypassCacheUrl');
        }
      } catch (e) {
        print('❌ Error downloading image for marker [${obs.namaSpesies}]: $e');
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double radius = 50.0;
    const double pointerHeight = 25.0;
    const double width = radius * 2;
    const double height = radius * 2 + pointerHeight;
    const double borderSize = 6.0;

    final path = Path();
    path.addArc(
      Rect.fromCircle(center: const Offset(radius, radius), radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
    );
    path.lineTo(radius, height);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Inner white circle
    canvas.drawCircle(
      const Offset(radius, radius),
      radius - borderSize,
      Paint()..color = Colors.white,
    );

    if (markerImage != null) {
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(radius, radius),
            radius: radius - borderSize)));
      
      final double imgW = markerImage.width.toDouble();
      final double imgH = markerImage.height.toDouble();
      final double targetSize = (radius - borderSize) * 2;
      
      double scale = math.max(targetSize / imgW, targetSize / imgH);
      double dw = imgW * scale;
      double dh = imgH * scale;
      
      canvas.translate(radius - dw / 2, radius - dh / 2);
      canvas.scale(scale, scale);
      canvas.drawImage(markerImage, Offset.zero, Paint());
      canvas.restore();
    } else {
      canvas.drawCircle(
        const Offset(radius, radius),
        radius - borderSize,
        Paint()..color = color.withOpacity(0.2),
      );

      final tp = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 45)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(radius - tp.width / 2, radius - tp.height / 2));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
    final unsyncedCount = _observations.where((o) => !o.isSynced).length;

    return Scaffold(
      body: Stack(
        children: [
          if (_userPosition == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Mencari lokasi Anda...',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            MapWidget(
              onMapCreated: _onMapCreated,
              styleUri: AppMapbox.styleUrl,
              cameraOptions: CameraOptions(
                center: Point(coordinates: _userPosition!),
                zoom: _is3DPov ? 18.5 : 16.0,
                pitch: _is3DPov ? 65.0 : 0.0,
                bearing: 0.0,
              ),
            ),
          if (_userPosition != null)
            MapBottomSheet(
              observations: _observations,
              selectedObservationId: _selectedObservation?.id,
              sheetExtent: _sheetExtent,
              onObservationTap: (obs) {
                setState(() => _selectedObservation = obs);
                _flyToObservation(obs);
              },
            ),
          if (_userPosition != null)
            MapTopOverlay(unsyncedCount: unsyncedCount),
          if (_selectedObservation != null)
            ObservationDetailCard(
              obs: _selectedObservation!,
              onClose: () => setState(() => _selectedObservation = null),
            ),
          if (_userPosition != null)
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