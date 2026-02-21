/// 아바타 구성 부위 (시스템 내부용)
/// 
/// 얼굴과 체형은 마네킹 베이스 생성용으로만 사용되며
/// 사용자에게 노출되지 않는다.
class AvatarParts {
  // === 시스템 내부용 (비노출) ===
  final String? faceImagePath;      // 얼굴 이미지 (마네킹 베이스 생성용)
  final String? bodyImagePath;      // 체형 이미지 (마네킹 맞춤용)
  
  // === 워드로브 (사용자 노출) ===
  final String? hairImagePath;
  final String? topImagePath;
  final String? bottomImagePath;
  final String? shoesImagePath;
  final List<String> accessoryImagePaths;
  
  AvatarParts({
    this.faceImagePath,
    this.bodyImagePath,
    this.hairImagePath,
    this.topImagePath,
    this.bottomImagePath,
    this.shoesImagePath,
    this.accessoryImagePaths = const [],
  });

  /// 모든 부위가 추출됐는지 확인
  bool get isComplete {
    return faceImagePath != null &&
        bodyImagePath != null &&
        hairImagePath != null &&
        topImagePath != null &&
        bottomImagePath != null &&
        shoesImagePath != null;
  }

  /// 깊은 복사
  AvatarParts copyWith({
    String? faceImagePath,
    String? bodyImagePath,
    String? hairImagePath,
    String? topImagePath,
    String? bottomImagePath,
    String? shoesImagePath,
    List<String>? accessoryImagePaths,
  }) {
    return AvatarParts(
      faceImagePath: faceImagePath ?? this.faceImagePath,
      bodyImagePath: bodyImagePath ?? this.bodyImagePath,
      hairImagePath: hairImagePath ?? this.hairImagePath,
      topImagePath: topImagePath ?? this.topImagePath,
      bottomImagePath: bottomImagePath ?? this.bottomImagePath,
      shoesImagePath: shoesImagePath ?? this.shoesImagePath,
      accessoryImagePaths: accessoryImagePaths ?? this.accessoryImagePaths,
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'faceImagePath': faceImagePath,
      'bodyImagePath': bodyImagePath,
      'hairImagePath': hairImagePath,
      'topImagePath': topImagePath,
      'bottomImagePath': bottomImagePath,
      'shoesImagePath': shoesImagePath,
      'accessoryImagePaths': accessoryImagePaths,
    };
  }

  /// JSON 역직렬화
  factory AvatarParts.fromJson(Map<String, dynamic> json) {
    return AvatarParts(
      faceImagePath: json['faceImagePath'] as String?,
      bodyImagePath: json['bodyImagePath'] as String?,
      hairImagePath: json['hairImagePath'] as String?,
      topImagePath: json['topImagePath'] as String?,
      bottomImagePath: json['bottomImagePath'] as String?,
      shoesImagePath: json['shoesImagePath'] as String?,
      accessoryImagePaths:
          List<String>.from(json['accessoryImagePaths'] as List? ?? []),
    );
  }
}
