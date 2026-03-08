import 'package:flutter/material.dart';
import '../services/clothing_term_service.dart';

/// 패션 용어를 "English (한글발음)" 형식으로 표시하는 위젯
/// 예: "Denim Jacket (데님 자켓)"
class ClothingTermText extends StatelessWidget {
  final String englishTerm;
  final String category; // 'clothing_types' 등
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClothingTermText(
    this.englishTerm,
    this.category, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final formatted = ClothingTermService.instance
          .formatWithPronunciation(englishTerm, category);

      return Text(
        formatted,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    } catch (e) {
      // 오류 발생 시 원본 영어 텍스트만 표시
      debugPrint('[ClothingTermText] ⚠️ 포맷팅 오류: $e, 원본 사용: $englishTerm');
      return Text(
        englishTerm,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
  }
}
