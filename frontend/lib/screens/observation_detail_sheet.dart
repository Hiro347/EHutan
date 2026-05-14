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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // 1. HEADER FOTO DENGAN ZOOM
                  _buildHeaderPhoto(context),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. JUDUL SPESIES & NAMA LOKAL (Sesuai Wireframe)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    observation.namaSpesies,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Color(0xFF1A2400)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    observation.namaLokal != null && observation.namaLokal!.isNotEmpty ? observation.namaLokal! : 'Nama lokal tidak diketahui',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: observation.statusApproval),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // 3. WAKTU & LOKASI
                        _buildInfoRow(Icons.calendar_month_rounded, '${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(observation.waktuPengamatan)} WIB'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.location_on_rounded, '${observation.latitude.toStringAsFixed(6)}, ${observation.longitude.toStringAsFixed(6)}'),
                        
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // 4. GRID DETAIL DATA (Dengan Icon Menarik)
                        const Text('DETAIL OBSERVASI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              _buildDetailGridItem(Icons.category_rounded, Colors.purple, 'Taksonomi', observation.kategoriTakson),
                              const Divider(height: 24),
                              _buildDetailGridItem(Icons.groups_rounded, Colors.blue, 'Jumlah Individu', observation.jumlahIndividu != null ? '${observation.jumlahIndividu} Ekor' : '-'),
                              const Divider(height: 24),
                              _buildDetailGridItem(Icons.directions_run_rounded, Colors.orange, 'Aktivitas', observation.aktivitasTermati ?? '-'),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        // 5. CATATAN HABITAT & KONDISI
                        if (observation.catatanHabitat != null && observation.catatanHabitat!.isNotEmpty) ...[
                          const Text('KONDISI & HABITAT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: Text(observation.catatanHabitat!, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF2C3E50))),
                          ),
                        ],

                        // 6. DRAFT WARNING
                        if (!observation.isSynced) ...[
                          const SizedBox(height: 20),
                          _DraftBanner(),
                        ],
                        
                        const SizedBox(height: 100), // Ruang untuk tombol hapus
                      ],
                    ),
                  ),
                ],
              ),

              // TOMBOL HAPUS (Kanan Bawah)
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton.extended(
                  heroTag: 'delete_obs',
                  backgroundColor: Colors.red.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
                  onPressed: () => _confirmDelete(context, ref),
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  label: Text('Hapus', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET HELPER ---
  String? _resolveImagePath() {
    final local = observation.localFotoPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) return local;
    return resolveSupabaseFotoUrl(observation.fotoUrl);
  }

  Widget _buildHeaderPhoto(BuildContext context) {
    final imagePath = _resolveImagePath();
    final bool hasImage = imagePath != null;
    return Stack(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? _renderImage(imagePath)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Tidak ada foto', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
        ),
        // Tombol Close
        Positioned(
          top: 16,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black45,
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
        ),
        // Tombol Zoom Fullscreen
        if (hasImage)
          Positioned(
            bottom: 16,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: imagePath)));
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _renderImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text('Gagal memuat foto', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Center(
      child: Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade400),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A2400)))),
      ],
    );
  }

  Widget _buildDetailGridItem(IconData icon, Color iconColor, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2400))),
            ],
          ),
        ),
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
                Navigator.pop(ctx);
                Navigator.pop(context);
                onDeleted();
              }
            }, 
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET FULLSCREEN GAMBAR ---
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: imagePath.startsWith('http') ? Image.network(imagePath) : Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// --- SUB-WIDGETS ---
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'TERVERIFIKASI' => ('✓ Terverifikasi', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'PERLU_DIREVISI' => ('⚠ Revisi', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      _ => ('⏳ Menunggu', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade300)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Data ini tersimpan secara lokal dan belum tersinkronisasi ke server.', style: TextStyle(fontSize: 12, color: Colors.orange.shade900))),
        ],
      ),
    );
  }
}