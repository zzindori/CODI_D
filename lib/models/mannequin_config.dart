import 'package:json_annotation/json_annotation.dart';

part 'mannequin_config.g.dart';

/// 마네킹 설정 데이터 (JSON에서 로드)
@JsonSerializable()
class MannequinConfig {
  final String id;
  final String gender;
  @JsonKey(name: 'body_type')
  final String bodyType;
  @JsonKey(name: 'asset_path')
  final String assetPath;
  @JsonKey(name: 'display_name')
  final Map<String, String> displayName;
  final Map<String, String> description;
  final int order;

  MannequinConfig({
    required this.id,
    required this.gender,
    required this.bodyType,
    required this.assetPath,
    required this.displayName,
    required this.description,
    required this.order,
  });

  factory MannequinConfig.fromJson(Map<String, dynamic> json) =>
      _$MannequinConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MannequinConfigToJson(this);

  /// 현재 로케일에 맞는 표시 이름
  String getDisplayName(String locale) {
    return displayName[locale] ?? displayName['ko'] ?? id;
  }

  /// 현재 로케일에 맞는 설명
  String getDescription(String locale) {
    return description[locale] ?? description['ko'] ?? '';
  }
}

/// 마네킹 설정 파일 전체
@JsonSerializable()
class MannequinsData {
  final String version;
  final List<MannequinConfig> mannequins;

  MannequinsData({
    required this.version,
    required this.mannequins,
  });

  factory MannequinsData.fromJson(Map<String, dynamic> json) =>
      _$MannequinsDataFromJson(json);

  Map<String, dynamic> toJson() => _$MannequinsDataToJson(this);
}
