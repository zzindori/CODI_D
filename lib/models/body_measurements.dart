import 'package:json_annotation/json_annotation.dart';

part 'body_measurements.g.dart';

/// 신체 정보 (Stage-0에서 수치로만 저장)
@JsonSerializable()
class BodyMeasurements {
  final double height; // cm
  final double weight; // kg
  final double? shoulderWidth; // cm
  final double? chestCircumference; // cm
  final double? waistCircumference; // cm
  final double? hipCircumference; // cm
  final DateTime measuredAt;

  BodyMeasurements({
    required this.height,
    required this.weight,
    this.shoulderWidth,
    this.chestCircumference,
    this.waistCircumference,
    this.hipCircumference,
    DateTime? measuredAt,
  }) : measuredAt = measuredAt ?? DateTime.now();

  factory BodyMeasurements.fromJson(Map<String, dynamic> json) =>
      _$BodyMeasurementsFromJson(json);

  Map<String, dynamic> toJson() => _$BodyMeasurementsToJson(this);

  /// BMI 계산
  double get bmi => weight / ((height / 100) * (height / 100));

  /// 체형 타입 추정 (간단한 규칙 기반)
  String get bodyType {
    // 상세 측정값이 있으면 정밀 계산
    if (shoulderWidth != null && waistCircumference != null && hipCircumference != null && hipCircumference != 0) {
      final shoulderHipRatio = shoulderWidth! / hipCircumference!;
      final waistHipRatio = waistCircumference! / hipCircumference!;

      if (shoulderHipRatio > 1.05) {
        return 'inverted_triangle'; // 역삼각형
      } else if (waistHipRatio < 0.75) {
        return 'hourglass'; // 모래시계
      } else if (waistHipRatio > 0.85) {
        return 'rectangle'; // 직사각형
      } else {
        return 'triangle'; // 삼각형
      }
    }

    // 키/몸무게만 있으면 BMI 기반 체형 설명
    final bmiValue = bmi;
    if (bmiValue < 18.5) {
      return 'slim (BMI: ${bmiValue.toStringAsFixed(1)})';
    } else if (bmiValue < 23) {
      return 'standard (BMI: ${bmiValue.toStringAsFixed(1)})';
    } else if (bmiValue < 25) {
      return 'slightly_heavy (BMI: ${bmiValue.toStringAsFixed(1)})';
    } else {
      return 'heavy (BMI: ${bmiValue.toStringAsFixed(1)})';
    }
  }
}
