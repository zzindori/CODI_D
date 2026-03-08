import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 패션 용어를 "English (한글발음)" 형식으로 표시해주는 서비스
/// 예: "Denim Jacket (데님 자켓)"
class ClothingTermService {
  static final instance = ClothingTermService._();
  ClothingTermService._();

  late Map<String, Map<String, dynamic>> _terms;
  late List<dynamic> _clothingTypesList;
  late Map<String, dynamic> _clothingTypeTerms;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _terms = {};
      _clothingTypesList = <dynamic>[];
      _clothingTypeTerms = <String, dynamic>{};

      final typesJson = await rootBundle.loadString(
        'assets/config/clothing_types.json',
      );
      final typesDecoded = jsonDecode(typesJson) as Map<String, dynamic>;

      // clothing_types 배열 저장
      if (typesDecoded['clothing_types'] is List) {
        _clothingTypesList = typesDecoded['clothing_types'] as List<dynamic>;
      }

      if (typesDecoded['clothing_terms'] is Map) {
        _terms['clothing_terms'] = Map<String, dynamic>.from(
          typesDecoded['clothing_terms'] as Map<String, dynamic>,
        );
      }

      final termsJson = await rootBundle.loadString(
        'assets/config/clothing_terms.json',
      );
      final termsDecoded = jsonDecode(termsJson) as Map<String, dynamic>;

      if (termsDecoded['clothing_types'] is Map) {
        final mappedTypes = Map<String, dynamic>.from(
          termsDecoded['clothing_types'] as Map,
        );
        _terms['clothing_types'] = mappedTypes;
        _clothingTypeTerms = mappedTypes;
      }

      if (termsDecoded['clothing_terms'] is Map) {
        _terms['clothing_terms'] = Map<String, dynamic>.from(
          termsDecoded['clothing_terms'] as Map,
        );
      }

      _initialized = true;
      debugPrint('[ClothingTermService] ✅ 초기화 완료');
    } catch (e) {
      debugPrint('[ClothingTermService] ❌ 초기화 실패: $e');
      _initialized = true; // 실패해도 진행
    }
  }

  /// 카테고리 ID로 표시명 가져오기
  /// 예: "top" → "Top (상의)" 또는 "Top"
  String? getCategoryDisplay(String categoryId) {
    if (!_initialized) {
      debugPrint('[ClothingTermService] ⚠️ 아직 초기화되지 않음');
      return null;
    }

    try {
      for (final item in _clothingTypesList) {
        if (item is Map && item['id'] == categoryId) {
          final displayName = item['display_name'] as Map?;
          if (displayName != null) {
            final en = displayName['en'] as String?;
            final ko = displayName['ko'] as String?;
            if (en != null && ko != null) {
              return '$en ($ko)';
            }
            return en ?? ko;
          }
        }
      }
    } catch (e) {
      debugPrint('[ClothingTermService] ⚠️ 카테고리 lookup 실패: $e');
    }

    return null;
  }

  /// 영어 용어 → "English (한글발음)" 형식으로 변환
  /// 예: "denim_jacket" → "Denim Jacket (데님 자켓)"
  String formatWithPronunciation(String englishTerm, String category) {
    if (!_initialized) {
      debugPrint('[ClothingTermService] ⚠️ 아직 초기화되지 않음');
      return englishTerm;
    }

    final normalized = englishTerm
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    final categoryData = _terms[category] ??
      (category == 'clothing_types' ? _clothingTypeTerms : null);
    if (categoryData == null) {
      debugPrint('[ClothingTermService] ⚠️ 카테고리 없음: $category');
      return englishTerm;
    }

    final termData = categoryData[normalized];
    if (termData == null) {
      debugPrint('[ClothingTermService] ⚠️ 용어 없음: $normalized in $category');
      return englishTerm;
    }

    if (termData is Map && termData['en'] != null && termData['ko'] != null) {
      final en = termData['en'] as String;
      final ko = termData['ko'] as String;
      return '$en ($ko)';
    }

    return englishTerm;
  }

  /// 편의 메서드 - 카테고리 기반
  String typeWithPronunciation(String type) {
    // 먼저 category lookup 시도
    final categoryDisplay = getCategoryDisplay(type);
    if (categoryDisplay != null) {
      return categoryDisplay;
    }
    // 실패면 원본 반환
    return type;
  }
}
