class AiTaxonomy {
  final String? kingdom;
  final String? phylum;
  final String? className;
  final String? order;
  final String? family;
  final String? genus;

  const AiTaxonomy({
    this.kingdom,
    this.phylum,
    this.className,
    this.order,
    this.family,
    this.genus,
  });

  factory AiTaxonomy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiTaxonomy();
    return AiTaxonomy(
      kingdom: json['kingdom'] as String?,
      phylum: json['phylum'] as String?,
      className: json['class'] as String?,
      order: json['order'] as String?,
      family: json['family'] as String?,
      genus: json['genus'] as String?,
    );
  }

  Map<String, String> toChipMap() {
    final map = <String, String>{};
    if (kingdom != null && kingdom!.isNotEmpty) map['Kingdom'] = kingdom!;
    if (phylum != null && phylum!.isNotEmpty) map['Phylum'] = phylum!;
    if (className != null && className!.isNotEmpty) map['Class'] = className!;
    if (order != null && order!.isNotEmpty) map['Order'] = order!;
    if (family != null && family!.isNotEmpty) map['Family'] = family!;
    if (genus != null && genus!.isNotEmpty) map['Genus'] = genus!;
    return map;
  }

  bool get isEmpty =>
      (kingdom == null || kingdom!.isEmpty) &&
      (phylum == null || phylum!.isEmpty) &&
      (className == null || className!.isEmpty) &&
      (order == null || order!.isEmpty) &&
      (family == null || family!.isEmpty) &&
      (genus == null || genus!.isEmpty);
}

class AiSuggestion {
  final String speciesName;
  final String commonName;
  final double confidence;
  final String category;
  final AiTaxonomy taxonomy;
  final String? habitatHint;
  final String? conservationStatus;
  final int? processingTimeMs;

  const AiSuggestion({
    required this.speciesName,
    required this.commonName,
    required this.confidence,
    required this.category,
    required this.taxonomy,
    this.habitatHint,
    this.conservationStatus,
    this.processingTimeMs,
  });

  factory AiSuggestion.fromJson(Map<String, dynamic> json) {
    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num ? rawConfidence.toDouble() : 0.0;
    return AiSuggestion(
      speciesName: (json['species_name'] as String?)?.trim() ?? '',
      commonName: (json['common_name'] as String?)?.trim() ?? '',
      confidence: confidence.clamp(0.0, 1.0),
      category: (json['category'] as String?)?.trim() ?? 'Fauna',
      taxonomy:
          AiTaxonomy.fromJson(json['taxonomy'] as Map<String, dynamic>?),
      habitatHint: (json['habitat_hint'] as String?)?.trim(),
      conservationStatus:
          (json['conservation_status'] as String?)?.trim(),
      processingTimeMs: json['processing_time_ms'] is num
          ? (json['processing_time_ms'] as num).toInt()
          : null,
    );
  }

  bool get isConfident => confidence >= 0.5;

  String get confidencePercent => '${(confidence * 100).round()}%';

  String get confidenceLabel {
    if (confidence >= 0.85) return 'Sangat Yakin';
    if (confidence >= 0.65) return 'Cukup Yakin';
    if (confidence >= 0.5) return 'Yakin';
    return 'Tidak Yakin';
  }
}
