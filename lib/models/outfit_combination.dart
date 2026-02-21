import 'package:json_annotation/json_annotation.dart';

part 'outfit_combination.g.dart';

/// 코디 조합 (v3.0)
/// 
/// 여러 옷 아이템을 조합하여 하나의 코디를 만듦
@JsonSerializable()
class OutfitCombination {
  /// 고유 ID
  final String id;

  /// 조합 이름 (예: "Business Casual")
  final String name;

  /// 조합된 아이템 ID 리스트
  final List<String> itemIds;

  /// 이 조합을 선택한 이유/설명
  final String? reason;

  /// 적합한 상황
  final String? occasion;

  /// 생성된 코디 이미지 경로 (Stability AI 생성 결과)
  final String? generatedImagePath;

  /// 생성 시각
  final DateTime createdAt;

  /// 사용자 평가 (1-5)
  final int? rating;

  /// 사용자 메모
  final String? memo;

  const OutfitCombination({
    required this.id,
    required this.name,
    required this.itemIds,
    this.reason,
    this.occasion,
    this.generatedImagePath,
    required this.createdAt,
    this.rating,
    this.memo,
  });

  factory OutfitCombination.fromJson(Map<String, dynamic> json) =>
      _$OutfitCombinationFromJson(json);

  Map<String, dynamic> toJson() => _$OutfitCombinationToJson(this);

  OutfitCombination copyWith({
    String? name,
    List<String>? itemIds,
    String? reason,
    String? occasion,
    String? generatedImagePath,
    int? rating,
    String? memo,
  }) {
    return OutfitCombination(
      id: id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      reason: reason ?? this.reason,
      occasion: occasion ?? this.occasion,
      generatedImagePath: generatedImagePath ?? this.generatedImagePath,
      createdAt: createdAt,
      rating: rating ?? this.rating,
      memo: memo ?? this.memo,
    );
  }
}
