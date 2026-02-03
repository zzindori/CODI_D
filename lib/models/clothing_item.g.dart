// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClothingItem _$ClothingItemFromJson(Map<String, dynamic> json) => ClothingItem(
  id: json['id'] as String,
  name: json['name'] as String,
  typeId: json['typeId'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  originalImagePath: json['originalImagePath'] as String,
  extractedImagePath: json['extractedImagePath'] as String?,
  dominantColor: json['dominantColor'] as String?,
  memo: json['memo'] as String?,
);

Map<String, dynamic> _$ClothingItemToJson(ClothingItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'typeId': instance.typeId,
      'createdAt': instance.createdAt.toIso8601String(),
      'originalImagePath': instance.originalImagePath,
      'extractedImagePath': instance.extractedImagePath,
      'dominantColor': instance.dominantColor,
      'memo': instance.memo,
    };
