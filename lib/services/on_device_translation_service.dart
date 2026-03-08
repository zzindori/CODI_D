import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter/foundation.dart';

/// On-device translation service for EN → KO translation.
/// Caches translator instances and translation results.
class OnDeviceTranslationService {
  static final OnDeviceTranslationService _instance =
      OnDeviceTranslationService._internal();

  factory OnDeviceTranslationService() {
    return _instance;
  }

  OnDeviceTranslationService._internal();

  // Cache: translator by language pair
  late OnDeviceTranslator _translatorEnKo;
  bool _isInitialized = false;

  // Translation result cache to avoid re-translating same text
  final Map<String, String> _translationCache = {};

  /// Initialize the translator for EN → KO
  Future<void> _initializeIfNeeded() async {
    if (_isInitialized) {
      return;
    }

    try {
      _translatorEnKo = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.korean,
      );
      
      // Verify translator is working
      final testResult = await _translatorEnKo.translateText('test');
      if (testResult.isEmpty) {
        throw Exception('Translator returned empty result');
      }
      
      _isInitialized = true;
      debugPrint('[Translation] ✅ EN→KO translator initialized successfully');
    } catch (e) {
      debugPrint('[Translation] ❌ Initialization error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Translate English text to Korean.
  /// Returns Korean text if successful, or original text if translation fails.
  Future<String> translateToKorean(String englishText) async {
    if (englishText.isEmpty) {
      return englishText;
    }

    // Check cache first
    if (_translationCache.containsKey(englishText)) {
      final cached = _translationCache[englishText]!;
      debugPrint('[Translation] ✅ Cache hit: "$englishText" → "$cached"');
      return cached;
    }

    try {
      await _initializeIfNeeded();

      if (!_isInitialized) {
        debugPrint('[Translation] ⚠️ Translator not initialized, returning English');
        return englishText;
      }

      final koreanText = await _translatorEnKo.translateText(englishText);
      
      // Validate translation result
      if (koreanText.isEmpty) {
        debugPrint('[Translation] ⚠️ Translator returned empty string for: "$englishText"');
        return englishText;
      }

      // Cache the result
      _translationCache[englishText] = koreanText;
      debugPrint('[Translation] ✅ Translated: "$englishText" → "$koreanText"');
      
      return koreanText;
    } catch (e) {
      debugPrint('[Translation] ⚠️ Translation failed for "$englishText": $e');
      // Fall back to original English text
      return englishText;
    }
  }

  /// Batch translate multiple English texts to Korean.
  Future<List<String>> translateBatch(List<String> englishTexts) async {
    final results = <String>[];
    for (final text in englishTexts) {
      final translated = await translateToKorean(text);
      results.add(translated);
    }
    return results;
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _translationCache.length,
      'is_initialized': _isInitialized,
      'cached_items': _translationCache.keys.toList(),
    };
  }

  /// Clear all caches and close translator
  Future<void> closeTranslator() async {
    try {
      if (_isInitialized) {
        await _translatorEnKo.close();
        _isInitialized = false;
        debugPrint('[Translation] ✅ Translator closed');
      }
      _translationCache.clear();
    } catch (e) {
      debugPrint('[Translation] ❌ Error closing translator: $e');
    }
  }
}
