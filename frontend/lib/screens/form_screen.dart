import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Jangan lupa install package intl
import '../providers/observation_provider.dart';
import '../utils/constants.dart';

class FormScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;

  const FormScreen({super.key, required this.lat, required this.lng});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _spesiesController = TextEditingController();
  final _lokalController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');
  final _aktivitasCustomController = TextEditingController();
  final _catatanController = TextEditingController();
  final _vegetasiController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _fotoPath;
  bool _isLoading = false;

  // --- DATA DROPDOWN (Sesuai Standar Tally Sheet) ---
  String _kategoriTakson = 'DK Primata';
  final List<String> _listDivisi = [
    'DK Karnivora', 'DK Herbivora', 'DK Primata', 'DK Burung', 
    'DK Reptil Amfibi', 'DK Insekta', 'DK Fauna Perairan'
  ];

  String _statusKesehatan = 'Sehat';
  final List<String> _listKesehatan = ['Sehat', 'Luka', 'Sakit', 'Mati (Bangkai)'];

  String _aktivitas = 'Makan / Minum';
  final List<String> _listAktivitas = [
    'Makan / Minum', 'Istirahat / Tidur', 'Berpindah (Jalan/Terbang)', 
    'Bersuara', 'Interaksi Sosial', 'Lainnya'
  ];

  String _tipeHabitat = 'Hutan Primer';
  final List<String> _listHabitat = [
    'Hutan Primer', 'Hutan Sekunder', 'Semak Belukar', 'Area Terbuka', 'Pemukiman'
  ];

  String _posisiSatwa = 'Canopy (Tajuk)';
  final List<String> _listPosisi = [
    'Canopy (Tajuk)', 'Understory (Tengah)', 'Terestrial (Tanah)', 'Aquatik (Air)'
  ];

  @override
  void dispose() {
    _spesiesController.dispose();
    _lokalController.dispose();
    _jumlahController.dispose();
    _aktivitasCustomController.dispose();
    _catatanController.dispose();
    _vegetasiController.dispose();
    super.dispose();
  }

  // --- FUNGSI PICKER ---
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final finalWaktu = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute
    );

    try {
      await ref.read(localObservationProvider.notifier).addObservation(
        namaSpesies: _spesiesController.text,
        namaLokal: _lokalController.text,
        kategoriTakson: _kategoriTakson,
        latitude: widget.lat,
        longitude: widget.lng,
        idPetugas: 'petugas-001',
        localFotoPath: _fotoPath ?? '',
        jumlahIndividu: int.tryParse(_jumlahController.text),
        aktivitasTermati: _aktivitas == 'Lainnya' ? _aktivitasCustomController.text : _aktivitas,
        // Tips: Untuk data tambahan seperti Habitat/Kesehatan, sementara gabung ke catatanHabitat
        catatanHabitat: "Status: $_statusKesehatan | Habitat: $_tipeHabitat | Posisi: $_posisiSatwa | Veg: ${_vegetasiController.text} | Note: ${_catatanController.text}",
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
      appBar: AppBar(
        title: const Text('TALLY SHEET OBSERVASI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('1. INFORMASI DASAR'),
            _buildInfoCard(),
            const SizedBox(height: 16),

            _buildSectionHeader('2. IDENTIFIKASI SATWA'),
            _buildSatwaCard(),
            const SizedBox(height: 16),

            _buildSectionHeader('3. KONDISI & PERILAKU'),
            _buildKondisiCard(),
            const SizedBox(height: 16),

            _buildSectionHeader('4. DETAIL HABITAT'),
            _buildHabitatCard(),
            const SizedBox(height: 16),

            _buildSectionHeader('5. DOKUMENTASI & CATATAN'),
            _buildCatatanCard(),
            
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoCard() {
    return _buildCard(children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today, color: AppColors.primary),
        title: Text(DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate)),
        subtitle: const Text('Tanggal Pengamatan'),
        onTap: _pickDate,
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.location_on, color: Colors.redAccent),
        title: Text('${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}'),
        subtitle: const Text('Titik Koordinat (Autofill)'),
      ),
    ]);
  }

  Widget _buildSatwaCard() {
    return _buildCard(children: [
      TextFormField(
        controller: _lokalController,
        decoration: InputDecoration(
          labelText: 'Nama Lokal / Panggilan',
          filled: true,
          fillColor: const Color(0xFFFFFDE7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.stars, color: Colors.amber),
        ),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _spesiesController,
        decoration: const InputDecoration(labelText: 'Nama Ilmiah (Latin)', border: UnderlineInputBorder()),
        style: const TextStyle(fontStyle: FontStyle.italic),
        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _kategoriTakson,
        decoration: const InputDecoration(labelText: 'Divisi Konservasi'),
        items: _listDivisi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _kategoriTakson = v!),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _jumlahController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Jumlah Individu', prefixIcon: Icon(Icons.groups)),
      ),
    ]);
  }

  Widget _buildKondisiCard() {
    return _buildCard(children: [
      DropdownButtonFormField<String>(
        value: _statusKesehatan,
        decoration: const InputDecoration(labelText: 'Status Kesehatan'),
        items: _listKesehatan.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _statusKesehatan = v!),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _aktivitas,
        decoration: const InputDecoration(labelText: 'Aktivitas Utama'),
        items: _listAktivitas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _aktivitas = v!),
      ),
      if (_aktivitas == 'Lainnya') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _aktivitasCustomController,
          decoration: const InputDecoration(hintText: 'Tulis aktivitas manual...'),
        ),
      ],
    ]);
  }

  Widget _buildHabitatCard() {
    return _buildCard(children: [
      DropdownButtonFormField<String>(
        value: _tipeHabitat,
        decoration: const InputDecoration(labelText: 'Tipe Habitat'),
        items: _listHabitat.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _tipeHabitat = v!),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _posisiSatwa,
        decoration: const InputDecoration(labelText: 'Posisi / Stratifikasi'),
        items: _listPosisi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _posisiSatwa = v!),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _vegetasiController,
        decoration: const InputDecoration(labelText: 'Vegetasi Dominan Sekitar', hintText: 'Misal: Pohon Rasamala, Bambu...'),
      ),
    ]);
  }

  Widget _buildCatatanCard() {
    return _buildCard(children: [
      Center(
        child: GestureDetector(
          onTap: () async {
            final path = await ref.read(localObservationProvider.notifier).pickAndSaveFoto(fromCamera: true);
            if (path != null) setState(() => _fotoPath = path);
          },
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: _fotoPath != null 
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_fotoPath!), fit: BoxFit.cover))
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), Text('Tambah Foto Satwa')]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _catatanController,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Catatan Tambahan', border: OutlineInputBorder()),
      ),
    ]);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: _isLoading ? null : _submitData,
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SIMPAN TALLY SHEET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}