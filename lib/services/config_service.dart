import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/mannequin_config.dart';
import '../models/score_config.dart';
import '../models/clothing_type_config.dart';

/// 설정 파일 로드 서비스
/// 
/// **헌법 원칙**: 모든 표현 데이터는 JSON으로 관리
class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance {
    _instance ??= ConfigService._();
    return _instance!;
  }

  ConfigService._();

  MannequinsData? _mannequinsData;
  ScoreConfigData? _scoreConfigData;
  ClothingTypesData? _clothingTypesData;
  Map<String, dynamic>? _uiStrings;
  Map<String, dynamic>? _prompts;
  String _currentLocale = 'ko';

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize({String locale = 'ko'}) async {
    _currentLocale = locale;
    await Future.wait([
      _loadMannequins(),
      _loadScoreConfig(),
      _loadClothingTypes(),
      _loadUIStrings(),
      _loadPrompts(),
    ]);
  }

  Future<void> _loadMannequins() async {
    final jsonString =
        await rootBundle.loadString('assets/config/mannequins.json');
    final json = jsonDecode(jsonString);
    _mannequinsData = MannequinsData.fromJson(json);
  }

  Future<void> _loadScoreConfig() async {
    final jsonString =
        await rootBundle.loadString('assets/config/score_config.json');
    final json = jsonDecode(jsonString);
    _scoreConfigData = ScoreConfigData.fromJson(json);
  }

  Future<void> _loadClothingTypes() async {
    final jsonString =
        await rootBundle.loadString('assets/config/clothing_types.json');
    final json = jsonDecode(jsonString);
    _clothingTypesData = ClothingTypesData.fromJson(json);
  }

  Future<void> _loadUIStrings() async {
    final jsonString =
        await rootBundle.loadString('assets/config/ui_strings.json');
    _uiStrings = jsonDecode(jsonString);
  }

  Future<void> _loadPrompts() async {
    final jsonString =
        await rootBundle.loadString('assets/config/prompts.json');
    _prompts = jsonDecode(jsonString);
  }

  /// 마네킹 목록 (순서대로)
  List<MannequinConfig> get mannequins {
    if (_mannequinsData == null) {
      throw StateError('ConfigService not initialized');
    }
    final list = List<MannequinConfig>.from(_mannequinsData!.mannequins);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// ID로 마네킹 찾기
  MannequinConfig? getMannequinById(String id) {
    for (final mannequin in mannequins) {
      if (mannequin.id == id) {
        return mannequin;
      }
    }
    return null;
  }

  /// 점수 항목 목록 (순서대로)
  List<ScoreItemConfig> get scoreItems {
    if (_scoreConfigData == null) {
      throw StateError('ConfigService not initialized');
    }
    final list = List<ScoreItemConfig>.from(_scoreConfigData!.scoreItems);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// 옷 타입 목록 (순서대로)
  List<ClothingTypeConfig> get clothingTypes {
    if (_clothingTypesData == null) {
      throw StateError('ConfigService not initialized');
    }
    final list = List<ClothingTypeConfig>.from(_clothingTypesData!.clothingTypes);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// ID로 옷 타입 찾기
  ClothingTypeConfig? getClothingTypeById(String id) {
    for (final type in clothingTypes) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }

  /// ID로 점수 항목 찾기
  ScoreItemConfig? getScoreItemById(String id) {
    for (final item in scoreItems) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// UI 문자열 가져오기
  String getString(String key, {String? fallback}) {
    if (_uiStrings == null) {
      return fallback ?? key;
    }

    final keys = key.split('.');
    dynamic current = _uiStrings;

    for (final k in keys) {
      if (current is Map && current.containsKey(k)) {
        current = current[k];
      } else {
        return fallback ?? key;
      }
    }

    return current?.toString() ?? fallback ?? key;
  }

  /// 프롬프트 템플릿 가져오기
  String getPrompt(String key, {Map<String, String>? params}) {
    if (_prompts == null) {
      return key;
    }

    final promptMap = _prompts!['prompts'];
    if (promptMap is! Map) {
      return key;
    }

    final rawTemplate = promptMap[key];
    final template = _resolvePromptTemplate(rawTemplate) ?? key;
    if (params == null || params.isEmpty) {
      return template;
    }

    var resolved = template;
    params.forEach((paramKey, value) {
      resolved = resolved.replaceAll('{$paramKey}', value);
    });
    return resolved;
  }

  String? _resolvePromptTemplate(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final lines = value.map((entry) => entry.toString()).toList();
      return lines.join('\n');
    }
    return value.toString();
  }

  /// 현재 로케일
  String get locale => _currentLocale;

  /// 로케일 변경
  Future<void> changeLocale(String locale) async {
    _currentLocale = locale;
    await _loadUIStrings();
  }
}
