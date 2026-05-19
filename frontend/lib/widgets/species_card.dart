import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/observation.dart';
import '../utils/constants.dart';
import '../utils/tcg_style_utils.dart';

class SpeciesCard extends StatefulWidget {
  final Observation observation;
  final VoidCallback onTap;
  const SpeciesCard({super.key, required this.observation, required this.onTap});

  @override
  State<SpeciesCard> createState() => _SpeciesCardState();
}

class _SpeciesCardState extends State<SpeciesCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipCtrl;
  bool _isBack = false;
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
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
    return Listener(
      onPointerDown: (e) => _dragStart = e.position,
      onPointerUp: (e) {
        if (_dragStart != null) {
          final delta = e.position - _dragStart!;
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
  //  FRONT SIDE — TCG Card
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFront() {
    final obs = widget.observation;
    final grad = TcgStyleUtils.getGradientFor(obs.kategoriTakson);

    final lat = obs.latitude.toStringAsFixed(3);
    final lng = obs.longitude.toStringAsFixed(3);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE658), width: 5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            grad[0],
            grad[1],
            grad[1],
            grad[0],
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: grad[1].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Kategori & Status ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge kiri atas (Kategori)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8E8E8), Color(0xFFBDBDBD)],
                  ),
                  border: Border.all(color: const Color(0xFFAAAAAA)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                  ],
                ),
                child: Text(
                  obs.kategoriTakson.replaceAll('DK ', '').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              const SizedBox(width: 6),

              // Nama Spesies (Kanan)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    obs.namaSpesies,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Area gambar ──
          Expanded(
            flex: 55,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBDBDBD), width: 2),
                color: Colors.black,
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  // Gambar utama
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: _photo(obs),
                    ),
                  ),

                  // Silver bar bawah gambar (Info Spasial)
                  Container(
                    height: 14,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD0D0D0), Color(0xFFB0B0B0)],
                      ),
                      border: Border(
                        top: BorderSide(color: Color(0xFFAAAAAA)),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, size: 8, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              'LAT $lat • LNG $lng',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 8,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Area konten bawah (Deskripsi / Serangan) ──
          Expanded(
            flex: 45,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Lokal & Sync Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          obs.namaLokal != null && obs.namaLokal!.isNotEmpty 
                              ? obs.namaLokal! 
                              : 'Spesies Liar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!obs.isSynced)
                        const Icon(Icons.cloud_off_rounded, size: 12, color: Colors.orangeAccent)
                      else
                        const Icon(Icons.cloud_done_rounded, size: 12, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Habitat / Catatan
                  Expanded(
                    child: Text(
                      obs.catatanHabitat != null && obs.catatanHabitat!.isNotEmpty
                          ? obs.catatanHabitat!
                          : 'Ditemukan di habitat alami. Tidak ada catatan tambahan.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Footer (Tanggal & Status)
                  const Divider(color: Colors.white30, height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(obs.waktuPengamatan),
                          style: const TextStyle(color: Colors.white60, fontSize: 9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          obs.statusApproval,
                          style: TextStyle(
                            color: obs.statusApproval == 'TERVERIFIKASI' 
                                ? Colors.greenAccent 
                                : (obs.statusApproval == 'PERLU_DIREVISI' ? Colors.redAccent : Colors.orangeAccent),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BACK SIDE — Gradient data card
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBack() {
    final obs = widget.observation;
    final grad = TcgStyleUtils.getGradientFor(obs.kategoriTakson);
    final dateStr = DateFormat('dd MMM yyyy').format(obs.waktuPengamatan);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [grad[0], grad[1]]),
        boxShadow: [
          BoxShadow(
            color: grad[1].withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPatternPainter(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(TcgStyleUtils.getEmojiFor(obs.kategoriTakson),
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Detail',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.swipe_rounded,
                        color: Colors.white70, size: 12),
                  ),
                ]),
                const SizedBox(height: 8),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _infoRow(Icons.science_rounded, 'Latin',
                            obs.namaSpesies),
                        _infoRow(Icons.label_rounded, 'Lokal',
                            obs.namaLokal ?? '-'),
                        _infoRow(Icons.category_rounded, 'Takson',
                            obs.kategoriTakson),
                        _infoRow(Icons.groups_rounded, 'Individu',
                            '${obs.jumlahIndividu ?? 1} ekor'),
                        _infoRow(Icons.directions_walk_rounded, 'Aktivitas',
                            obs.aktivitasTermati ?? '-'),
                        _infoRow(Icons.calendar_today_rounded, 'Tanggal',
                            dateStr),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child:
              Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
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
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    final url = resolveSupabaseFotoUrl(obs.fotoUrl);
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (_, child, p) =>
            p == null ? child : _placeholder(loading: true),
      );
    }
    return _placeholder();
  }

  Widget _placeholder({bool loading = false}) {
    final g = TcgStyleUtils.getGradientFor(widget.observation.kategoriTakson);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            g[0].withValues(alpha: 0.15),
            g[1].withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: g[1]))
            : Icon(Icons.photo_camera_outlined,
                color: g[1].withValues(alpha: 0.5), size: 32),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HELPERS (Moved to TcgStyleUtils)
  // ═══════════════════════════════════════════════════════════════════════
}

// ─── Dot pattern for card back ───────────────────────────────────────────────
class _DotPatternPainter extends CustomPainter {
  final Color color;
  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 18.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}