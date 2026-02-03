// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mannequin_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MannequinConfig _$MannequinConfigFromJson(Map<String, dynamic> json) =>
    MannequinConfig(
      id: json['id'] as String,
      gender: json['gender'] as String,
      bodyType: json['body_type'] as String,
      assetPath: json['asset_path'] as String,
      displayName: Map<String, String>.from(json['display_name'] as Map),
      description: Map<String, String>.from(json['description'] as Map),
      order: (json['order'] as num).toInt(),
    );

Map<String, dynamic> _$MannequinConfigToJson(MannequinConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gender': instance.gender,
      'body_type': instance.bodyType,
      'asset_path': instance.assetPath,
      'display_name': instance.displayName,
      'description': instance.description,
      'order': instance.order,
    };

MannequinsData _$MannequinsDataFromJson(Map<String, dynamic> json) =>
    MannequinsData(
      version: json['version'] as String,
      mannequins: (json['mannequins'] as List<dynamic>)
          .map((e) => MannequinConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MannequinsDataToJson(MannequinsData instance) =>
    <String, dynamic>{
      'version': instance.version,
      'mannequins': instance.mannequins,
    };
