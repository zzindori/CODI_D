// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_measurements.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BodyMeasurements _$BodyMeasurementsFromJson(Map<String, dynamic> json) =>
    BodyMeasurements(
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      shoulderWidth: (json['shoulderWidth'] as num?)?.toDouble(),
      chestCircumference: (json['chestCircumference'] as num?)?.toDouble(),
      waistCircumference: (json['waistCircumference'] as num?)?.toDouble(),
      hipCircumference: (json['hipCircumference'] as num?)?.toDouble(),
      measuredAt: json['measuredAt'] == null
          ? null
          : DateTime.parse(json['measuredAt'] as String),
    );

Map<String, dynamic> _$BodyMeasurementsToJson(BodyMeasurements instance) =>
    <String, dynamic>{
      'height': instance.height,
      'weight': instance.weight,
      'shoulderWidth': instance.shoulderWidth,
      'chestCircumference': instance.chestCircumference,
      'waistCircumference': instance.waistCircumference,
      'hipCircumference': instance.hipCircumference,
      'measuredAt': instance.measuredAt.toIso8601String(),
    };
