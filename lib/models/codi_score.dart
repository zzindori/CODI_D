import 'package:json_annotation/json_annotation.dart';

part 'codi_score.g.dart';

/// 코디 점수 (JSON 기반)
/// 
/// **헌법적 원칙:**
/// 점수 항목은 표현 데이터로 분리되며, 코드는 데이터 해석만 담당
@JsonSerializable()
class CodiScore {
  /// score_id -> value
  final Map<String, int> scores;

  CodiScore({required this.scores});

  factory CodiScore.fromJson(Map<String, dynamic> json) =>
      _$CodiScoreFromJson(json);

  Map<String, dynamic> toJson() => _$CodiScoreToJson(this);

  int? getScore(String id) => scores[id];

  /// 가중치 기반 평균
  double weightedAverage(Map<String, double> weights) {
    double total = 0;
    double weightSum = 0;

    scores.forEach((id, value) {
      final weight = weights[id] ?? 1.0;
      total += value * weight;
      weightSum += weight;
    });

    if (weightSum == 0) return 0;
    return total / weightSum;
  }
}
