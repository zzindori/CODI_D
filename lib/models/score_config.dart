import 'package:json_annotation/json_annotation.dart';

part 'score_config.g.dart';

/// 점수 항목 설정 (JSON에서 로드)
@JsonSerializable()
class ScoreItemConfig {
  final String id;
  final int order;
  @JsonKey(name: 'display_name')
  final Map<String, String> displayName;
  final Map<String, String> description;
  final int min;
  final int max;
  final double weight;

  ScoreItemConfig({
    required this.id,
    required this.order,
    required this.displayName,
    required this.description,
    required this.min,
    required this.max,
    required this.weight,
  });

  factory ScoreItemConfig.fromJson(Map<String, dynamic> json) =>
      _$ScoreItemConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ScoreItemConfigToJson(this);

  String getDisplayName(String locale) {
    return displayName[locale] ?? displayName['ko'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['ko'] ?? '';
  }
}

/// 점수 설정 파일 전체
@JsonSerializable()
class ScoreConfigData {
  final String version;
  @JsonKey(name: 'score_items')
  final List<ScoreItemConfig> scoreItems;

  ScoreConfigData({
    required this.version,
    required this.scoreItems,
  });

  factory ScoreConfigData.fromJson(Map<String, dynamic> json) =>
      _$ScoreConfigDataFromJson(json);

  Map<String, dynamic> toJson() => _$ScoreConfigDataToJson(this);
}
