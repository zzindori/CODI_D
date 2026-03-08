// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_clothing_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleClothingItem _$SimpleClothingItemFromJson(Map<String, dynamic> json) =>
    SimpleClothingItem(
      id: json['id'] as String,
      photoPath: json['photoPath'] as String,
      imageHash: json['imageHash'] as String,
      itemType: json['itemType'] as String,
      labelKey: json['labelKey'] as String? ?? '',
      labelEn: json['labelEn'] as String? ?? '',
      labelKo: json['labelKo'] as String? ?? '',
      itemCategory: json['itemCategory'] as String? ?? 'accessory',
      description: json['description'] as String,
      descriptionKo: json['descriptionKo'] as String? ?? '',
      color: json['color'] as String,
      colorHex: json['colorHex'] as String,
      material: json['material'] as String? ?? '',
      pattern: json['pattern'] as String? ?? 'Solid',
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
      'imageHash': instance.imageHash,
      'itemType': instance.itemType,
      'labelKey': instance.labelKey,
      'labelEn': instance.labelEn,
      'labelKo': instance.labelKo,
      'itemCategory': instance.itemCategory,
      'description': instance.description,
      'descriptionKo': instance.descriptionKo,
      'color': instance.color,
      'colorHex': instance.colorHex,
      'material': instance.material,
      'pattern': instance.pattern,
      'style': instance.style,
      'season': instance.season,
      'occasion': instance.occasion,
      'createdAt': instance.createdAt.toIso8601String(),
      'memo': instance.memo,
    };
