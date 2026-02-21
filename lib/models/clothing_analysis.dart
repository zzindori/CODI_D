// 의류 분석 결과
// Gemini가 분석한 상의, 하의, 신발, 악세사리

class ClothingAnalysis {
  final ClothingPartAnalysis? top;
  final ClothingPartAnalysis? bottom;
  final ClothingPartAnalysis? shoes;
  final List<AccessoryAnalysis> accessories;

  ClothingAnalysis({
    this.top,
    this.bottom,
    this.shoes,
    this.accessories = const [],
  });

  /// JSON 역직렬화
  factory ClothingAnalysis.fromJson(Map<String, dynamic> json) {
    return ClothingAnalysis(
      top: json['top'] != null && json['top'] is Map<String, dynamic>
          ? ClothingPartAnalysis.fromJson(json['top'] as Map<String, dynamic>)
          : null,
      bottom: json['bottom'] != null && json['bottom'] is Map<String, dynamic>
          ? ClothingPartAnalysis.fromJson(json['bottom'] as Map<String, dynamic>)
          : null,
      shoes: json['shoes'] != null && json['shoes'] is Map<String, dynamic>
          ? ClothingPartAnalysis.fromJson(json['shoes'] as Map<String, dynamic>)
          : null,
      accessories: json['accessories'] is List
          ? (json['accessories'] as List)
              .whereType<Map<String, dynamic>>()
              .map((a) => AccessoryAnalysis.fromJson(a))
              .toList()
          : [],
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'top': top?.toJson(),
      'bottom': bottom?.toJson(),
      'shoes': shoes?.toJson(),
      'accessories': accessories.map((a) => a.toJson()).toList(),
    };
  }

  /// Stability API 프롬프트 생성
  String generateStabilityPrompt() {
    final parts = <String>[];

    if (top != null) {
      parts.add('Top: ${top!.type} (${top!.color}), ${top!.material}, ${top!.fit}');
    }
    if (bottom != null) {
      parts.add('Bottom: ${bottom!.type} (${bottom!.color}), ${bottom!.fit}');
    }
    if (shoes != null) {
      parts.add('Shoes: ${shoes!.type} (${shoes!.color}), ${shoes!.material}');
    }
    if (accessories.isNotEmpty) {
      final accessoryDesc = accessories.map((a) => '${a.type} (${a.color})').join(', ');
      parts.add('Accessories: $accessoryDesc');
    }

    final description = parts.join('. ');
    return '''Fashion illustration showing clothing outfit.
Clothing details: $description.

High quality, professional fashion illustration style, white background, full body view.''';
  }
}

/// 의류 부위 분석 (상의, 하의, 신발)
class ClothingPartAnalysis {
  final String type;
  final String material;
  final String color;
  final String colorHex;
  final String pattern;
  final String fit;
  final String texture;
  final String? sleeves;
  final String? length;
  final String details;
  final String? condition;

  ClothingPartAnalysis({
    required this.type,
    required this.material,
    required this.color,
    required this.colorHex,
    required this.pattern,
    required this.fit,
    required this.texture,
    this.sleeves,
    this.length,
    required this.details,
    this.condition,
  });

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'material': material,
      'color': color,
      'colorHex': colorHex,
      'pattern': pattern,
      'fit': fit,
      'texture': texture,
      'sleeves': sleeves,
      'length': length,
      'details': details,
      'condition': condition,
    };
  }

  /// Stability API 프롬프트 생성 (의류 부위별)
  String generateStabilityPrompt() {
    return '''Fashion illustration of clothing item.
Type: $type
Color: $color
Material: $material
Fit: $fit
Pattern: $pattern
Texture: $texture
Details: $details

Professional fashion design sketch, high quality, white background.''';
  }

  factory ClothingPartAnalysis.fromJson(Map<String, dynamic> json) {
    return ClothingPartAnalysis(
      type: json['type'] as String? ?? '',
      material: json['material'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      pattern: json['pattern'] as String? ?? 'solid',
      fit: json['fit'] as String? ?? '',
      texture: json['texture'] as String? ?? '',
      sleeves: json['sleeves'] as String?,
      length: json['length'] as String?,
      details: json['details'] as String? ?? '',
      condition: json['condition'] as String?,
    );
  }
}

/// 악세사리 분석
class AccessoryAnalysis {
  final String type;
  final String material;
  final String color;
  final String colorHex;
  final String style;
  final String? details;

  AccessoryAnalysis({
    required this.type,
    required this.material,
    required this.color,
    required this.colorHex,
    required this.style,
    this.details,
  });

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'material': material,
      'color': color,
      'colorHex': colorHex,
      'style': style,
      'details': details,
    };
  }

  factory AccessoryAnalysis.fromJson(Map<String, dynamic> json) {
    return AccessoryAnalysis(
      type: json['type'] as String? ?? '',
      material: json['material'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      style: json['style'] as String? ?? '',
      details: json['details'] as String?,
    );
  }
}
