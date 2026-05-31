import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../models/ai_suggestion.dart';
import '../../models/observation.dart';
import '../../providers/observation_provider.dart';
import '../../services/ai_service.dart';
import '../../utils/constants.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'map_picker_screen.dart';

class FormScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;
  /// Jika diisi, FormScreen berjalan dalam mode Edit
  final Observation? editingObservation;

  const FormScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.editingObservation,
  });

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = AiService();

  MapboxMap? _miniMap;
  PointAnnotationManager? _miniMapAnnotationManager;
  bool _isListeningToCoordinates = true;

  // Pencarian lokasi dipindah ke full screen picker

  // Controllers Utama
  final _spesiesController = TextEditingController();
  final _lokalController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');
  final _vegetasiController = TextEditingController();
  final _catatanController = TextEditingController();

  // Controllers Custom (Untuk Opsi "Lainnya")
  final _kesehatanCustomController = TextEditingController();
  final _aktivitasCustomController = TextEditingController();
  final _habitatCustomController = TextEditingController();
  final _posisiCustomController = TextEditingController();

  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    final obs = widget.editingObservation;
    if (obs != null) {
      // ── MODE EDIT: pre-fill semua field dari data observasi ──
      _latController = TextEditingController(
        text: obs.latitude.toStringAsFixed(6),
      );
      _lngController = TextEditingController(
        text: obs.longitude.toStringAsFixed(6),
      );
      _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(obs.waktuPengamatan),
      );
      _timeController = TextEditingController(
        text: DateFormat('HH:mm').format(obs.waktuPengamatan),
      );
      _spesiesController.text = obs.namaSpesies;
      _lokalController.text = obs.namaLokal ?? '';
      _jumlahController.text = obs.jumlahIndividu?.toString() ?? '1';
      _kategoriTakson = obs.kategoriTakson;
      // Parse catatanHabitat: "Status: X | Habitat: Y | Posisi: Z | Veg: W | Note: N"
      _parseCatatanHabitat(obs.catatanHabitat);
      // Parse aktivitasTermati ke dropdown
      if (obs.aktivitasTermati != null) {
        if (_listAktivitas.contains(obs.aktivitasTermati)) {
          _aktivitas = obs.aktivitasTermati!;
        } else if (obs.aktivitasTermati!.isNotEmpty) {
          _aktivitas = 'Lainnya';
          _aktivitasCustomController.text = obs.aktivitasTermati!;
        }
      }
      // Foto: gunakan yang sudah ada
      _existingFotoUrl = obs.fotoUrl;
      if (obs.localFotoPath != null && obs.localFotoPath!.isNotEmpty) {
        _fotoPath = obs.localFotoPath;
      }
    } else {
      // ── MODE TAMBAH BARU ──
      _latController = TextEditingController(
        text: widget.lat.toStringAsFixed(6),
      );
      _lngController = TextEditingController(
        text: widget.lng.toStringAsFixed(6),
      );
      final now = DateTime.now();
      _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(now),
      );
      _timeController = TextEditingController(
        text: DateFormat('HH:mm').format(now),
      );
    }
    _latController.addListener(_onCoordinateTextChanged);
    _lngController.addListener(_onCoordinateTextChanged);
  }

  /// Parse string catatanHabitat kembali ke field individual.
  /// Format: "Status: X | Habitat: Y | Posisi: Z | Veg: W | Note: N"
  void _parseCatatanHabitat(String? catatan) {
    if (catatan == null || catatan.isEmpty) return;
    final parts = catatan.split(' | ');
    for (final part in parts) {
      if (part.startsWith('Status: ')) {
        final val = part.substring('Status: '.length).trim();
        if (_listKesehatan.contains(val)) {
          _statusKesehatan = val;
        } else if (val.isNotEmpty) {
          _statusKesehatan = 'Lainnya';
          _kesehatanCustomController.text = val;
        }
      } else if (part.startsWith('Habitat: ')) {
        final val = part.substring('Habitat: '.length).trim();
        if (_listHabitat.contains(val)) {
          _tipeHabitat = val;
        } else if (val.isNotEmpty) {
          _tipeHabitat = 'Lainnya';
          _habitatCustomController.text = val;
        }
      } else if (part.startsWith('Posisi: ')) {
        final val = part.substring('Posisi: '.length).trim();
        if (_listPosisi.contains(val)) {
          _posisiSatwa = val;
        } else if (val.isNotEmpty) {
          _posisiSatwa = 'Lainnya';
          _posisiCustomController.text = val;
        }
      } else if (part.startsWith('Veg: ')) {
        _vegetasiController.text = part.substring('Veg: '.length).trim();
      } else if (part.startsWith('Note: ')) {
        _catatanController.text = part.substring('Note: '.length).trim();
      }
    }
  }

  String? _fotoPath;
  String _existingFotoUrl = ''; // URL foto lama (Supabase) saat mode edit
  bool _isLoading = false;

  // --- AI STATE ---
  AiSuggestion? _aiSuggestion;
  bool _isAiLoading = false;
  AiServiceException? _aiError;
  bool _aiApplied = false;

  // --- DATA DROPDOWN ---
  String _kategoriTakson = 'DK Primata';
  final List<String> _listDivisi = [
    'DK Karnivora',
    'DK Herbivora',
    'DK Primata',
    'DK Burung',
    'DK Reptil Amfibi',
    'DK Insekta',
    'DK Fauna Perairan',
  ];

  String _statusKesehatan = 'Sehat';
  final List<String> _listKesehatan = [
    'Sehat',
    'Luka',
    'Sakit',
    'Mati (Bangkai)',
    'Lainnya',
  ];

  String _aktivitas = 'Makan / Minum';
  final List<String> _listAktivitas = [
    'Makan / Minum',
    'Istirahat / Tidur',
    'Berpindah (Jalan/Terbang)',
    'Bersuara',
    'Interaksi Sosial',
    'Lainnya',
  ];

  String _tipeHabitat = 'Hutan Primer';
  final List<String> _listHabitat = [
    'Hutan Primer',
    'Hutan Sekunder',
    'Semak Belukar',
    'Area Terbuka',
    'Pemukiman',
    'Lainnya',
  ];

  String _posisiSatwa = 'Canopy (Tajuk)';
  final List<String> _listPosisi = [
    'Canopy (Tajuk)',
    'Understory (Tengah)',
    'Terestrial (Tanah)',
    'Aquatik (Air)',
    'Lainnya',
  ];

  void _onCoordinateTextChanged() {
    if (!_isListeningToCoordinates) return;
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      _miniMap?.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
      ));
      _updateMiniMapMarker(lng, lat);
    }
  }

  Future<void> _updateMiniMapMarker(double lng, double lat) async {
    if (_miniMapAnnotationManager == null) return;
    await _miniMapAnnotationManager!.deleteAll();
    final pinBytes = await _createPinImage();
    await _miniMapAnnotationManager!.create(PointAnnotationOptions(
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
    canvas.drawCircle(const Offset(25, 25), 12, paint);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(25, 25), 12, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(50, 50);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _latController.removeListener(_onCoordinateTextChanged);
    _lngController.removeListener(_onCoordinateTextChanged);
    _latController.dispose();
    _lngController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _spesiesController.dispose();
    _lokalController.dispose();
    _jumlahController.dispose();
    _vegetasiController.dispose();
    _catatanController.dispose();
    _kesehatanCustomController.dispose();
    _aktivitasCustomController.dispose();
    _habitatCustomController.dispose();
    _posisiCustomController.dispose();
    super.dispose();
  }

  // --- FUNGSI PICKER WAKTU & GAMBAR ---
  Future<void> _pickDate() async {
    final parsedDate =
        DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      _timeController.text = DateFormat('HH:mm').format(dt);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Ambil dari Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final path = await ref
                      .read(localObservationProvider.notifier)
                      .pickAndSaveFoto(fromCamera: true);
                  if (path != null && mounted) {
                    setState(() => _fotoPath = path);
                    _runAiIdentification(path);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final path = await ref
                      .read(localObservationProvider.notifier)
                      .pickAndSaveFoto(fromCamera: false);
                  if (path != null && mounted) {
                    setState(() => _fotoPath = path);
                    _runAiIdentification(path);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAiIdentification(String path) async {
    setState(() {
      _isAiLoading = true;
      _aiError = null;
      _aiSuggestion = null;
      _aiApplied = false;
    });
    try {
      final result = await _aiService.identify(File(path));
      if (!mounted) return;

      if (result.isHumanDetected) {
        setState(() {
          _aiError = const AiServiceException(
            'Foto ini terdeteksi sebagai manusia. Silakan ambil foto fauna atau flora untuk identifikasi.',
            code: 'human_detected',
          );
          _aiSuggestion = null;
          _isAiLoading = false;
        });
        return;
      }
      setState(() {
        _aiSuggestion = result;
        _isAiLoading = false;
      });
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e;
        _isAiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = AiServiceException('Terjadi kesalahan: $e', code: 'unknown');
        _isAiLoading = false;
      });
    }
  }

  void _applyAiToForm() {
    final s = _aiSuggestion;
    if (s == null) return;

    _spesiesController.text = s.speciesName;
    _lokalController.text = s.commonName;

    final mappedDivisi = _mapTaxonomyToDivisi(s);
    if (mappedDivisi != null) {
      _kategoriTakson = mappedDivisi;
    }

    if ((s.habitatHint ?? '').isNotEmpty &&
        _vegetasiController.text.trim().isEmpty) {
      _vegetasiController.text = s.habitatHint!;
    }

    setState(() => _aiApplied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Form terisi dari saran AI ✨')),
    );
  }

  String? _mapTaxonomyToDivisi(AiSuggestion s) {
    final tax = s.taxonomy;
    final klass = (tax.className ?? '').toLowerCase();
    final order = (tax.order ?? '').toLowerCase();
    final phylum = (tax.phylum ?? '').toLowerCase();

    if (klass.contains('aves')) return 'DK Burung';
    if (klass.contains('reptilia') || klass.contains('amphibia')) {
      return 'DK Reptil Amfibi';
    }
    if (klass.contains('insecta')) return 'DK Insekta';
    if (klass.contains('actinopterygii') ||
        klass.contains('chondrichthyes') ||
        klass.contains('fish') ||
        phylum.contains('mollusca') ||
        phylum.contains('crustacea')) {
      return 'DK Fauna Perairan';
    }
    if (order.contains('primates')) return 'DK Primata';
    if (klass.contains('mammalia')) {
      if (order.contains('carnivora')) return 'DK Karnivora';
      if (order.contains('artiodactyla') ||
          order.contains('perissodactyla') ||
          order.contains('proboscidea') ||
          order.contains('rodentia') ||
          order.contains('lagomorpha')) {
        return 'DK Herbivora';
      }
      return 'DK Herbivora';
    }
    return null;
  }



  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Gabungkan Tanggal & Waktu Custom
    DateTime finalWaktu = DateTime.now();
    try {
      final dateParts = _dateController.text.split('-');
      final timeParts = _timeController.text.split(':');
      finalWaktu = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Format tanggal/waktu salah! (Gunakan YYYY-MM-DD dan HH:MM)',
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    final latParsed = double.tryParse(_latController.text) ?? widget.lat;
    final lngParsed = double.tryParse(_lngController.text) ?? widget.lng;

    // Ambil nilai akhir (Dropdown vs Custom Text)
    final kesehatanFinal = _statusKesehatan == 'Lainnya'
        ? _kesehatanCustomController.text
        : _statusKesehatan;
    final aktivitasFinal = _aktivitas == 'Lainnya'
        ? _aktivitasCustomController.text
        : _aktivitas;
    final habitatFinal = _tipeHabitat == 'Lainnya'
        ? _habitatCustomController.text
        : _tipeHabitat;
    final posisiFinal = _posisiSatwa == 'Lainnya'
        ? _posisiCustomController.text
        : _posisiSatwa;

    final catatanFinal =
        "Status: $kesehatanFinal | Habitat: $habitatFinal | Posisi: $posisiFinal | Veg: ${_vegetasiController.text} | Note: ${_catatanController.text}";

    try {
      final editObs = widget.editingObservation;
      if (editObs != null) {
        // ── MODE EDIT ──
        await ref
            .read(localObservationProvider.notifier)
            .updateObservation(
              id: editObs.id,
              namaSpesies: _spesiesController.text,
              namaLokal: _lokalController.text.isNotEmpty
                  ? _lokalController.text
                  : null,
              kategoriTakson: _kategoriTakson,
              latitude: latParsed,
              longitude: lngParsed,
              localFotoPath: _fotoPath ?? '',
              existingFotoUrl: _existingFotoUrl,
              jumlahIndividu: int.tryParse(_jumlahController.text),
              aktivitasTermati: aktivitasFinal,
              catatanHabitat: catatanFinal,
              waktuPengamatan: finalWaktu,
            );

        if (mounted) {
          Navigator.pop(context, true); // true = ada perubahan
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Observasi diperbarui! Menunggu verifikasi ulang ✏️'),
            ),
          );
        }
      } else {
        // ── MODE TAMBAH BARU ──
        await ref
            .read(localObservationProvider.notifier)
            .addObservation(
              namaSpesies: _spesiesController.text,
              namaLokal: _lokalController.text.isNotEmpty ? _lokalController.text : null,
              kategoriTakson: _kategoriTakson,
              latitude: latParsed,
              longitude: lngParsed,
              idPetugas: Supabase.instance.client.auth.currentUser?.id ?? '',
              localFotoPath: _fotoPath ?? '',
              jumlahIndividu: int.tryParse(_jumlahController.text),
              aktivitasTermati: aktivitasFinal,
              catatanHabitat: catatanFinal,
              waktuPengamatan: finalWaktu,
            );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tally Sheet Tersimpan! 📝')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editingObservation != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F0),
      appBar: AppBar(
        title: Text(
          isEditMode ? 'EDIT OBSERVASI' : 'TALLY SHEET',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('1. WAKTU PENGAMATAN'),
            _buildCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: 'Tanggal (YYYY-MM-DD)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: _pickDate,
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        decoration: InputDecoration(
                          labelText: 'Waktu (HH:MM)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.access_time, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.schedule),
                            onPressed: _pickTime,
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final now = DateTime.now();
                    _dateController.text = DateFormat('yyyy-MM-dd').format(now);
                    _timeController.text = DateFormat('HH:mm').format(now);
                  },
                  icon: const Icon(Icons.update),
                  label: const Text('Gunakan Waktu Saat Ini (Auto)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const ui.Size.fromHeight(40),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionHeader('2. LOKASI PENGAMATAN (KOORDINAT)'),
            _buildCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          final val = double.tryParse(v);
                          if (val == null) return 'Format angka salah';
                          if (val == 0.0) return 'Latitude tidak boleh 0';
                          if (val < -90 || val > 90) return 'Rentang -90 s/d 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          final val = double.tryParse(v);
                          if (val == null) return 'Format angka salah';
                          if (val == 0.0) return 'Longitude tidak boleh 0';
                          if (val < -180 || val > 180) return 'Rentang -180 s/d 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      // Fetch real GPS location instead of resetting to widget.lat
                      final pos = await geo.Geolocator.getCurrentPosition(
                        locationSettings: const geo.LocationSettings(
                          accuracy: geo.LocationAccuracy.high,
                        ),
                      );
                      if (mounted) {
                        _latController.text = pos.latitude.toStringAsFixed(6);
                        _lngController.text = pos.longitude.toStringAsFixed(6);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lokasi diperbarui ke GPS Terkini! 📍')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal mendapatkan GPS: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Gunakan Lokasi GPS Terkini (Auto)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const ui.Size.fromHeight(40),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final currentLat = double.tryParse(_latController.text) ?? widget.lat;
                    final currentLng = double.tryParse(_lngController.text) ?? widget.lng;
                    final result = await Navigator.push<Map<String, double>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPickerScreen(
                          initialLat: currentLat,
                          initialLng: currentLng,
                        ),
                      ),
                    );
                    if (result != null && mounted) {
                      final lat = result['lat']!;
                      final lng = result['lng']!;
                      setState(() {
                        _isListeningToCoordinates = false;
                        _latController.text = lat.toStringAsFixed(6);
                        _lngController.text = lng.toStringAsFixed(6);
                        _isListeningToCoordinates = true;
                      });
                      _miniMap?.setCamera(CameraOptions(
                        center: Point(coordinates: Position(lng, lat)),
                        zoom: 15.0,
                        pitch: 0.0,
                        bearing: 0.0,
                      ));
                      _updateMiniMapMarker(lng, lat);
                    }
                  },
                  child: AbsorbPointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Stack(
                          children: [
                            MapWidget(
                              styleUri: AppMapbox.styleUrl,
                              onMapCreated: (mapboxMap) async {
                                _miniMap = mapboxMap;
                                _miniMapAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                                
                                // Sembunyikan elemen UI bawaan Mapbox
                                mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
                                mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
                                mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false));
                                mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

                                final lat = double.tryParse(_latController.text) ?? widget.lat;
                                final lng = double.tryParse(_lngController.text) ?? widget.lng;
                                if (lat != 0.0 && lng != 0.0) {
                                  mapboxMap.setCamera(CameraOptions(
                                    center: Point(coordinates: Position(lng, lat)),
                                    zoom: 15.0,
                                    pitch: 0.0,
                                    bearing: 0.0,
                                  ));
                                  _updateMiniMapMarker(lng, lat);
                                }
                              },
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ketuk untuk Cari / Geser Peta',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionHeader('3. FOTO OBSERVASI'),
            _buildCard(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _fotoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_fotoPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text('Ketuk untuk Ambil Foto'),
                                SizedBox(height: 4),
                                Text(
                                  'AI akan otomatis mengenali spesies',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                if (_fotoPath != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Ganti Foto'),
                      ),
                      const Spacer(),
                      if (_aiSuggestion != null && !_isAiLoading)
                        TextButton.icon(
                          onPressed: () => _runAiIdentification(_fotoPath!),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Ulangi AI'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            if (_fotoPath != null) ...[
              _buildSectionHeader('IDENTIFIKASI AI'),
              _buildAiCard(),
              const SizedBox(height: 16),
            ],

            _buildSectionHeader('4. IDENTIFIKASI SATWA'),
            _buildCard(
              children: [
                if (_aiApplied) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusTerverifikasi.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusTerverifikasi.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.statusTerverifikasi,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Terisi otomatis dari AI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusTerverifikasi,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _spesiesController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Ilmiah (Latin)',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lokalController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lokal / Panggilan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _kategoriTakson,
                  decoration: const InputDecoration(
                    labelText: 'Divisi Konservasi',
                    border: OutlineInputBorder(),
                  ),
                  items: _listDivisi
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategoriTakson = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _jumlahController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Individu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionHeader('5. KONDISI & PERILAKU'),
            _buildCard(
              children: [
                _buildDropdownWithCustom(
                  label: 'Status Kesehatan',
                  value: _statusKesehatan,
                  list: _listKesehatan,
                  customController: _kesehatanCustomController,
                  onChanged: (v) => setState(() => _statusKesehatan = v!),
                ),
                const SizedBox(height: 16),
                _buildDropdownWithCustom(
                  label: 'Aktivitas Utama',
                  value: _aktivitas,
                  list: _listAktivitas,
                  customController: _aktivitasCustomController,
                  onChanged: (v) => setState(() => _aktivitas = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionHeader('6. DETAIL HABITAT'),
            _buildCard(
              children: [
                _buildDropdownWithCustom(
                  label: 'Tipe Habitat',
                  value: _tipeHabitat,
                  list: _listHabitat,
                  customController: _habitatCustomController,
                  onChanged: (v) => setState(() => _tipeHabitat = v!),
                ),
                const SizedBox(height: 16),
                _buildDropdownWithCustom(
                  label: 'Posisi / Stratifikasi',
                  value: _posisiSatwa,
                  list: _listPosisi,
                  customController: _posisiCustomController,
                  onChanged: (v) => setState(() => _posisiSatwa = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vegetasiController,
                  decoration: const InputDecoration(
                    labelText: 'Vegetasi Dominan Sekitar',
                    hintText: 'Misal: Pohon Rasamala',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSectionHeader('7. CATATAN TAMBAHAN'),
            _buildCard(
              children: [
                TextFormField(
                  controller: _catatanController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Tambahan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _submitData,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.editingObservation != null
                            ? 'SIMPAN PERUBAHAN'
                            : 'SIMPAN TALLY SHEET',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCard() {
    if (_isAiLoading) {
      return _buildCard(
        children: [
          Row(
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menganalisis foto...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI sedang mengidentifikasi spesies',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_aiError != null) {
      final err = _aiError!;
      final isHuman = err.code == 'human_detected';
      final icon = isHuman
          ? Icons.person_off_rounded
          : err.isOffline
          ? Icons.cloud_off_rounded
          : err.isTimeout
          ? Icons.timer_off_rounded
          : Icons.error_outline_rounded;
      final title = isHuman
          ? 'Bukan Fauna/Flora'
          : 'Identifikasi AI Gagal';
      return _buildCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.statusRevisi),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusRevisi,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(err.message, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                      'Anda tetap dapat mengisi form secara manual.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (err.isRetryable && _fotoPath != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _runAiIdentification(_fotoPath!),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ],
      );
    }

    final s = _aiSuggestion;
    if (s == null) return const SizedBox.shrink();

    final confidenceColor = s.confidence >= 0.85
        ? AppColors.statusTerverifikasi   // hijau: Sangat Yakin
        : s.confidence >= 0.5
        ? AppColors.statusMenunggu        // kuning: Cukup Yakin / Yakin
        : s.confidence > 0.0
        ? AppColors.statusMenunggu        // kuning: Tidak Yakin (ada hasil tapi rendah)
        : AppColors.statusRevisi;         // merah: Tidak Terdeteksi sama sekali

    return _buildCard(
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Saran AI',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: confidenceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${s.confidenceLabel} • ${s.confidencePercent}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: confidenceColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: s.confidence,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(confidenceColor),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          s.speciesName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (s.commonName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            s.commonName,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
        if (!s.taxonomy.isEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: s.taxonomy.toChipMap().entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if ((s.habitatHint ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.forest, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.habitatHint!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
        if ((s.conservationStatus ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Status Konservasi: ${s.conservationStatus}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
        if (!s.isConfident) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.statusRevisi.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.statusRevisi.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.statusRevisi,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI tidak yakin dengan hasil ini. Periksa kembali sebelum menerapkan ke form.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.statusRevisi,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _aiApplied
                      ? Colors.grey.shade400
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _aiApplied ? null : _applyAiToForm,
                icon: Icon(
                  _aiApplied ? Icons.check : Icons.download_done_rounded,
                  size: 18,
                ),
                label: Text(
                  _aiApplied ? 'Sudah Diterapkan' : 'Terapkan ke Form',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper Section
  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: Colors.grey,
        letterSpacing: 1,
      ),
    ),
  );
  Widget _buildCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  // Helper untuk Dropdown + Custom Field
  Widget _buildDropdownWithCustom({
    required String label,
    required String value,
    required List<String> list,
    required TextEditingController customController,
    required Function(String?) onChanged,
  }) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          initialValue: value,
          items: list
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
        if (value == 'Lainnya') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: customController,
            decoration: InputDecoration(
              hintText: 'Tulis $label manual...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.orange.shade50,
            ),
          ),
        ],
      ],
    );
  }
}
