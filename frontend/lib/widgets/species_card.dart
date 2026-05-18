import 'dart:io';
import 'dart:math' as math;
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
  //  FRONT SIDE — Field Dex Card
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFront() {
    final obs = widget.observation;
    final typeColor = _typeColorFor(obs.kategoriTakson);
    final borderColor = _borderColorFor(obs.kategoriTakson);
    final frameColor = _frameColorFor(obs.kategoriTakson);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Outer border — thick, like Pokémon card's colored rim
        border: Border.all(color: borderColor, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: borderColor.withValues(alpha: 0.20),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Card background with subtle texture
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBF8),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CardTexturePainter(
                color: typeColor.withValues(alpha: 0.035),
              ),
            ),
          ),
          // Inner metallic frame line
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: frameColor, width: 1.0),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── HEADER STRIP ──
              _buildHeader(obs, typeColor, borderColor),
              // ── PHOTO FRAME ──
              Expanded(
                flex: 55,
                child: _buildPhotoFrame(obs, typeColor, borderColor),
              ),
              // ── POKÉDEX INFO STRIP ──
              _buildDexStrip(obs, typeColor),
              // ── FOOTER ──
              Expanded(
                flex: 32,
                child: _buildFooter(obs, typeColor, borderColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Observation obs, Color typeColor, Color borderColor) {
    final jumlah = obs.jumlahIndividu ?? 1;
    final emoji = _emojiFor(obs.kategoriTakson);
    final typeName = obs.kategoriTakson.replaceAll('DK ', '').toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            borderColor,
            typeColor,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Type badge (like BASIC stage in Pokémon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 0.7),
            ),
            child: Text(
              typeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const Spacer(),
          // Individu count (like HP in Pokémon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '×$jumlah',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 3),
                Text(emoji, style: const TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoFrame(
      Observation obs, Color typeColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 5, 6, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // Inner photo border — silver frame
        border: Border.all(
          color: const Color(0xFFB8B8B8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          _photo(obs),

          // Subtle holographic diagonal shimmer overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _HoloPainter(color: typeColor.withValues(alpha: 0.07)),
            ),
          ),

          // Status badge (top-left)
          Positioned(
            top: 6,
            left: 6,
            child: _statusBadge(obs),
          ),

          // Swipe hint (bottom-right)
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swipe_rounded,
                  color: Colors.white70, size: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDexStrip(Observation obs, Color typeColor) {
    final lat = obs.latitude.toStringAsFixed(4);
    final lng = obs.longitude.toStringAsFixed(4);

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: typeColor.withValues(alpha: 0.18), width: 0.7),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop_outlined,
              size: 9, color: typeColor.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            '$lat°  $lng°',
            style: TextStyle(
              fontSize: 8.5,
              fontFamily: 'monospace',
              color: typeColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
      Observation obs, Color typeColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Species name — italic like Pokémon name
          Text(
            obs.namaSpesies,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: Color(0xFF1A1A1A),
              height: 1.15,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (obs.namaLokal != null && obs.namaLokal!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              obs.namaLokal!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: typeColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const Spacer(),

          // Bottom divider line (like the divider before W/R/Retreat in Pokémon)
          Container(
            height: 0.7,
            color: const Color(0xFFB8B8B8).withValues(alpha: 0.6),
          ),
          const SizedBox(height: 4),

          // Time + sync indicator
          Row(
            children: [
              Icon(Icons.access_time_outlined,
                  size: 9, color: const Color(0xFFAAAAAA)),
              const SizedBox(width: 3),
              Text(
                _getTimeAgo(obs.waktuPengamatan),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!obs.isSynced)
                Icon(Icons.cloud_off_rounded,
                    size: 11, color: Colors.orange.shade400)
              else
                Icon(Icons.cloud_done_rounded,
                    size: 11, color: const Color(0xFFBBBBBB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Observation obs) {
    if (!obs.isSynced) {
      return _badge(Icons.edit_note_rounded, 'Draft',
          Colors.orange.shade700, Colors.orange.shade50);
    }
    if (obs.statusApproval == 'TERVERIFIKASI') {
      return _badge(Icons.verified_rounded, 'Verified',
          AppColors.statusTerverifikasi, const Color(0xFFE6FAF3));
    }
    if (obs.statusApproval == 'PERLU_DIREVISI') {
      return _badge(Icons.warning_amber_rounded, 'Revisi',
          AppColors.statusRevisi, const Color(0xFFFFF0F0));
    }
    return _badge(Icons.hourglass_top_rounded, 'Pending',
        AppColors.statusMenunggu, const Color(0xFFFFF8E6));
  }

  Widget _badge(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BACK SIDE — Gradient data card
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBack() {
    final obs = widget.observation;
    final grad = _gradientFor(obs.kategoriTakson);
    final dateStr = DateFormat('dd MMM yyyy').format(obs.waktuPengamatan);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
                  Text(_emojiFor(obs.kategoriTakson),
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
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, p) =>
            p == null ? child : _placeholder(loading: true),
      );
    }
    return _placeholder();
  }

  Widget _placeholder({bool loading = false}) {
    final g = _gradientFor(widget.observation.kategoriTakson);
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
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}h lalu';
    if (duration.inHours > 0) return '${duration.inHours}j lalu';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m lalu';
    return 'Baru saja';
  }

  /// Warna dominan card (untuk gradient back + glow)
  List<Color> _gradientFor(String t) {
    final s = t.toLowerCase();
    if (s.contains('karnivora'))
      return [const Color(0xFFD4451A), const Color(0xFF8B2010)];
    if (s.contains('herbivora'))
      return [const Color(0xFF2E9B5E), const Color(0xFF1A6B3E)];
    if (s.contains('primata'))
      return [const Color(0xFFA0522D), const Color(0xFF6B3418)];
    if (s.contains('burung'))
      return [const Color(0xFF2196F3), const Color(0xFF0D47A1)];
    if (s.contains('reptil') || s.contains('amfibi'))
      return [const Color(0xFF00897B), const Color(0xFF004D40)];
    if (s.contains('insekta'))
      return [const Color(0xFFFF8F00), const Color(0xFFE65100)];
    if (s.contains('fauna perairan'))
      return [const Color(0xFF5C6BC0), const Color(0xFF283593)];
    if (s.contains('eksitu') || s.contains('flora'))
      return [const Color(0xFF7CB342), const Color(0xFF33691E)];
    return [const Color(0xFF609008), const Color(0xFF3D5A05)];
  }

  /// Warna type utama (untuk accent, strip, dll)
  Color _typeColorFor(String t) => _gradientFor(t)[0];

  /// Warna border tebal luar (sedikit lebih gelap)
  Color _borderColorFor(String t) => _gradientFor(t)[1];

  /// Warna frame metalik dalam (lighter, satin)
  Color _frameColorFor(String t) {
    final base = _gradientFor(t)[0];
    return Color.lerp(base, Colors.white, 0.6)!.withValues(alpha: 0.6);
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

// ─── Card texture — subtle diagonal lines ────────────────────────────────────
class _CardTexturePainter extends CustomPainter {
  final Color color;
  _CardTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const spacing = 14.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Holographic shimmer overlay ─────────────────────────────────────────────
class _HoloPainter extends CustomPainter {
  final Color color;
  _HoloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
          color,
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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