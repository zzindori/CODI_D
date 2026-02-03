import 'package:json_annotation/json_annotation.dart';

part 'clothing_type_config.g.dart';

/// 옷 타입 설정 (JSON에서 로드)
@JsonSerializable()
class ClothingTypeConfig {
  final String id;
  final int order;
  @JsonKey(name: 'display_name')
  final Map<String, String> displayName;
  @JsonKey(name: 'prompt_token')
  final String promptToken;

  ClothingTypeConfig({
    required this.id,
    required this.order,
    required this.displayName,
    required this.promptToken,
  });

  factory ClothingTypeConfig.fromJson(Map<String, dynamic> json) =>
      _$ClothingTypeConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ClothingTypeConfigToJson(this);

  String getDisplayName(String locale) {
    return displayName[locale] ?? displayName['ko'] ?? id;
  }
}

@JsonSerializable()
class ClothingTypesData {
  final String version;
  @JsonKey(name: 'clothing_types')
  final List<ClothingTypeConfig> clothingTypes;

  ClothingTypesData({
    required this.version,
    required this.clothingTypes,
  });

  factory ClothingTypesData.fromJson(Map<String, dynamic> json) =>
      _$ClothingTypesDataFromJson(json);

  Map<String, dynamic> toJson() => _$ClothingTypesDataToJson(this);
}
