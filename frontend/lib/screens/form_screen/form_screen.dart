import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ai_suggestion.dart';
import '../../providers/observation_provider.dart';
import '../../services/ai_service.dart';
import '../../utils/constants.dart';

class FormScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;

  const FormScreen({super.key, required this.lat, required this.lng});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = AiService();

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

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _fotoPath;
  bool _isLoading = false;

  // --- AI STATE ---
  AiSuggestion? _aiSuggestion;
  bool _isAiLoading = false;
  AiServiceException? _aiError;
  bool _aiApplied = false;

  // --- DATA DROPDOWN ---
  String _kategoriTakson = 'DK Primata';
  final List<String> _listDivisi = ['DK Karnivora', 'DK Herbivora', 'DK Primata', 'DK Burung', 'DK Reptil Amfibi', 'DK Insekta', 'DK Fauna Perairan'];

  String _statusKesehatan = 'Sehat';
  final List<String> _listKesehatan = ['Sehat', 'Luka', 'Sakit', 'Mati (Bangkai)', 'Lainnya'];

  String _aktivitas = 'Makan / Minum';
  final List<String> _listAktivitas = ['Makan / Minum', 'Istirahat / Tidur', 'Berpindah (Jalan/Terbang)', 'Bersuara', 'Interaksi Sosial', 'Lainnya'];

  String _tipeHabitat = 'Hutan Primer';
  final List<String> _listHabitat = ['Hutan Primer', 'Hutan Sekunder', 'Semak Belukar', 'Area Terbuka', 'Pemukiman', 'Lainnya'];

  String _posisiSatwa = 'Canopy (Tajuk)';
  final List<String> _listPosisi = ['Canopy (Tajuk)', 'Understory (Tengah)', 'Terestrial (Tanah)', 'Aquatik (Air)', 'Lainnya'];

  @override
  void dispose() {
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
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Ambil dari Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ref.read(localObservationProvider.notifier).pickAndSaveFoto(fromCamera: true);
                if (path != null) {
                  setState(() => _fotoPath = path);
                  _runAiIdentification(path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ref.read(localObservationProvider.notifier).pickAndSaveFoto(fromCamera: false);
                if (path != null) {
                  setState(() => _fotoPath = path);
                  _runAiIdentification(path);
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
        _aiError = AiServiceException(
          'Terjadi kesalahan: $e',
          code: 'unknown',
        );
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
    final finalWaktu = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

    // Ambil nilai akhir (Dropdown vs Custom Text)
    final kesehatanFinal = _statusKesehatan == 'Lainnya' ? _kesehatanCustomController.text : _statusKesehatan;
    final aktivitasFinal = _aktivitas == 'Lainnya' ? _aktivitasCustomController.text : _aktivitas;
    final habitatFinal = _tipeHabitat == 'Lainnya' ? _habitatCustomController.text : _tipeHabitat;
    final posisiFinal = _posisiSatwa == 'Lainnya' ? _posisiCustomController.text : _posisiSatwa;

    try {
      await ref.read(localObservationProvider.notifier).addObservation(
        namaSpesies: _spesiesController.text,
        namaLokal: _lokalController.text,
        kategoriTakson: _kategoriTakson,
        latitude: widget.lat,
        longitude: widget.lng,
        idPetugas: Supabase.instance.client.auth.currentUser?.id ?? '',
        localFotoPath: _fotoPath ?? '',
        jumlahIndividu: int.tryParse(_jumlahController.text),
        aktivitasTermati: aktivitasFinal,
        catatanHabitat: "Status: $kesehatanFinal | Habitat: $habitatFinal | Posisi: $posisiFinal | Veg: ${_vegetasiController.text} | Note: ${_catatanController.text}",
        waktuPengamatan: finalWaktu,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tally Sheet Tersimpan! 📝')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F0),
      appBar: AppBar(title: const Text('TALLY SHEET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), backgroundColor: Colors.white, foregroundColor: AppColors.primary, centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('1. WAKTU & LOKASI'),
            _buildCard(children: [
              Row(
                children: [
                  Expanded(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today, color: AppColors.primary), title: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Tanggal'), onTap: _pickDate)),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(child: ListTile(contentPadding: const EdgeInsets.only(left: 16), leading: const Icon(Icons.access_time, color: Colors.orange), title: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Waktu'), onTap: _pickTime)),
                ],
              ),
              const Divider(),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on, color: Colors.redAccent), title: Text('${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}'), subtitle: const Text('Koordinat GPS (Auto)')),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('2. FOTO OBSERVASI'),
            _buildCard(children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: double.infinity, height: 180, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)),
                    child: _fotoPath != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_fotoPath!), fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 44, color: Colors.grey), SizedBox(height: 8), Text('Ketuk untuk Ambil Foto'), SizedBox(height: 4), Text('AI akan otomatis mengenali spesies', style: TextStyle(fontSize: 11, color: Colors.grey))]),
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
            ]),
            const SizedBox(height: 16),

            if (_fotoPath != null) ...[
              _buildSectionHeader('IDENTIFIKASI AI'),
              _buildAiCard(),
              const SizedBox(height: 16),
            ],

            _buildSectionHeader('3. IDENTIFIKASI SATWA'),
            _buildCard(children: [
              if (_aiApplied) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.statusTerverifikasi.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.statusTerverifikasi.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppColors.statusTerverifikasi),
                      SizedBox(width: 6),
                      Text('Terisi otomatis dari AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusTerverifikasi)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(controller: _spesiesController, decoration: const InputDecoration(labelText: 'Nama Ilmiah (Latin)', border: OutlineInputBorder()), style: const TextStyle(fontStyle: FontStyle.italic), validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _lokalController, decoration: const InputDecoration(labelText: 'Nama Lokal / Panggilan', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(value: _kategoriTakson, decoration: const InputDecoration(labelText: 'Divisi Konservasi', border: OutlineInputBorder()), items: _listDivisi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _kategoriTakson = v!)),
              const SizedBox(height: 16),
              TextFormField(controller: _jumlahController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Individu', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups))),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('4. KONDISI & PERILAKU'),
            _buildCard(children: [
              _buildDropdownWithCustom(label: 'Status Kesehatan', value: _statusKesehatan, list: _listKesehatan, customController: _kesehatanCustomController, onChanged: (v) => setState(() => _statusKesehatan = v!)),
              const SizedBox(height: 16),
              _buildDropdownWithCustom(label: 'Aktivitas Utama', value: _aktivitas, list: _listAktivitas, customController: _aktivitasCustomController, onChanged: (v) => setState(() => _aktivitas = v!)),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('5. DETAIL HABITAT'),
            _buildCard(children: [
              _buildDropdownWithCustom(label: 'Tipe Habitat', value: _tipeHabitat, list: _listHabitat, customController: _habitatCustomController, onChanged: (v) => setState(() => _tipeHabitat = v!)),
              const SizedBox(height: 16),
              _buildDropdownWithCustom(label: 'Posisi / Stratifikasi', value: _posisiSatwa, list: _listPosisi, customController: _posisiCustomController, onChanged: (v) => setState(() => _posisiSatwa = v!)),
              const SizedBox(height: 16),
              TextFormField(controller: _vegetasiController, decoration: const InputDecoration(labelText: 'Vegetasi Dominan Sekitar', hintText: 'Misal: Pohon Rasamala', border: OutlineInputBorder())),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('6. CATATAN TAMBAHAN'),
            _buildCard(children: [
              TextFormField(controller: _catatanController, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan Tambahan', border: OutlineInputBorder())),
            ]),

            const SizedBox(height: 32),
            SizedBox(height: 56, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: _isLoading ? null : _submitData, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SIMPAN TALLY SHEET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCard() {
    if (_isAiLoading) {
      return _buildCard(children: [
        Row(
          children: const [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menganalisis foto...', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('AI sedang mengidentifikasi spesies', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ]);
    }

    if (_aiError != null) {
      final err = _aiError!;
      final icon = err.isOffline
          ? Icons.cloud_off_rounded
          : err.isTimeout
              ? Icons.timer_off_rounded
              : Icons.error_outline_rounded;
      return _buildCard(children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.statusRevisi),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Identifikasi AI Gagal',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusRevisi)),
                  const SizedBox(height: 4),
                  Text(err.message, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Anda tetap dapat mengisi form secara manual.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      ]);
    }

    final s = _aiSuggestion;
    if (s == null) return const SizedBox.shrink();

    final confidenceColor = s.confidence >= 0.85
        ? AppColors.statusTerverifikasi
        : s.confidence >= 0.5
            ? AppColors.statusMenunggu
            : AppColors.statusRevisi;

    return _buildCard(children: [
      Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Saran AI', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${s.confidenceLabel} • ${s.confidencePercent}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: confidenceColor),
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
      Text(s.speciesName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
      if (s.commonName.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(s.commonName, style: const TextStyle(fontSize: 14, color: Colors.black87)),
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
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primaryDark),
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
            Expanded(child: Text(s.habitatHint!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          ],
        ),
      ],
      if ((s.conservationStatus ?? '').isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Status Konservasi: ${s.conservationStatus}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
            border: Border.all(color: AppColors.statusRevisi.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.statusRevisi),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI tidak yakin dengan hasil ini. Periksa kembali sebelum menerapkan ke form.',
                  style: TextStyle(fontSize: 12, color: AppColors.statusRevisi, fontWeight: FontWeight.w500),
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
                backgroundColor: _aiApplied ? Colors.grey.shade400 : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _aiApplied ? null : _applyAiToForm,
              icon: Icon(_aiApplied ? Icons.check : Icons.download_done_rounded, size: 18),
              label: Text(_aiApplied ? 'Sudah Diterapkan' : 'Terapkan ke Form'),
            ),
          ),
        ],
      ),
    ]);
  }

  // Helper Section
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)));
  Widget _buildCard({required List<Widget> children}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  // Helper untuk Dropdown + Custom Field
  Widget _buildDropdownWithCustom({required String label, required String value, required List<String> list, required TextEditingController customController, required Function(String?) onChanged}) {
    return Column(
      children: [
        DropdownButtonFormField<String>(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), value: value, items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged),
        if (value == 'Lainnya') ...[
          const SizedBox(height: 12),
          TextFormField(controller: customController, decoration: InputDecoration(hintText: 'Tulis $label manual...', border: const OutlineInputBorder(), filled: true, fillColor: Colors.orange.shade50)),
        ],
      ],
    );
  }
}
