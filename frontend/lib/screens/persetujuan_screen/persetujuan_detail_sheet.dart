import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/observation.dart';
import '../../models/user_profile.dart';
import '../../services/persetujuan_service.dart';
import '../../utils/constants.dart';
import '../../utils/tcg_style_utils.dart';

Future<void> showPersetujuanDetailSheet({
  required BuildContext context,
  required Observation observation,
  required UserProfile userProfile,
  required VoidCallback onRefresh,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PersetujuanDetailSheet(
      observation: observation,
      userProfile: userProfile,
      onRefresh: onRefresh,
    ),
  );
}

class PersetujuanDetailSheet extends StatefulWidget {
  final Observation observation;
  final UserProfile userProfile;
  final VoidCallback onRefresh;

  const PersetujuanDetailSheet({
    super.key,
    required this.observation,
    required this.userProfile,
    required this.onRefresh,
  });

  @override
  State<PersetujuanDetailSheet> createState() => _PersetujuanDetailSheetState();
}

class _PersetujuanDetailSheetState extends State<PersetujuanDetailSheet> {
  final PersetujuanService _service = PersetujuanService();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isSubmitting = true);
    try {
      await _service.updateStatus(
        obsId: widget.observation.id,
        statusApproval: status,
        catatanRevisi: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status berhasil diperbarui menjadi \$status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui: \$e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grad = TcgStyleUtils.getGradientFor(
      widget.observation.kategoriTakson,
    );

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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header Status & Nama
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.observation.namaSpesies,
                                style: const TextStyle(
                                  fontSize: 24,
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
                              Row(
                                children: [
                                  Text(
                                    TcgStyleUtils.getEmojiFor(
                                      widget.observation.kategoriTakson,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.observation.namaLokal != null &&
                                              widget
                                                  .observation
                                                  .namaLokal!
                                                  .isNotEmpty
                                          ? widget.observation.namaLokal!
                                          : 'Nama lokal tidak diketahui',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(widget.observation.statusApproval),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Colors.white24),
                    const SizedBox(height: 20),

                    // Info Umum
                    _buildInfoRow(
                      Icons.calendar_month_rounded,
                      '${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(widget.observation.waktuPengamatan)} WIB',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.person_outline_rounded,
                      'Dilaporkan oleh ID: ${widget.observation.idPetugas.substring(0, 8)}...',
                    ),

                    const SizedBox(height: 20),

                    // Catatan Revisi Lama (Jika ada)
                    if (widget.observation.catatanRevisi != null &&
                        widget.observation.catatanRevisi!.isNotEmpty) ...[
                      const Text(
                        'CATATAN REVISI SEBELUMNYA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          widget.observation.catatanRevisi!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Foto Observasi (opsional)
                    if (widget.observation.fotoUrl.isNotEmpty) ...[
                      const Text(
                        'FOTO BUKTI',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          resolveSupabaseFotoUrl(widget.observation.fotoUrl) ??
                              '',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 200,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Form untuk Admin/Kordinator
                    if (widget.userProfile.canVerify &&
                        widget.observation.statusApproval ==
                            'MENUNGGU_VERIFIKASI') ...[
                      const Divider(height: 1, color: Colors.white24),
                      const SizedBox(height: 20),
                      const Text(
                        'TINDAKAN VERIFIKASI',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tambahkan catatan jika perlu direvisi...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),

              // Action Buttons untuk Admin/Kordinator
              if (widget.userProfile.canVerify &&
                  widget.observation.statusApproval == 'MENUNGGU_VERIFIKASI')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: grad[1], // Warna aksi match dengan gradient
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _updateStatus('PERLU_DIREVISI'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Revisi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _updateStatus('TERVERIFIKASI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusTerverifikasi,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Setujui',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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

  Widget _buildStatusChip(String status) {
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
