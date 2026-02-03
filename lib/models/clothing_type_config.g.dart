// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_type_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClothingTypeConfig _$ClothingTypeConfigFromJson(Map<String, dynamic> json) =>
    ClothingTypeConfig(
      id: json['id'] as String,
      order: (json['order'] as num).toInt(),
      displayName: Map<String, String>.from(json['display_name'] as Map),
      promptToken: json['prompt_token'] as String,
    );

Map<String, dynamic> _$ClothingTypeConfigToJson(ClothingTypeConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order': instance.order,
      'display_name': instance.displayName,
      'prompt_token': instance.promptToken,
    };

ClothingTypesData _$ClothingTypesDataFromJson(Map<String, dynamic> json) =>
    ClothingTypesData(
      version: json['version'] as String,
      clothingTypes: (json['clothing_types'] as List<dynamic>)
          .map((e) => ClothingTypeConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ClothingTypesDataToJson(ClothingTypesData instance) =>
    <String, dynamic>{
      'version': instance.version,
      'clothing_types': instance.clothingTypes,
    };
