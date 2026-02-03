// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_avatar.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyAvatar _$MyAvatarFromJson(Map<String, dynamic> json) => MyAvatar(
  id: json['id'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  stage:
      $enumDecodeNullable(_$AvatarStageEnumMap, json['stage']) ??
      AvatarStage.anchor,
  baseMannequinId: json['baseMannequinId'] as String,
  bodyMeasurements: BodyMeasurements.fromJson(
    json['bodyMeasurements'] as Map<String, dynamic>,
  ),
  evolvedImagePath: json['evolvedImagePath'] as String?,
  referencePaths: (json['referencePaths'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  evolutionHistory: (json['evolutionHistory'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MyAvatarToJson(MyAvatar instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'stage': _$AvatarStageEnumMap[instance.stage]!,
  'baseMannequinId': instance.baseMannequinId,
  'bodyMeasurements': instance.bodyMeasurements,
  'evolvedImagePath': instance.evolvedImagePath,
  'referencePaths': instance.referencePaths,
  'evolutionHistory': instance.evolutionHistory,
};

const _$AvatarStageEnumMap = {
  AvatarStage.anchor: 'anchor',
  AvatarStage.silhouette: 'silhouette',
  AvatarStage.layered: 'layered',
};
