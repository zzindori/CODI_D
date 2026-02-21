import 'package:json_annotation/json_annotation.dart';
import 'clothing_analysis.dart';
import 'person_analysis.dart';

part 'clothing_item.g.dart';

/// 워드로브에 저장되는 옷 아이템
/// 
/// 옷의 원본, 추출본, 마네킹에 입혀진 모습, 
/// 그리고 모든 분석 데이터를 함께 보관한다.
@JsonSerializable()
class ClothingItem {
  final String id;
  final String category; // 'hair', 'top', 'bottom', 'shoes', 'accessory'
  final String name;
  final String? dominantColor;
  
  // ✅ 이미지 경로들
  /// 원본 사진 (사용자가 업로드한 사진)
  final String sourceImagePath;
  
  /// 옷만 추출된 투명 배경 PNG
  final String imagePath;
  
  /// 마네킹에 입혀진 썬네일 이미지 (Inpainting 결과)
  final String? imageOnMannequinPath;
  
  // ✅ 분석 데이터 (모두 함께 저장)
  final Map<String, dynamic>? hairAnalysisJson;
  final Map<String, dynamic>? clothingAnalysisJson;
  final Map<String, dynamic>? accessoryAnalysisJson;
  
  // ✅ Inpainting 마스크 정보
  /// 마스크 이미지 파일 경로
  final String? maskImagePath;
  
  /// 마스크 좌표 (left, top, right, bottom)
  final Map<String, double>? maskCoordinates;
  
  // ✅ 메타데이터
  final DateTime createdAt;
  final String? memo;

  ClothingItem({
    required this.id,
    required this.name,
    String? category,
    String? sourceImagePath,
    String? imagePath,
    String? typeId,
    String? originalImagePath,
    String? extractedImagePath,
    this.dominantColor,
    this.imageOnMannequinPath,
    this.hairAnalysisJson,
    this.clothingAnalysisJson,
    this.accessoryAnalysisJson,
    this.maskImagePath,
    this.maskCoordinates,
    DateTime? createdAt,
    this.memo,
  })  : category = category ?? typeId ?? 'top',
        sourceImagePath = sourceImagePath ?? originalImagePath ?? '',
        imagePath = imagePath ?? extractedImagePath ?? originalImagePath ?? '',
        createdAt = createdAt ?? DateTime.now();

  // 레거시 호환 getter
  String get typeId => category;
  String get originalImagePath => sourceImagePath;
  String? get extractedImagePath => imagePath.isEmpty ? null : imagePath;

  /// 분석 객체로 변환 (Getter)
  HairAnalysis? get hairAnalysis =>
      hairAnalysisJson != null ? HairAnalysis.fromJson(hairAnalysisJson!) : null;

  ClothingPartAnalysis? get clothingAnalysis =>
      clothingAnalysisJson != null ? ClothingPartAnalysis.fromJson(clothingAnalysisJson!) : null;

  AccessoryAnalysis? get accessoryAnalysis =>
      accessoryAnalysisJson != null ? AccessoryAnalysis.fromJson(accessoryAnalysisJson!) : null;

  factory ClothingItem.fromJson(Map<String, dynamic> json) =>
      _$ClothingItemFromJson(json);

  Map<String, dynamic> toJson() => _$ClothingItemToJson(this);

  ClothingItem copyWith({
    String? category,
    String? name,
    String? imagePath,
    String? imageOnMannequinPath,
    String? maskImagePath,
    String? dominantColor,
    String? memo,
  }) {
    return ClothingItem(
      id: id,
      category: category ?? this.category,
      name: name ?? this.name,
      sourceImagePath: sourceImagePath,
      imagePath: imagePath ?? this.imagePath,
      dominantColor: dominantColor ?? this.dominantColor,
      imageOnMannequinPath: imageOnMannequinPath ?? this.imageOnMannequinPath,
      hairAnalysisJson: hairAnalysisJson,
      clothingAnalysisJson: clothingAnalysisJson,
      accessoryAnalysisJson: accessoryAnalysisJson,
      maskImagePath: maskImagePath ?? this.maskImagePath,
      maskCoordinates: maskCoordinates,
      createdAt: createdAt,
      memo: memo ?? this.memo,
    );
  }
}
