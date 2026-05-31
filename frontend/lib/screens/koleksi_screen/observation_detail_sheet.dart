import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../models/observation.dart';
import '../../utils/constants.dart';
import '../../utils/tcg_style_utils.dart';
import '../../providers/observation_provider.dart';
import '../../providers/profile_provider.dart';
import '../form_screen/form_screen.dart';

Future<void> showObservationDetailSheet(
  BuildContext context,
  Observation observation,
  VoidCallback onDeleted, [
  Function(Observation)? onFlyTo,
  bool isOwner = false,
  VoidCallback? onEdited,
]) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ObservationDetailSheet(
      observation: observation,
      onDeleted: onDeleted,
      onFlyTo: onFlyTo,
      isOwner: isOwner,
      onEdited: onEdited,
    ),
  );
}

class ObservationDetailSheet extends ConsumerWidget {
  final Observation observation;
  final VoidCallback onDeleted;
  final Function(Observation)? onFlyTo;
  final bool isOwner;
  final VoidCallback? onEdited;

  const ObservationDetailSheet({
    super.key,
    required this.observation,
    required this.onDeleted,
    this.onFlyTo,
    this.isOwner = false,
    this.onEdited,
  });

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
  Widget build(BuildContext context, WidgetRef ref) {
    final grad = TcgStyleUtils.getGradientFor(observation.kategoriTakson);
    final profileState = ref.watch(profileProvider);
    final profile = profileState.value;

    bool canDelete = false;
    if (profile != null) {
      if (profile.role == 'Admin') {
        canDelete = true;
      } else if (profile.role == 'Kordinator_Divisi' &&
          profile.divisiTakson == observation.kategoriTakson) {
        canDelete = true;
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [grad[0], grad[1], grad[1], grad[0]],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
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
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 2,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    observation.namaLokal != null &&
                                            observation.namaLokal!.isNotEmpty
                                        ? observation.namaLokal!
                                        : 'Nama lokal tidak diketahui',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: observation.statusApproval),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 20),

                        // 3. WAKTU & LOKASI
                        _buildInfoRow(
                          Icons.calendar_month_rounded,
                          '${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(observation.waktuPengamatan)} WIB',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                Icons.location_on_rounded,
                                '${observation.latitude.toStringAsFixed(6)}, ${observation.longitude.toStringAsFixed(6)}',
                              ),
                            ),
                            if (onFlyTo != null)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.map_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Lihat di Peta',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onFlyTo!(observation);
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                            ),
                            child: MapWidget(
                              styleUri: AppMapbox.styleUrl,
                              onMapCreated: (mapboxMap) async {
                                await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
                                await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
                                await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
                                await mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false));

                                mapboxMap.setCamera(CameraOptions(
                                  center: Point(coordinates: Position(observation.longitude, observation.latitude)),
                                  zoom: 14.0,
                                ));
                                final annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                                final pinBytes = await _createPinImage();
                                annotationManager.create(PointAnnotationOptions(
                                  geometry: Point(coordinates: Position(observation.longitude, observation.latitude)),
                                  image: pinBytes,
                                  iconAnchor: IconAnchor.CENTER,
                                ));
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 20),

                        // 4. GRID DETAIL DATA (Dengan Icon Menarik)
                        const Text(
                          'DETAIL OBSERVASI',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              _buildDetailGridItem(
                                Icons.category_rounded,
                                Colors.white,
                                'Taksonomi',
                                observation.kategoriTakson,
                              ),
                              const Divider(height: 24, color: Colors.white24),
                              _buildDetailGridItem(
                                Icons.groups_rounded,
                                Colors.white,
                                'Jumlah Individu',
                                observation.jumlahIndividu != null
                                    ? '${observation.jumlahIndividu} Ekor'
                                    : '-',
                              ),
                              const Divider(height: 24, color: Colors.white24),
                              _buildDetailGridItem(
                                Icons.directions_run_rounded,
                                Colors.white,
                                'Aktivitas',
                                observation.aktivitasTermati ?? '-',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 5. CATATAN HABITAT & KONDISI
                        if (observation.catatanHabitat != null &&
                            observation.catatanHabitat!.isNotEmpty) ...[
                          const Text(
                            'KONDISI & HABITAT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.white70,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              observation.catatanHabitat!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],

                        // 6. DRAFT WARNING
                        if (!observation.isSynced) ...[
                          const SizedBox(height: 20),
                          _DraftBanner(),
                        ],

                        // 7. TOMBOL AKSI (di bawah konten, tidak menghalangi)
                        if (isOwner || canDelete) ...[
                          const SizedBox(height: 24),
                          const Divider(height: 1, color: Colors.white24),
                          const SizedBox(height: 16),
                          // isOwner → Edit + Hapus side by side
                          // canDelete saja (Admin/Kordinator) → Hapus full width
                          if (isOwner)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(0xFF2E7D32), // Solid Green
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _openEditForm(context),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Edit Observasi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.red.shade700, // Solid Red
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _confirmDelete(context, ref),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Hapus',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (canDelete)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.red.shade700, // Solid Red
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _confirmDelete(context, ref),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Hapus Observasi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ] else
                          const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),

        );
      },
    );
  }

  // --- Navigasi ke FormScreen mode Edit ---
  void _openEditForm(BuildContext context) {
    Navigator.pop(context); // Tutup bottom sheet dulu
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormScreen(
          lat: observation.latitude,
          lng: observation.longitude,
          editingObservation: observation,
        ),
      ),
    ).then((edited) {
      // edited == true berarti user menyimpan perubahan
      if (edited == true) {
        onEdited?.call();
        onDeleted(); // Refresh list (reuse callback yang sudah ada)
      }
    });
  }

  // --- WIDGET HELPER ---
  String? _resolveImagePath() {
    final local = observation.localFotoPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return local;
    }
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
          decoration: const BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? _renderImage(imagePath)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada foto',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
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
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
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
                icon: const Icon(
                  Icons.zoom_out_map_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImageViewer(imagePath: imagePath),
                    ),
                  );
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
              Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat foto',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
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
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGridItem(
    IconData icon,
    Color iconColor,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
        content: const Text(
          'Apakah kamu yakin ingin menghapus data observasi ini secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref
                  .read(localObservationProvider.notifier)
                  .deleteObservation(observation.id);
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: imagePath.startsWith('http')
              ? Image.network(imagePath)
              : Image.file(File(imagePath)),
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
      'TERVERIFIKASI' => (
        '✓ Terverifikasi',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      'PERLU_DIREVISI' => (
        '⚠ Revisi',
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      ),
      _ => ('⏳ Menunggu', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data ini tersimpan secara lokal dan belum tersinkronisasi ke server.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
