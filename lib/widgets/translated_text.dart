import 'package:flutter/material.dart';
import '../services/on_device_translation_service.dart';

/// Widget that displays English text translated to Korean on-device.
/// If input is already Korean, displays it directly.
/// Falls back to English if translation fails or produces suspicious results.
/// 
/// Example:
/// ```dart
/// TranslatedText(
///   englishText: "Classic white cotton t-shirt",
///   style: Theme.of(context).textTheme.bodyMedium,
/// )
/// ```
class TranslatedText extends StatelessWidget {
  final String englishText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? loadingColor;

  const TranslatedText({
    super.key,
    required this.englishText,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.loadingColor,
  });

  /// Check if text contains Korean characters
  bool _isKorean(String text) {
    final koreanRegex = RegExp(r'[\uAC00-\uD7A3]'); // Korean Hangul Unicode range
    return koreanRegex.hasMatch(text);
  }

  /// Validate translation result to avoid suspicious translations
  bool _isValidTranslation(String original, String translated) {
    // If translation is empty, it's invalid
    if (translated.isEmpty) {
      return false;
    }

    // If translation is too different in length (e.g., 50% difference), it might be wrong
    final lengthRatio = translated.length / original.length;
    if (lengthRatio > 3.0 || lengthRatio < 0.2) {
      debugPrint('[TranslatedText] ⚠️ Suspicious length ratio: "$original" (${original.length}) → "$translated" (${translated.length})');
      return false;
    }

    // If original has 2+ words but translation is 1 character, it's likely wrong
    final wordCount = original.split(RegExp(r'\s+')).length;
    if (wordCount >= 2 && translated.length == 1) {
      debugPrint('[TranslatedText] ⚠️ Single character result for multi-word input: "$original" → "$translated"');
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (englishText.isEmpty) {
      return const SizedBox.shrink();
    }

    // If input is already Korean, display directly without translation
    if (_isKorean(englishText)) {
      debugPrint('[TranslatedText] 🇰🇷 Input already Korean, skipping translation: "$englishText"');
      return Text(
        englishText,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return FutureBuilder<String>(
      future: _translateWithValidation(englishText),
      builder: (context, snapshot) {
        final displayText = snapshot.data ?? englishText;

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state with English text in lighter color
          return Text(
            englishText,
            style: style?.copyWith(
              color: loadingColor ?? Colors.grey[400],
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        if (snapshot.hasError) {
          // Fall back to English on error
          debugPrint('[TranslatedText] ❌ Error: ${snapshot.error}');
          return Text(
            englishText,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        return Text(
          displayText,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  Future<String> _translateWithValidation(String text) async {
    try {
      // Add timeout: if translation takes longer than 3 seconds, use English
      final translated = await OnDeviceTranslationService()
          .translateToKorean(text)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('[TranslatedText] ⏱️ Translation timeout for: "$text"');
              return text;
            },
          );
      
      // Validate translation quality
      if (_isValidTranslation(text, translated)) {
        return translated;
      } else {
        debugPrint('[TranslatedText] ⚠️ Translation validation failed, returning English');
        return text;
      }
    } catch (e) {
      debugPrint('[TranslatedText] ❌ Translation error: $e');
      return text;
    }
  }
}
