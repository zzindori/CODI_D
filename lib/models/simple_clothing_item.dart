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

  /// 사진 파일의 MD5 해시 (중복 검증용)
  final String imageHash;

  /// 아이템 타입 (jacket, shirt, pants, skirt, shoes, accessory, etc)
  final String itemType;

  /// 정규화된 라벨 키 (예: puffer_jacket)
  @JsonKey(defaultValue: '')
  final String labelKey;

  /// 라벨 영어 표기
  @JsonKey(defaultValue: '')
  final String labelEn;

  /// 라벨 한글 표기
  @JsonKey(defaultValue: '')
  final String labelKo;

  /// Gemini에서 분류한 카테고리 (top, bottom, hat, shoes, accessory)
  /// 한 번 저장되면 변경 없음 - 항상 같은 탭에 표시됨
  @JsonKey(defaultValue: 'accessory')
  final String itemCategory;

  /// 간단한 설명 (영어)
  final String description;

  /// 간단한 설명 (한글 - Gemini 직접 번역)
  final String descriptionKo;

  /// 주요 색상 이름
  final String color;

  /// 주요 색상 hex
  final String colorHex;

  /// 재질/소재 (cotton, denim, wool, leather, polyester, etc)
  final String material;

  /// 패턴 (solid, striped, checkered, floral, etc)
  final String pattern;

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
    required this.imageHash,
    required this.itemType,
    this.labelKey = '',
    this.labelEn = '',
    this.labelKo = '',
    this.itemCategory = 'accessory',
    required this.description,
    this.descriptionKo = '',
    required this.color,
    required this.colorHex,
    this.material = '',
    this.pattern = 'Solid',
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
    String? imageHash,
    String? itemType,
    String? labelKey,
    String? labelEn,
    String? labelKo,
    String? itemCategory,
    String? description,
    String? descriptionKo,
    String? color,
    String? colorHex,
    String? material,
    String? pattern,
    String? style,
    List<String>? season,
    List<String>? occasion,
    String? memo,
  }) {
    return SimpleClothingItem(
      id: id,
      photoPath: photoPath ?? this.photoPath,
      imageHash: imageHash ?? this.imageHash,
      itemType: itemType ?? this.itemType,
      labelKey: labelKey ?? this.labelKey,
      labelEn: labelEn ?? this.labelEn,
      labelKo: labelKo ?? this.labelKo,
      itemCategory: itemCategory ?? this.itemCategory,
      description: description ?? this.description,
      descriptionKo: descriptionKo ?? this.descriptionKo,
      color: color ?? this.color,
      colorHex: colorHex ?? this.colorHex,
      material: material ?? this.material,
      pattern: pattern ?? this.pattern,
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
