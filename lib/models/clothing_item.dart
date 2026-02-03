import 'package:json_annotation/json_annotation.dart';

part 'clothing_item.g.dart';

/// 추출된 옷 아이템
@JsonSerializable()
class ClothingItem {
  final String id;
  final String name;
  /// 옷 타입 ID (JSON 기반)
  final String typeId;
  final DateTime createdAt;

  /// 원본 사진 경로
  final String originalImagePath;

  /// 마스크 기반 PNG 추출 경로
  final String? extractedImagePath;

  /// 색상 정보 (간단히)
  final String? dominantColor;

  /// 사용자 메모
  final String? memo;

  ClothingItem({
    required this.id,
    required this.name,
    required this.typeId,
    DateTime? createdAt,
    required this.originalImagePath,
    this.extractedImagePath,
    this.dominantColor,
    this.memo,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClothingItem.fromJson(Map<String, dynamic> json) =>
      _$ClothingItemFromJson(json);

  Map<String, dynamic> toJson() => _$ClothingItemToJson(this);

  ClothingItem copyWith({
    String? name,
    String? extractedImagePath,
    String? dominantColor,
    String? memo,
  }) {
    return ClothingItem(
      id: id,
      name: name ?? this.name,
      typeId: typeId,
      createdAt: createdAt,
      originalImagePath: originalImagePath,
      extractedImagePath: extractedImagePath ?? this.extractedImagePath,
      dominantColor: dominantColor ?? this.dominantColor,
      memo: memo ?? this.memo,
    );
  }
}
