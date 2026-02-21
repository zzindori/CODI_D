// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClothingItem _$ClothingItemFromJson(Map<String, dynamic> json) => ClothingItem(
  id: json['id'] as String,
  name: json['name'] as String,
  category: json['category'] as String?,
  sourceImagePath: json['sourceImagePath'] as String?,
  imagePath: json['imagePath'] as String?,
  typeId: json['typeId'] as String?,
  originalImagePath: json['originalImagePath'] as String?,
  extractedImagePath: json['extractedImagePath'] as String?,
  dominantColor: json['dominantColor'] as String?,
  imageOnMannequinPath: json['imageOnMannequinPath'] as String?,
  hairAnalysisJson: json['hairAnalysisJson'] as Map<String, dynamic>?,
  clothingAnalysisJson: json['clothingAnalysisJson'] as Map<String, dynamic>?,
  accessoryAnalysisJson: json['accessoryAnalysisJson'] as Map<String, dynamic>?,
  maskImagePath: json['maskImagePath'] as String?,
  maskCoordinates: (json['maskCoordinates'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  memo: json['memo'] as String?,
);

Map<String, dynamic> _$ClothingItemToJson(ClothingItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'name': instance.name,
      'dominantColor': instance.dominantColor,
      'sourceImagePath': instance.sourceImagePath,
      'imagePath': instance.imagePath,
      'imageOnMannequinPath': instance.imageOnMannequinPath,
      'hairAnalysisJson': instance.hairAnalysisJson,
      'clothingAnalysisJson': instance.clothingAnalysisJson,
      'accessoryAnalysisJson': instance.accessoryAnalysisJson,
      'maskImagePath': instance.maskImagePath,
      'maskCoordinates': instance.maskCoordinates,
      'createdAt': instance.createdAt.toIso8601String(),
      'memo': instance.memo,
      'typeId': instance.typeId,
      'originalImagePath': instance.originalImagePath,
      'extractedImagePath': instance.extractedImagePath,
    };
