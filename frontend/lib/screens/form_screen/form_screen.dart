import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/observation_provider.dart';
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
                if (path != null) setState(() => _fotoPath = path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ref.read(localObservationProvider.notifier).pickAndSaveFoto(fromCamera: false);
                if (path != null) setState(() => _fotoPath = path);
              },
            ),
          ],
        ),
      ),
    );
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

            _buildSectionHeader('2. IDENTIFIKASI SATWA'),
            _buildCard(children: [
              TextFormField(controller: _spesiesController, decoration: const InputDecoration(labelText: 'Nama Ilmiah (Latin)', border: OutlineInputBorder()), style: const TextStyle(fontStyle: FontStyle.italic), validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _lokalController, decoration: const InputDecoration(labelText: 'Nama Lokal / Panggilan', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(initialValue: _kategoriTakson, decoration: const InputDecoration(labelText: 'Divisi Konservasi', border: OutlineInputBorder()), items: _listDivisi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _kategoriTakson = v!)),
              const SizedBox(height: 16),
              TextFormField(controller: _jumlahController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Individu', border: OutlineInputBorder(), prefixIcon: Icon(Icons.groups))),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('3. KONDISI & PERILAKU'),
            _buildCard(children: [
              _buildDropdownWithCustom(label: 'Status Kesehatan', value: _statusKesehatan, list: _listKesehatan, customController: _kesehatanCustomController, onChanged: (v) => setState(() => _statusKesehatan = v!)),
              const SizedBox(height: 16),
              _buildDropdownWithCustom(label: 'Aktivitas Utama', value: _aktivitas, list: _listAktivitas, customController: _aktivitasCustomController, onChanged: (v) => setState(() => _aktivitas = v!)),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('4. DETAIL HABITAT'),
            _buildCard(children: [
              _buildDropdownWithCustom(label: 'Tipe Habitat', value: _tipeHabitat, list: _listHabitat, customController: _habitatCustomController, onChanged: (v) => setState(() => _tipeHabitat = v!)),
              const SizedBox(height: 16),
              _buildDropdownWithCustom(label: 'Posisi / Stratifikasi', value: _posisiSatwa, list: _listPosisi, customController: _posisiCustomController, onChanged: (v) => setState(() => _posisiSatwa = v!)),
              const SizedBox(height: 16),
              TextFormField(controller: _vegetasiController, decoration: const InputDecoration(labelText: 'Vegetasi Dominan Sekitar', hintText: 'Misal: Pohon Rasamala', border: OutlineInputBorder())),
            ]),
            const SizedBox(height: 16),

            _buildSectionHeader('5. DOKUMENTASI & CATATAN'),
            _buildCard(children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: double.infinity, height: 160, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)),
                    child: _fotoPath != null 
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_fotoPath!), fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Ketuk untuk Tambah Foto')]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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

  // Helper Section
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)));
  Widget _buildCard({required List<Widget> children}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  // Helper untuk Dropdown + Custom Field
  Widget _buildDropdownWithCustom({required String label, required String value, required List<String> list, required TextEditingController customController, required Function(String?) onChanged}) {
    return Column(
      children: [
        DropdownButtonFormField<String>(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), initialValue: value, items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged),
        if (value == 'Lainnya') ...[
          const SizedBox(height: 12),
          TextFormField(controller: customController, decoration: InputDecoration(hintText: 'Tulis $label manual...', border: const OutlineInputBorder(), filled: true, fillColor: Colors.orange.shade50)),
        ],
      ],
    );
  }
}