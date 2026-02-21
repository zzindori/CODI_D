// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_clothing_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleClothingItem _$SimpleClothingItemFromJson(Map<String, dynamic> json) =>
    SimpleClothingItem(
      id: json['id'] as String,
      photoPath: json['photoPath'] as String,
      itemType: json['itemType'] as String,
      description: json['description'] as String,
      color: json['color'] as String,
      colorHex: json['colorHex'] as String,
      style: json['style'] as String,
      season: (json['season'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      occasion: (json['occasion'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      memo: json['memo'] as String?,
    );

Map<String, dynamic> _$SimpleClothingItemToJson(SimpleClothingItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'photoPath': instance.photoPath,
      'itemType': instance.itemType,
      'description': instance.description,
      'color': instance.color,
      'colorHex': instance.colorHex,
      'style': instance.style,
      'season': instance.season,
      'occasion': instance.occasion,
      'createdAt': instance.createdAt.toIso8601String(),
      'memo': instance.memo,
    };
