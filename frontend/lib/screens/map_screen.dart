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
import '../widgets/navbar.dart';

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
  bool _firstLocationFixed = false;
  bool _is3DPov = true;
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.28);

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
        [8.0, 8.0, 8.0], // sesuaikan skala model kamu
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
              zoom: _is3DPov ? 18.5 : 16.0, // <-- Samakan nilai defaultnya
              pitch: _is3DPov ? 65.0 : 0.0, // <-- Samakan nilai defaultnya
              bearing: 0.0,
            ),
          ),
          _buildBottomSheet(),
          _buildTopOverlay(),
          if (_selectedObservation != null)
            _buildDetailCard(_selectedObservation!),
          _buildMapControls(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Navbar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              onAddTap: () {
                // TODO: Implement add observation action
                print('Tombol Add ditekan dari Map Screen!');
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
  return NotificationListener<DraggableScrollableNotification>(
    onNotification: (notification) {
      _sheetExtent.value = notification.extent;
      return false; 
    },
child: DraggableScrollableSheet(
      initialChildSize: 0.15, // Ukuran awal saat tertutup (collapse)
      minChildSize: 0.15,     // Batas paling bawah
      maxChildSize: 0.40,     // Batas paling atas (0.40 berarti hanya 40% layar)
      snap: true,             // <-- TAMBAHKAN INI: Memaksa sheet untuk snap
      snapSizes: const [0.15, 0.40], // <-- TAMBAHKAN INI: Sheet HANYA akan berhenti di 15% atau 40%
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          // PERUBAHAN: Gunakan SingleChildScrollView agar seluruh area bisa didrag
          child: SingleChildScrollView(
            controller: scrollController, // Berikan controller di sini!
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
                              '${_dummyObservations.length} titik',
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
                  // PERUBAHAN: Hilangkan controller dari ListView horizontal ini
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _dummyObservations.length,
                    itemBuilder: (_, i) =>
                        _buildObservationCard(_dummyObservations[i]),
                  ),
                ),
                // Jika kamu ingin menambahkan konten lain saat di-expand,
                // bisa ditambahkan di bawah sini.
                // Contoh:
                // const SizedBox(height: 20),
                // Padding(padding: EdgeInsets.all(16), child: Text("Detail Lainnya")),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  // ─────────────────────────────────────────────────────────
  // OBSERVATION CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildObservationCard(Observation obs) {
    final color = markerColorForTakson(obs.kategoriTakson);
    final emoji = markerEmojiForTakson(obs.kategoriTakson);
    final isSelected = _selectedObservation?.id == obs.id;

    // Simulate distance
    final int distance = (10 + (obs.id.hashCode % 90));

    return GestureDetector(
      onTap: () {
        setState(() => _selectedObservation = obs);
        _flyToObservation(obs);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Image Background
              if (obs.fotoUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    obs.fotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(color, emoji),
                  ),
                )
              else
                Positioned.fill(
                  child: _buildPlaceholder(color, emoji),
                ),

              // Gradient Overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            obs.kategoriTakson.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (!obs.isSynced)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    // Species name
                    Text(
                      obs.namaSpesies,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Distance
                    Row(
                      children: [
                        const Icon(Icons.directions_walk, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '$distance m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color, String emoji) {
    return Container(
      color: color.withOpacity(0.2),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 40),
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

  void _togglePov() {
    setState(() {
      _is3DPov = !_is3DPov;
    });

    _mapboxMap?.flyTo(
      CameraOptions(
        zoom: _is3DPov ? 18.5 : 16.0, // <-- UBAH: Zoom level lebih ideal (18.5)
        pitch: _is3DPov ? 65.0 : 0.0, // <-- UBAH: Pitch diturunkan ke 65.0 agar mirip PoGo
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  // ─────────────────────────────────────────────────────────
  // MAP CONTROLS (POV & RECENTER)
  // ─────────────────────────────────────────────────────────
  Widget _buildMapControls() {
    return ValueListenableBuilder<double>(
      valueListenable: _sheetExtent,
      builder: (context, extent, child) {
        // Calculate bottom padding based on sheet extent
        // The sheet height is screenHeight * extent.
        // We add some extra padding (e.g., 16) to sit above the sheet.
        final bottomPadding = (MediaQuery.of(context).size.height * extent) + 16;
        
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
                onPressed: _togglePov,
                child: Icon(_is3DPov ? Icons.map_outlined : Icons.view_in_ar),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 4,
                onPressed: () => _mapboxMap?.flyTo(
                  CameraOptions(
                    center: Point(coordinates: _userPosition),
                    zoom: _is3DPov ? 19.5 : 16.0,
                    pitch: _is3DPov ? 80.0 : 0.0,
                    bearing: 0.0,
                  ),
                  MapAnimationOptions(duration: 800),
                ),
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        );
      },
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