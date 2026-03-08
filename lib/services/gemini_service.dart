import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'config_service.dart';

/// Gemini API를 통한 AI 서비스
///
/// **역할:**
/// - 옷 이미지 분석 (JSON 형식)
/// - 옷 추출 (투명 배경 PNG - 현재는 원본 이미지 저장)
class GeminiService {
  late final GenerativeModel _model;
  final String _apiKey;

  GeminiService({required String apiKey}) : _apiKey = apiKey {
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);
  }

  /// 이미지 분석 (텍스트 기반 응답)
  ///
  /// **사용:**
  /// - analyze_clothing_json: 상의/하의 감지
  /// - analyze_image: 일반 분석
  Future<String?> analyzeImage(String imagePath, String promptKey) async {
    try {
      final stopwatch = Stopwatch()..start();
      const requestTimeout = Duration(seconds: 12);

      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        debugPrint('[Gemini] 이미지 파일 없음: $imagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imagePath);

      // 프롬프트 로드
      final prompt = ConfigService.instance.getPrompt(promptKey);
      debugPrint('[Gemini] ===== AI 요청 시작 =====');
      debugPrint('[Gemini] PromptKey: $promptKey');
      debugPrint('[Gemini] ImagePath: $imagePath');
      debugPrint('[Gemini] MimeType: $mimeType');
      debugPrint('[Gemini] ImageBytes: ${imageBytes.length} bytes');
      _logLongText('[Gemini] Prompt 원문', prompt);

      // Gemini API 호출
      final content = [
        Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
      ];

      debugPrint('[Gemini] generateContent 호출');
      final response = await _model
          .generateContent(content)
          .timeout(
            requestTimeout,
            onTimeout: () => throw Exception(
              'Gemini 요청 타임아웃(${requestTimeout.inSeconds}s)',
            ),
          );
      final result = response.text;

      if (result == null) {
        debugPrint('[Gemini] 응답 텍스트가 null 입니다.');
      } else {
        _logLongText('[Gemini] 응답 원문', result, chunkSize: 500);
      }
      stopwatch.stop();
      debugPrint('[Gemini] 요청 소요: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[Gemini] ===== AI 요청 종료 =====');

      return result;
    } catch (e) {
      debugPrint('[Gemini] 이미지 분석 실패: $e');
      return null;
    }
  }

  /// 옷 추출 (현재는 원본 이미지를 임시 폴더에 저장)
  ///
  /// **제약:**
  /// - Gemini는 이미지 생성 불가 (text/binary 응답만 가능)
  /// - 따라서 현재는 원본 이미지를 저장하고
  /// - 향후 image_service 패키지로 처리 예정
  ///
  /// **반환:**
  /// - 저장된 이미지 File 객체 (null이면 실패)
  Future<File?> extractClothing({
    required String imagePath,
    required String clothingType,
  }) async {
    try {
      // 원본 이미지 읽기
      final sourceFile = File(imagePath);
      if (!sourceFile.existsSync()) {
        debugPrint('[Gemini] 원본 이미지 없음: $imagePath');
        return null;
      }

      // 임시 폴더 생성
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/extracted_clothes');
      await extractDir.create(recursive: true);

      // 저장 파일 경로 생성
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'extracted_${clothingType}_$timestamp.png';
      final outputFile = File('${extractDir.path}/$fileName');

      // 이미지 복사 (현재는 원본 그대로)
      // TODO: 향후 실제 추출 로직 추가 (크롭, 배경 제거 등)
      await sourceFile.copy(outputFile.path);

      debugPrint('[Gemini] 옷 이미지 저장됨: ${outputFile.path}');
      return outputFile;
    } catch (e) {
      debugPrint('[Gemini] 옷 추출 실패: $e');
      return null;
    }
  }

  /// 아바타 실루엣 진화 (진화 기능용)
  ///
  /// **역할:**
  /// - 기본 마네킹 실루엣을 참고 사진 기반으로 미세 조정
  /// - 현재는 비활성 (avatar evolution 기능 중단)
  Future<File?> evolveAvatarSilhouette({
    required String baseAvatarPath,
    required String referencePath,
    required String bodyType,
  }) async {
    try {
      debugPrint('[진화] Placeholder: 실루엣 진화 요청 (현재 비활성)');
      // TODO: 향후 image generation 서비스로 구현 예정
      return null;
    } catch (e) {
      debugPrint('[Gemini] 실루엣 진화 실패: $e');
      return null;
    }
  }

  /// 파일 경로에서 MIME 타입 결정
  String _getMimeType(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  void _logLongText(String prefix, String text, {int chunkSize = 700}) {
    if (text.isEmpty) {
      debugPrint('$prefix: <empty>');
      return;
    }

    final totalChunks = (text.length / chunkSize).ceil();
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      final chunkIndex = (i ~/ chunkSize) + 1;
      final chunk = text.substring(i, end);
      debugPrint('$prefix [$chunkIndex/$totalChunks]: $chunk');
    }
  }
}
