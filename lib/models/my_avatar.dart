import 'package:json_annotation/json_annotation.dart';
import 'body_measurements.dart';
import 'avatar_stage.dart';

part 'my_avatar.g.dart';

/// MyAvatar - 단 하나만 존재하는 사용자의 기준 인체
/// 
/// **헌법적 원칙:**
/// - 항상 1개만 존재
/// - 완전 교체가 아닌 점진적 진화
/// - Stage-0에서는 시각적 변화 없음 (마네킹 선택만)
@JsonSerializable()
class MyAvatar {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 현재 진화 단계
  final AvatarStage stage;

  /// Stage-0: 선택한 고정 마네킹 ID (JSON 기반)
  final String baseMannequinId;

  /// Stage-0: 신체 정보 (수치로만 저장)
  final BodyMeasurements bodyMeasurements;

  /// Stage-1: 진화된 아바타 이미지 경로 (로컬)
  final String? evolvedImagePath;

  /// Stage-1: 진화에 사용된 사진들의 경로
  final List<String> referencePaths;

  /// 진화 히스토리 (변화량 추적용)
  final List<String> evolutionHistory;

  MyAvatar({
    required this.id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.stage = AvatarStage.anchor,
    required this.baseMannequinId,
    required this.bodyMeasurements,
    this.evolvedImagePath,
    List<String>? referencePaths,
    List<String>? evolutionHistory,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        referencePaths = referencePaths ?? [],
        evolutionHistory = evolutionHistory ?? [];

  factory MyAvatar.fromJson(Map<String, dynamic> json) =>
      _$MyAvatarFromJson(json);

  Map<String, dynamic> toJson() => _$MyAvatarToJson(this);

  /// 아바타 복사 (불변성 유지)
  MyAvatar copyWith({
    AvatarStage? stage,
    String? baseMannequinId,
    BodyMeasurements? bodyMeasurements,
    String? evolvedImagePath,
    List<String>? referencePaths,
    List<String>? evolutionHistory,
  }) {
    return MyAvatar(
      id: id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      stage: stage ?? this.stage,
      baseMannequinId: baseMannequinId ?? this.baseMannequinId,
      bodyMeasurements: bodyMeasurements ?? this.bodyMeasurements,
      evolvedImagePath: evolvedImagePath ?? this.evolvedImagePath,
      referencePaths: referencePaths ?? this.referencePaths,
      evolutionHistory: evolutionHistory ?? this.evolutionHistory,
    );
  }

  /// 현재 표시할 이미지 경로
  String get displayImagePath {
    // Stage-1 이상이고 진화된 이미지가 있으면 그것을 사용
    if (stage.level >= AvatarStage.silhouette.level && evolvedImagePath != null) {
      return evolvedImagePath!;
    }
    // 그 외에는 기본 마네킹 (ConfigService에서 조회)
    return baseMannequinId; // 이 값은 UI에서 ConfigService로 변환됨
  }

  /// 진화 가능 여부
  bool get canEvolve {
    return stage == AvatarStage.anchor || stage == AvatarStage.silhouette;
  }
}
