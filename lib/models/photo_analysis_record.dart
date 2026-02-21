class AnalysisItemTag {
  final String category;
  final String label;
  final String description;
  final bool eligibleForCategory;
  final String qualityStatus;

  const AnalysisItemTag({
    required this.category,
    required this.label,
    required this.description,
    this.eligibleForCategory = true,
    this.qualityStatus = 'ok',
  });

  factory AnalysisItemTag.fromJson(Map<String, dynamic> json) {
    return AnalysisItemTag(
      category: (json['category'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      eligibleForCategory: json['eligibleForCategory'] as bool? ?? true,
      qualityStatus: (json['qualityStatus'] ?? 'ok').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'label': label,
      'description': description,
      'eligibleForCategory': eligibleForCategory,
      'qualityStatus': qualityStatus,
    };
  }
}

class PhotoAnalysisRecord {
  final String id;
  final String imagePath;
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
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      personCount: (json['personCount'] as num?)?.toInt() ?? 0,
      selectedPersonId: (json['selectedPersonId'] as num?)?.toInt(),
      brightnessScore: (json['brightnessScore'] as num?)?.toDouble() ?? 0,
      sharpnessScore: (json['sharpnessScore'] as num?)?.toDouble() ?? 0,
        topCoverageScore: (json['topCoverageScore'] as num?)?.toDouble() ?? 0,
        bottomCoverageScore: (json['bottomCoverageScore'] as num?)?.toDouble() ?? 0,
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