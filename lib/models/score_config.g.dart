// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScoreItemConfig _$ScoreItemConfigFromJson(Map<String, dynamic> json) =>
    ScoreItemConfig(
      id: json['id'] as String,
      order: (json['order'] as num).toInt(),
      displayName: Map<String, String>.from(json['display_name'] as Map),
      description: Map<String, String>.from(json['description'] as Map),
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
      weight: (json['weight'] as num).toDouble(),
    );

Map<String, dynamic> _$ScoreItemConfigToJson(ScoreItemConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order': instance.order,
      'display_name': instance.displayName,
      'description': instance.description,
      'min': instance.min,
      'max': instance.max,
      'weight': instance.weight,
    };

ScoreConfigData _$ScoreConfigDataFromJson(Map<String, dynamic> json) =>
    ScoreConfigData(
      version: json['version'] as String,
      scoreItems: (json['score_items'] as List<dynamic>)
          .map((e) => ScoreItemConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ScoreConfigDataToJson(ScoreConfigData instance) =>
    <String, dynamic>{
      'version': instance.version,
      'score_items': instance.scoreItems,
    };
