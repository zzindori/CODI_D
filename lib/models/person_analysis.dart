/// 사람의 신체 및 얼굴 특징을 분석한 결과
/// Gemini가 화가처럼 분석한 사람의 모든 세부사항
class PersonAnalysis {
  final FaceAnalysis face;
  final FacialFeaturesAnalysis facialFeatures;
  final HairAnalysis hair;
  final BodyProportionsAnalysis bodyProportions;
  final OverallAppearanceAnalysis overallAppearance;

  PersonAnalysis({
    required this.face,
    required this.facialFeatures,
    required this.hair,
    required this.bodyProportions,
    required this.overallAppearance,
  });

  /// JSON 역직렬화
  factory PersonAnalysis.fromJson(Map<String, dynamic> json) {
    return PersonAnalysis(
      face: FaceAnalysis.fromJson(json['face'] as Map<String, dynamic>? ?? {}),
      facialFeatures: FacialFeaturesAnalysis.fromJson(json['facialFeatures'] as Map<String, dynamic>? ?? {}),
      hair: HairAnalysis.fromJson(json['hair'] as Map<String, dynamic>? ?? {}),
      bodyProportions: BodyProportionsAnalysis.fromJson(json['bodyProportions'] as Map<String, dynamic>? ?? {}),
      overallAppearance: OverallAppearanceAnalysis.fromJson(json['overallAppearance'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'face': face.toJson(),
      'facialFeatures': facialFeatures.toJson(),
      'hair': hair.toJson(),
      'bodyProportions': bodyProportions.toJson(),
      'overallAppearance': overallAppearance.toJson(),
    };
  }
}

/// 얼굴 분석
class FaceAnalysis {
  final String faceShape;
  final String faceShapeDescription;
  final String skinTone;
  final String skinToneDescription;
  final String skinTexture;
  final String skinCondition;

  FaceAnalysis({
    required this.faceShape,
    required this.faceShapeDescription,
    required this.skinTone,
    required this.skinToneDescription,
    required this.skinTexture,
    required this.skinCondition,
  });

  factory FaceAnalysis.fromJson(Map<String, dynamic> json) {
    return FaceAnalysis(
      faceShape: json['faceShape'] as String? ?? '',
      faceShapeDescription: json['faceShapeDescription'] as String? ?? '',
      skinTone: json['skinTone'] as String? ?? '',
      skinToneDescription: json['skinToneDescription'] as String? ?? '',
      skinTexture: json['skinTexture'] as String? ?? '',
      skinCondition: json['skinCondition'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'faceShape': faceShape,
      'faceShapeDescription': faceShapeDescription,
      'skinTone': skinTone,
      'skinToneDescription': skinToneDescription,
      'skinTexture': skinTexture,
      'skinCondition': skinCondition,
    };
  }
}

/// 이목구비 분석 (눈, 코, 입, 눈썹)
class FacialFeaturesAnalysis {
  final EyesAnalysis eyes;
  final NoseAnalysis nose;
  final LipsAnalysis lips;
  final EyebrowsAnalysis eyebrows;

  FacialFeaturesAnalysis({
    required this.eyes,
    required this.nose,
    required this.lips,
    required this.eyebrows,
  });

  factory FacialFeaturesAnalysis.fromJson(Map<String, dynamic> json) {
    return FacialFeaturesAnalysis(
      eyes: EyesAnalysis.fromJson(json['eyes'] as Map<String, dynamic>? ?? {}),
      nose: NoseAnalysis.fromJson(json['nose'] as Map<String, dynamic>? ?? {}),
      lips: LipsAnalysis.fromJson(json['lips'] as Map<String, dynamic>? ?? {}),
      eyebrows: EyebrowsAnalysis.fromJson(json['eyebrows'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eyes': eyes.toJson(),
      'nose': nose.toJson(),
      'lips': lips.toJson(),
      'eyebrows': eyebrows.toJson(),
    };
  }
}

/// 눈 분석
class EyesAnalysis {
  final String shape;
  final String color;
  final String colorHex;
  final String size;
  final String expression;
  final String details;

  EyesAnalysis({
    required this.shape,
    required this.color,
    required this.colorHex,
    required this.size,
    required this.expression,
    required this.details,
  });

  factory EyesAnalysis.fromJson(Map<String, dynamic> json) {
    return EyesAnalysis(
      shape: json['shape'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      size: json['size'] as String? ?? '',
      expression: json['expression'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shape': shape,
      'color': color,
      'colorHex': colorHex,
      'size': size,
      'expression': expression,
      'details': details,
    };
  }
}

/// 코 분석
class NoseAnalysis {
  final String shape;
  final String size;
  final String description;

  NoseAnalysis({
    required this.shape,
    required this.size,
    required this.description,
  });

  factory NoseAnalysis.fromJson(Map<String, dynamic> json) {
    return NoseAnalysis(
      shape: json['shape'] as String? ?? '',
      size: json['size'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shape': shape,
      'size': size,
      'description': description,
    };
  }
}

/// 입 분석
class LipsAnalysis {
  final String shape;
  final String color;
  final String colorHex;
  final String description;

  LipsAnalysis({
    required this.shape,
    required this.color,
    required this.colorHex,
    required this.description,
  });

  factory LipsAnalysis.fromJson(Map<String, dynamic> json) {
    return LipsAnalysis(
      shape: json['shape'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shape': shape,
      'color': color,
      'colorHex': colorHex,
      'description': description,
    };
  }
}

/// 눈썹 분석
class EyebrowsAnalysis {
  final String shape;
  final String color;
  final String colorHex;
  final String thickness;
  final String description;

  EyebrowsAnalysis({
    required this.shape,
    required this.color,
    required this.colorHex,
    required this.thickness,
    required this.description,
  });

  factory EyebrowsAnalysis.fromJson(Map<String, dynamic> json) {
    return EyebrowsAnalysis(
      shape: json['shape'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      thickness: json['thickness'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shape': shape,
      'color': color,
      'colorHex': colorHex,
      'thickness': thickness,
      'description': description,
    };
  }
}

/// 헤어 분석
class HairAnalysis {
  final String style;
  final String color;
  final String colorHex;
  final String length;
  final String texture;
  final String volume;
  final String details;

  HairAnalysis({
    required this.style,
    required this.color,
    required this.colorHex,
    required this.length,
    required this.texture,
    required this.volume,
    required this.details,
  });

  factory HairAnalysis.fromJson(Map<String, dynamic> json) {
    return HairAnalysis(
      style: json['style'] as String? ?? '',
      color: json['color'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '#000000',
      length: json['length'] as String? ?? '',
      texture: json['texture'] as String? ?? '',
      volume: json['volume'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style,
      'color': color,
      'colorHex': colorHex,
      'length': length,
      'texture': texture,
      'volume': volume,
      'details': details,
    };
  }
}

/// 신체 비율 분석
class BodyProportionsAnalysis {
  final String height;
  final String headToBodyRatio;
  final String shoulderWidth;
  final String armLength;
  final String legLength;
  final String torsoLength;
  final String waistPosition;
  final String overallBuild;
  final String description;

  BodyProportionsAnalysis({
    required this.height,
    required this.headToBodyRatio,
    required this.shoulderWidth,
    required this.armLength,
    required this.legLength,
    required this.torsoLength,
    required this.waistPosition,
    required this.overallBuild,
    required this.description,
  });

  factory BodyProportionsAnalysis.fromJson(Map<String, dynamic> json) {
    return BodyProportionsAnalysis(
      height: json['height'] as String? ?? '',
      headToBodyRatio: json['headToBodyRatio'] as String? ?? '',
      shoulderWidth: json['shoulderWidth'] as String? ?? '',
      armLength: json['armLength'] as String? ?? '',
      legLength: json['legLength'] as String? ?? '',
      torsoLength: json['torsoLength'] as String? ?? '',
      waistPosition: json['waistPosition'] as String? ?? '',
      overallBuild: json['overallBuild'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'headToBodyRatio': headToBodyRatio,
      'shoulderWidth': shoulderWidth,
      'armLength': armLength,
      'legLength': legLength,
      'torsoLength': torsoLength,
      'waistPosition': waistPosition,
      'overallBuild': overallBuild,
      'description': description,
    };
  }
}

/// 전체 외모 분석
class OverallAppearanceAnalysis {
  final String age;
  final String presenceAndEnergy;
  final String distinguishingFeatures;
  final String colorPalette;

  OverallAppearanceAnalysis({
    required this.age,
    required this.presenceAndEnergy,
    required this.distinguishingFeatures,
    required this.colorPalette,
  });

  factory OverallAppearanceAnalysis.fromJson(Map<String, dynamic> json) {
    return OverallAppearanceAnalysis(
      age: json['age'] as String? ?? '',
      presenceAndEnergy: json['presenceAndEnergy'] as String? ?? '',
      distinguishingFeatures: json['distinguishingFeatures'] as String? ?? '',
      colorPalette: json['colorPalette'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'presenceAndEnergy': presenceAndEnergy,
      'distinguishingFeatures': distinguishingFeatures,
      'colorPalette': colorPalette,
    };
  }
}
