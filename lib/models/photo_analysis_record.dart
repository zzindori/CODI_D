class AnalysisItemTag {
  final String category;
  final String label;
  final String labelKey;
  final String labelEn;
  final String labelKo;
  final String description;
  final String? descriptionKo;
  final String? color;
  final String? colorHex;
  final String? material;
  final String? pattern;
  final String? style;
  final List<String>? season;
  final List<String>? occasion;
  final bool eligibleForCategory;
  final String qualityStatus;

  const AnalysisItemTag({
    required this.category,
    required this.label,
    this.labelKey = '',
    this.labelEn = '',
    this.labelKo = '',
    required this.description,
    this.descriptionKo,
    this.color,
    this.colorHex,
    this.material,
    this.pattern,
    this.style,
    this.season,
    this.occasion,
    this.eligibleForCategory = true,
    this.qualityStatus = 'ok',
  });

  factory AnalysisItemTag.fromJson(Map<String, dynamic> json) {
    return AnalysisItemTag(
      category: (json['category'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      labelKey: (json['label_key'] ?? json['labelKey'] ?? '').toString(),
      labelEn: (json['label_en'] ?? json['labelEn'] ?? json['label'] ?? '')
          .toString(),
      labelKo: (json['label_ko'] ?? json['labelKo'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      descriptionKo: json['description_ko']?.toString(),
      color: json['color']?.toString(),
      colorHex: json['colorHex']?.toString(),
      material: json['material']?.toString(),
      pattern: json['pattern']?.toString(),
      style: json['style']?.toString(),
      season: (json['season'] as List?)?.map((e) => e.toString()).toList(),
      occasion: (json['occasion'] as List?)?.map((e) => e.toString()).toList(),
      eligibleForCategory: json['eligibleForCategory'] as bool? ?? true,
      qualityStatus: (json['qualityStatus'] ?? 'ok').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'label': label,
      'label_key': labelKey,
      'label_en': labelEn,
      'label_ko': labelKo,
      'description': description,
      'description_ko': descriptionKo,
      'color': color,
      'colorHex': colorHex,
      'material': material,
      'pattern': pattern,
      'style': style,
      'season': season,
      'occasion': occasion,
      'eligibleForCategory': eligibleForCategory,
      'qualityStatus': qualityStatus,
    };
  }
}

class PhotoAnalysisRecord {
  final String id;
  final String imagePath;
  final String generatedImagePath;
  final List<String> croppedImagePaths;
  final List<int> selectedCellIndexes;
  final List<Map<String, double>> selectedRegions;
  final DateTime createdAt;
  final int personCount;
  final int? selectedPersonId;
  final double brightnessScore;
  final double sharpnessScore;
  final double topCoverageScore;
  final double bottomCoverageScore;
  final List<AnalysisItemTag> items;
  final String summary;

  const PhotoAnalysisRecord({
    required this.id,
    required this.imagePath,
    this.generatedImagePath = '',
    this.croppedImagePaths = const [],
    this.selectedCellIndexes = const [],
    this.selectedRegions = const [],
    required this.createdAt,
    required this.personCount,
    this.selectedPersonId,
    required this.brightnessScore,
    required this.sharpnessScore,
    required this.topCoverageScore,
    required this.bottomCoverageScore,
    required this.items,
    required this.summary,
  });

  factory PhotoAnalysisRecord.fromJson(Map<String, dynamic> json) {
    return PhotoAnalysisRecord(
      id: (json['id'] ?? '').toString(),
      imagePath: (json['imagePath'] ?? '').toString(),
      generatedImagePath: (json['generatedImagePath'] ?? '').toString(),
      croppedImagePaths:
          (json['croppedImagePaths'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .where((path) => path.trim().isNotEmpty)
              .toList(),
      selectedCellIndexes:
          (json['selectedCellIndexes'] as List<dynamic>? ?? const [])
              .map((e) => (e as num?)?.toInt())
              .whereType<int>()
              .toList(),
      selectedRegions: (json['selectedRegions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final x = (raw['x'] as num?)?.toDouble() ?? 0;
            final y = (raw['y'] as num?)?.toDouble() ?? 0;
            final width = (raw['width'] as num?)?.toDouble() ?? 0;
            final height = (raw['height'] as num?)?.toDouble() ?? 0;
            return <String, double>{
              'x': x,
              'y': y,
              'width': width,
              'height': height,
            };
          })
          .toList(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      personCount: (json['personCount'] as num?)?.toInt() ?? 0,
      selectedPersonId: (json['selectedPersonId'] as num?)?.toInt(),
      brightnessScore: (json['brightnessScore'] as num?)?.toDouble() ?? 0,
      sharpnessScore: (json['sharpnessScore'] as num?)?.toDouble() ?? 0,
      topCoverageScore: (json['topCoverageScore'] as num?)?.toDouble() ?? 0,
      bottomCoverageScore:
          (json['bottomCoverageScore'] as num?)?.toDouble() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnalysisItemTag.fromJson)
          .toList(),
      summary: (json['summary'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'generatedImagePath': generatedImagePath,
      'croppedImagePaths': croppedImagePaths,
      'selectedCellIndexes': selectedCellIndexes,
      'selectedRegions': selectedRegions,
      'createdAt': createdAt.toIso8601String(),
      'personCount': personCount,
      'selectedPersonId': selectedPersonId,
      'brightnessScore': brightnessScore,
      'sharpnessScore': sharpnessScore,
      'topCoverageScore': topCoverageScore,
      'bottomCoverageScore': bottomCoverageScore,
      'items': items.map((item) => item.toJson()).toList(),
      'summary': summary,
    };
  }
}
