import 'dart:io';
import 'package:json_annotation/json_annotation.dart';

part 'simple_clothing_item.g.dart';

/// 간소화된 옷 아이템 (v3.0)
/// 
/// 원칙:
/// - 원본 사진만 저장 (크롭/마스크 없음)
/// - Gemini 분석 결과를 최소 메타데이터로 저장
/// - Stability AI 코디 생성 시 사용
@JsonSerializable()
class SimpleClothingItem {
  /// 고유 ID
  final String id;

  /// 원본 사진 경로 (크롭하지 않음)
  final String photoPath;

  /// 아이템 타입 (jacket, shirt, pants, skirt, shoes, accessory, etc)
  final String itemType;

  /// 간단한 설명 (20단어 이내)
  final String description;

  /// 주요 색상 이름
  final String color;

  /// 주요 색상 hex
  final String colorHex;

  /// 스타일 (casual, formal, sporty, vintage, etc)
  final String style;

  /// 계절
  final List<String> season;

  /// 어울리는 상황
  final List<String> occasion;

  /// 생성 시각
  final DateTime createdAt;

  /// 사용자 메모 (선택)
  final String? memo;

  const SimpleClothingItem({
    required this.id,
    required this.photoPath,
    required this.itemType,
    required this.description,
    required this.color,
    required this.colorHex,
    required this.style,
    required this.season,
    required this.occasion,
    required this.createdAt,
    this.memo,
  });

  factory SimpleClothingItem.fromJson(Map<String, dynamic> json) =>
      _$SimpleClothingItemFromJson(json);

  Map<String, dynamic> toJson() => _$SimpleClothingItemToJson(this);

  SimpleClothingItem copyWith({
    String? photoPath,
    String? itemType,
    String? description,
    String? color,
    String? colorHex,
    String? style,
    List<String>? season,
    List<String>? occasion,
    String? memo,
  }) {
    return SimpleClothingItem(
      id: id,
      photoPath: photoPath ?? this.photoPath,
      itemType: itemType ?? this.itemType,
      description: description ?? this.description,
      color: color ?? this.color,
      colorHex: colorHex ?? this.colorHex,
      style: style ?? this.style,
      season: season ?? this.season,
      occasion: occasion ?? this.occasion,
      createdAt: createdAt,
      memo: memo ?? this.memo,
    );
  }

  /// 파일 객체 반환 (편의 메서드)
  File get photoFile => File(photoPath);
}
