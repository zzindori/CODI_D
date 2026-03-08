// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codi_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodiRecord _$CodiRecordFromJson(Map<String, dynamic> json) => CodiRecord(
  id: json['id'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  topId: json['topId'] as String,
  outerwearId: json['outerwearId'] as String?,
  bottomId: json['bottomId'] as String,
  composedImagePath: json['composedImagePath'] as String,
  score: CodiScore.fromJson(json['score'] as Map<String, dynamic>),
  memo: json['memo'] as String?,
  worn: json['worn'] as bool? ?? false,
  wornDate: json['wornDate'] == null
      ? null
      : DateTime.parse(json['wornDate'] as String),
);

Map<String, dynamic> _$CodiRecordToJson(CodiRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'topId': instance.topId,
      'outerwearId': instance.outerwearId,
      'bottomId': instance.bottomId,
      'composedImagePath': instance.composedImagePath,
      'score': instance.score,
      'memo': instance.memo,
      'worn': instance.worn,
      'wornDate': instance.wornDate?.toIso8601String(),
    };
