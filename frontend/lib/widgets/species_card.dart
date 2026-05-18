import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/observation.dart';
import '../utils/constants.dart';

class SpeciesCard extends StatefulWidget {
  final Observation observation;
  final VoidCallback onTap;
  const SpeciesCard({super.key, required this.observation, required this.onTap});

  @override
  State<SpeciesCard> createState() => _SpeciesCardState();
}

class _SpeciesCardState extends State<SpeciesCard> with SingleTickerProviderStateMixin {
  late AnimationController _flipCtrl;
  bool _isBack = false;
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flipCtrl.addListener(() {
      final back = _flipCtrl.value >= 0.5;
      if (back != _isBack) setState(() => _isBack = back);
    });
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener doesn't participate in gesture arena → scroll tetap jalan
    return Listener(
      onPointerDown: (e) => _dragStart = e.position,
      onPointerUp: (e) {
        if (_dragStart != null) {
          final delta = e.position - _dragStart!;
          // Hanya flip jika geser horizontal > 30px dan lebih besar dari vertikal
          if (delta.dx.abs() > 30 && delta.dx.abs() > delta.dy.abs() * 1.5) {
            _flip();
          }
          _dragStart = null;
        }
      },
      child: GestureDetector(
        onTap: _isBack ? _flip : widget.onTap,
        onLongPress: widget.onTap,
        child: AnimatedBuilder(
          animation: _flipCtrl,
          builder: (context, _) {
            final v = _flipCtrl.value;
            final scaleX = v <= 0.5 ? 1.0 - 2.0 * v : 2.0 * v - 1.0;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scale(scaleX, 1.0, 1.0),
              child: _isBack ? _buildBack() : _buildFront(),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FRONT SIDE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFront() {
    final obs = widget.observation;
    final grad = _gradientFor(obs.kategoriTakson);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: grad[1].withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        // Foto
        _photo(obs),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, 
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35), 
                Colors.transparent, 
                grad[0].withValues(alpha: 0.8), 
                grad[1].withValues(alpha: 0.95)
              ],
              stops: const [0.0, 0.4, 0.65, 1.0],
            ),
          ),
        ),

        // Emoji badge (glassy)
        Positioned(
          top: 10, right: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
            ),
            child: Text(_emojiFor(obs.kategoriTakson), style: const TextStyle(fontSize: 18)),
          ),
        ),

        // Status chip
        Positioned(top: 10, left: 10, child: _statusChip(obs)),

        // Bottom Content
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (obs.namaLokal != null && obs.namaLokal!.isNotEmpty) ...[
                        Text(
                          obs.namaLokal!, 
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.3, height: 1.2), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 4),
                        Text(
                          obs.namaSpesies,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis
                        ),
                      ] else ...[
                        Text(
                          obs.namaSpesies,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, letterSpacing: 0.3, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(height: 1.5, width: 30, color: Colors.white.withValues(alpha: 0.4), margin: const EdgeInsets.only(bottom: 8)),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: Colors.white.withValues(alpha: 0.9), size: 12),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(obs.waktuPengamatan),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Swipe hint icon
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15), 
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BACK SIDE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBack() {
    final obs = widget.observation;
    final grad = _gradientFor(obs.kategoriTakson);
    final dateStr = DateFormat('dd MMM yyyy').format(obs.waktuPengamatan);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [grad[0], grad[1]]),
        boxShadow: [BoxShadow(color: grad[1].withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Subtle pattern
        Positioned.fill(
          child: CustomPaint(painter: _DotPatternPainter(color: Colors.white.withValues(alpha: 0.06))),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Text(_emojiFor(obs.kategoriTakson), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Detail', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 14),
                ),
              ]),
              const SizedBox(height: 8),
              Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 8),

              // Info rows
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _infoRow(Icons.science_rounded, 'Latin', obs.namaSpesies),
                      _infoRow(Icons.label_rounded, 'Lokal', obs.namaLokal ?? '-'),
                      _infoRow(Icons.category_rounded, 'Takson', obs.kategoriTakson),
                      _infoRow(Icons.groups_rounded, 'Individu', '${obs.jumlahIndividu ?? 1} ekor'),
                      _infoRow(Icons.directions_walk_rounded, 'Aktivitas', obs.aktivitasTermati ?? '-'),
                      _infoRow(Icons.calendar_today_rounded, 'Tanggal', dateStr),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statusChip(Observation obs) {
    if (!obs.isSynced) return _chip(Icons.cloud_off_rounded, 'Draft', Colors.orange.shade700, Colors.orange.shade50);
    if (obs.statusApproval == 'TERVERIFIKASI') return _chip(Icons.verified_rounded, 'Verified', AppColors.statusTerverifikasi, Colors.green.shade50);
    if (obs.statusApproval == 'MENUNGGU_VERIFIKASI') return _chip(Icons.hourglass_top_rounded, 'Menunggu', AppColors.statusMenunggu, Colors.amber.shade50);
    return const SizedBox.shrink();
  }

  Widget _chip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.95), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1)
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PHOTO
  // ═══════════════════════════════════════════════════════════════════════
  Widget _photo(Observation obs) {
    final localPath = obs.localFotoPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    final url = resolveSupabaseFotoUrl(obs.fotoUrl);
    if (url != null) {
      return Image.network(url, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, p) => p == null ? child : _placeholder(loading: true));
    }
    return _placeholder();
  }

  Widget _placeholder({bool loading = false}) {
    final g = _gradientFor(widget.observation.kategoriTakson);
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g[0].withValues(alpha: 0.15), g[1].withValues(alpha: 0.25)])),
      child: Center(child: loading
        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: g[1]))
        : Icon(Icons.photo_camera_outlined, color: g[1].withValues(alpha: 0.5), size: 36)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  List<Color> _gradientFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora')) return [const Color(0xFFD4451A), const Color(0xFF8B2010)]; // Merah-oranye
    if (s.contains('herbivora')) return [const Color(0xFF2E9B5E), const Color(0xFF1A6B3E)]; // Hijau emerald
    if (s.contains('primata')) return [const Color(0xFFA0522D), const Color(0xFF6B3418)]; // Coklat sienna
    if (s.contains('burung')) return [const Color(0xFF2196F3), const Color(0xFF0D47A1)]; // Biru langit
    if (s.contains('reptil') || s.contains('amfibi')) return [const Color(0xFF00897B), const Color(0xFF004D40)]; // Teal
    if (s.contains('insekta')) return [const Color(0xFFFF8F00), const Color(0xFFE65100)]; // Amber-oranye
    if (s.contains('fauna perairan')) return [const Color(0xFF5C6BC0), const Color(0xFF283593)]; // Indigo
    if (s.contains('eksitu') || s.contains('flora')) return [const Color(0xFF7CB342), const Color(0xFF33691E)]; // Lime green
    return [const Color(0xFF609008), const Color(0xFF3D5A05)];
  }

  String _emojiFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora')) return '🐅';
    if (s.contains('herbivora')) return '🐘';
    if (s.contains('primata')) return '🐒';
    if (s.contains('burung')) return '🦅';
    if (s.contains('reptil') || s.contains('amfibi')) return '🦎';
    if (s.contains('insekta')) return '🦋';
    if (s.contains('fauna perairan')) return '🐟';
    if (s.contains('eksitu') || s.contains('flora')) return '🌿';
    return '🔍';
  }
}

// ─── Dot pattern painter for card back ──────────────────────────────────────
class _DotPatternPainter extends CustomPainter {
  final Color color;
  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}