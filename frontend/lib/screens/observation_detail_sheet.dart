import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/observation.dart';
import '../utils/constants.dart';
import '../providers/observation_provider.dart';

Future<void> showObservationDetailSheet(BuildContext context, Observation observation, VoidCallback onDeleted) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ObservationDetailSheet(observation: observation, onDeleted: onDeleted),
  );
}

class ObservationDetailSheet extends ConsumerWidget {
  final Observation observation;
  final VoidCallback onDeleted;

  const ObservationDetailSheet({super.key, required this.observation, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // 1. HEADER FOTO
                  _buildHeaderPhoto(context),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. SEKSI IDENTITAS (Gaya Pokemon)
                        _buildMainInfo(),
                        const SizedBox(height: 24),

                        // 3. DETAIL PENGAMATAN
                        _buildSectionTitle('DETAIL PENGAMATAN'),
                        _buildDetailGrid(),
                        const SizedBox(height: 24),

                        // 4. ISI LAPORAN (TALLY SHEET)
                        _buildSectionTitle('ISI LAPORAN TALLY SHEET'),
                        _buildTallyContent(),
                        
                        const SizedBox(height: 100), // Space buat tombol
                      ],
                    ),
                  ),
                ],
              ),

              // 5. TOMBOL HAPUS (Kanan Bawah)
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton.extended(
                  heroTag: 'delete_obs',
                  backgroundColor: Colors.red.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  onPressed: () => _confirmDelete(context, ref),
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  label: Text('Hapus Data Lokal', 
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderPhoto(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade300),
          child: observation.fotoUrl != null && observation.fotoUrl!.isNotEmpty
              ? Image.file(File(observation.fotoUrl!), fit: BoxFit.cover)
              : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white)),
        ),
        Positioned(
          top: 15,
          left: 15,
          child: CircleAvatar(
            backgroundColor: Colors.black26,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(observation.namaLokal ?? 'Satuwa Misterius', 
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF5F4B00))),
        ),
        const SizedBox(height: 8),
        Text(observation.namaSpesies, 
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        _buildTaksonBadge(),
      ],
    );
  }

  Widget _buildTaksonBadge() {
    final color = markerColorForTakson(observation.kategoriTakson);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(observation.kategoriTakson.toUpperCase(), 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
    );
  }

  Widget _buildDetailGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _rowInfo(Icons.access_time_rounded, 'Waktu', DateFormat('dd MMM yyyy, HH:mm').format(observation.waktuPengamatan)),
          const Divider(height: 24),
          _rowInfo(Icons.person_outline_rounded, 'Petugas', observation.idPetugas),
          const Divider(height: 24),
          _rowInfo(Icons.map_outlined, 'Lokasi', '${observation.latitude.toStringAsFixed(5)}, ${observation.longitude.toStringAsFixed(5)}'),
        ],
      ),
    );
  }

  Widget _buildTallyContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Text(observation.catatanHabitat ?? 'Tidak ada detail tambahan.', 
        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF2C3E50))),
    );
  }

  Widget _rowInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        )
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data?'),
        content: const Text('Data dummy ini akan dihapus permanen dari memori HP-mu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(localObservationProvider.notifier).deleteObservation(observation.id);
              if (context.mounted) {
                Navigator.pop(ctx); // Tutup dialog
                Navigator.pop(context); // Tutup sheet
                onDeleted(); // Panggil refresh di screen utama
              }
            }, 
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}