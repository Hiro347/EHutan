// lib/widgets/species_card.dart
// Kartu observasi bergaya Pokémon GO untuk layar Koleksi.
// Sengaja dibuat terpisah dari observation_card.dart (milik task lain).

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/observation.dart';
import '../utils/constants.dart';

class SpeciesCard extends StatelessWidget {
  final Observation observation;
  final VoidCallback onTap;

  const SpeciesCard({
    super.key,
    required this.observation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _taxonColor(observation.kategoriTakson);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha:0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Foto background ──────────────────────────────────────────
            Positioned.fill(
              child: _buildPhoto(observation),
            ),

            // ── Gradient overlay bawah ───────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      color.withValues(alpha:0.55),
                      color.withValues(alpha:0.92),
                    ],
                    stops: const [0.0, 0.4, 0.72, 1.0],
                  ),
                ),
              ),
            ),

            // ── Badge takson (pojok kanan atas) ──────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: _TaxonBadge(
                label: _taxonEmoji(observation.kategoriTakson),
                color: color,
              ),
            ),

            // ── Status draft (jika belum sync) ───────────────────────────
            if (!observation.isSynced)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 10, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Draft',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Info di bagian bawah kartu ───────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nama ilmiah (gaya nama Pokémon — bold, italic)
                    Text(
                      observation.namaSpesies,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.2,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Nama lokal (gaya CP di Pokémon GO — badge kuning kecil)
                    if (observation.namaLokal != null &&
                        observation.namaLokal!.isNotEmpty)
                      _LocalNameBadge(label: observation.namaLokal!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(Observation obs) {
    // 1. Cek foto lokal (belum sync)
    final localPath = obs.localFotoPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    // 2. Resolve fotoUrl ke URL lengkap (handle storage path)
    final resolvedUrl = resolveSupabaseFotoUrl(obs.fotoUrl);
    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _placeholder(loading: true);
        },
      );
    }

    return _placeholder();
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(Icons.image_not_supported_outlined,
                color: Colors.grey.shade400, size: 32),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Color _taxonColor(String takson) {
    switch (takson.toLowerCase()) {
      case 'mamalia':
        return const Color(0xFF8D6E4A);
      case 'aves':
      case 'burung':
        return const Color(0xFF1E88B4);
      case 'reptilia':
        return const Color(0xFF3E8A48);
      case 'insecta':
      case 'serangga':
        return const Color(0xFFB8860B);
      case 'amphibia':
        return const Color(0xFF2E9688);
      case 'pisces':
      case 'ikan':
        return const Color(0xFF1565C0);
      case 'flora':
      case 'tumbuhan':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  String _taxonEmoji(String takson) {
    switch (takson.toLowerCase()) {
      case 'mamalia':
        return '🦊';
      case 'aves':
      case 'burung':
        return '🦜';
      case 'reptilia':
        return '🦎';
      case 'insecta':
      case 'serangga':
        return '🦋';
      case 'amphibia':
        return '🐸';
      case 'pisces':
      case 'ikan':
        return '🐟';
      case 'flora':
      case 'tumbuhan':
        return '🌿';
      default:
        return '🔍';
    }
  }
}

// ─── Sub-widget: Badge takson ────────────────────────────────────────────────
class _TaxonBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TaxonBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha:0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

// ─── Sub-widget: Badge nama lokal (gaya CP Pokémon GO) ──────────────────────
class _LocalNameBadge extends StatelessWidget {
  final String label;

  const _LocalNameBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD740),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A1200),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}