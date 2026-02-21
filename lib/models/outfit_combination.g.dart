// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outfit_combination.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OutfitCombination _$OutfitCombinationFromJson(Map<String, dynamic> json) =>
    OutfitCombination(
      id: json['id'] as String,
      name: json['name'] as String,
      itemIds: (json['itemIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      reason: json['reason'] as String?,
      occasion: json['occasion'] as String?,
      generatedImagePath: json['generatedImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      rating: (json['rating'] as num?)?.toInt(),
      memo: json['memo'] as String?,
    );

Map<String, dynamic> _$OutfitCombinationToJson(OutfitCombination instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'itemIds': instance.itemIds,
      'reason': instance.reason,
      'occasion': instance.occasion,
      'generatedImagePath': instance.generatedImagePath,
      'createdAt': instance.createdAt.toIso8601String(),
      'rating': instance.rating,
      'memo': instance.memo,
    };
