import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'config_service.dart';

/// Stability AI 이미지 생성 서비스
///
/// 실행 시 `--dart-define=STABILITY_API_KEY=...`로 키를 주입하면 사용 가능하다.
class StabilityService {
  static const _baseUrl = 'https://api.stability.ai/v2beta';
  static const _v1BaseUrl = 'https://api.stability.ai/v1';
  static const _v1ImageToImageEngine = 'stable-diffusion-xl-1024-v1-0';
  static const List<(int, int)> _sdxlAllowedSizes = [
    (1024, 1024),
    (1152, 896),
    (1216, 832),
    (1344, 768),
    (1536, 640),
    (640, 1536),
    (768, 1344),
    (832, 1216),
    (896, 1152),
  ];

  final String _apiKey;

  StabilityService({required String apiKey}) : _apiKey = apiKey;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Core 이미지 생성 API 호출
  Future<File?> generateCoreImage({
    required String prompt,
    String aspectRatio = '1:1',
    String outputFormat = 'png',
    int? seed,
  }) async {
    if (!isConfigured) {
      debugPrint('[Stability] API 키가 비어 있습니다.');
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/stable-image/generate/core'),
      )
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..headers['Accept'] = 'image/*'
        ..fields['prompt'] = prompt
        ..fields['aspect_ratio'] = aspectRatio
        ..fields['output_format'] = outputFormat;

      if (seed != null) {
        request.fields['seed'] = seed.toString();
      }

      final streamed = await request.send();
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        debugPrint('[Stability] 요청 실패(${streamed.statusCode}): $body');
        return null;
      }

      final bytes = await streamed.stream.toBytes();
      if (bytes.isEmpty) {
        debugPrint('[Stability] 빈 이미지 응답');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/stability_images');
      await outputDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${outputDir.path}/stability_$timestamp.$outputFormat');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('[Stability] 이미지 생성 완료: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[Stability] 이미지 생성 예외: $e');
      return null;
    }
  }

  /// Image-to-Image: 기존 이미지에 변화 적용
  /// 
  /// 만든 이미지(마네킹)에 조건(옷)을 적용해서 새로운 이미지 생성
  /// strength: 0.0 (원본 유지) ~ 1.0 (완전히 새로 생성)
  Future<File?> imageToImage({
    required String baseImagePath,
    required String prompt,
    String outputFormat = 'png',
    double strength = 0.7,
    int? seed,
  }) async {
    if (!isConfigured) {
      debugPrint('[Stability] API 키가 비어 있습니다.');
      return null;
    }

    try {
      final imageFile = File(baseImagePath);
      if (!imageFile.existsSync()) {
        debugPrint('[Stability] 베이스 이미지 파일 없음: $baseImagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final prepared = _prepareImageForSdxlV1(imageBytes);
      
      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] 🚀 Image-to-Image API 호출');
      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] Base Image: $baseImagePath');
      debugPrint('[Stability] Base Image Size: ${imageBytes.length} bytes');
      debugPrint('[Stability] Prepared Size: ${prepared.width}x${prepared.height}');
      debugPrint('[Stability] Prepared Bytes: ${prepared.bytes.length} bytes');
      debugPrint('[Stability] Image Strength: $strength');
      debugPrint('[Stability] CFG Scale: 7');
      debugPrint('[Stability] Steps: 30');
      debugPrint('[Stability] Samples: 1');
      debugPrint('[Stability] Seed: ${seed ?? "random"}');
      debugPrint('[Stability] Prompt Length: ${prompt.length} characters');
      debugPrint('[Stability] Endpoint: $_v1BaseUrl/generation/$_v1ImageToImageEngine/image-to-image');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_v1BaseUrl/generation/$_v1ImageToImageEngine/image-to-image'),
      )
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..headers['Accept'] = 'image/png'
        ..fields['text_prompts[0][text]'] = prompt
        ..fields['text_prompts[0][weight]'] = '1.0'
        ..fields['init_image_mode'] = 'IMAGE_STRENGTH'
        ..fields['image_strength'] = strength.toString()
        ..fields['cfg_scale'] = '7'
        ..fields['steps'] = '30'
        ..fields['samples'] = '1'
        ..files.add(
          http.MultipartFile.fromBytes(
            'init_image',
            prepared.bytes,
            filename: 'base_image.png',
          ),
        );

      if (seed != null) {
        request.fields['seed'] = seed.toString();
      }

      debugPrint('[Stability] ⏳ API 요청 전송 중...');
      final startTime = DateTime.now();
      
      final streamed = await request.send();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('[Stability] API 응답 받음 (소요 시간: ${duration.inSeconds}초)');
      debugPrint('[Stability] HTTP Status: ${streamed.statusCode}');
      
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        debugPrint('[Stability] ❌ Image-to-Image 요청 실패');
        debugPrint('[Stability] Status: ${streamed.statusCode}');
        debugPrint('[Stability] Response: $body');
        return null;
      }

      final bytes = await streamed.stream.toBytes();
      if (bytes.isEmpty) {
        debugPrint('[Stability] ❌ 빈 이미지 응답');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/stability_outfit');
      await outputDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${outputDir.path}/outfit_$timestamp.$outputFormat');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] ✅ Image-to-Image 완료');
      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] 📍 결과 파일: ${file.path}');
      debugPrint('[Stability] 📦 이미지 크기: ${bytes.length} bytes');
      debugPrint('[Stability] ⏱️  생성 시간: ${duration.inSeconds}초');
      debugPrint('[Stability] ════════════════════════════════════════');
      
      return file;
    } catch (e) {
      debugPrint('[Stability] ❌ Image-to-Image 예외: $e');
      return null;
    }
  }

  ({List<int> bytes, int width, int height}) _prepareImageForSdxlV1(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      debugPrint('[Stability] ⚠️ 이미지 디코드 실패. 원본 바이트 사용');
      return (bytes: sourceBytes, width: 0, height: 0);
    }

    final sourceW = decoded.width;
    final sourceH = decoded.height;
    final sourceRatio = sourceW / sourceH;

    (int, int) bestTarget = _sdxlAllowedSizes.first;
    var bestScore = double.infinity;

    for (final candidate in _sdxlAllowedSizes) {
      final targetRatio = candidate.$1 / candidate.$2;
      final ratioScore = (math.log(sourceRatio) - math.log(targetRatio)).abs();
      final scale = math.max(candidate.$1 / sourceW, candidate.$2 / sourceH);
      final scaleScore = (scale - 1.0).abs();
      final score = ratioScore * 10 + scaleScore;

      if (score < bestScore) {
        bestScore = score;
        bestTarget = candidate;
      }
    }

    final targetW = bestTarget.$1;
    final targetH = bestTarget.$2;

    if (sourceW == targetW && sourceH == targetH) {
      return (bytes: sourceBytes, width: sourceW, height: sourceH);
    }

    final resized = img.copyResize(
      decoded,
      width: targetW,
      height: targetH,
      maintainAspect: true,
      interpolation: img.Interpolation.linear,
    );

    final offsetX = ((resized.width - targetW) / 2).floor().clamp(0, resized.width - targetW);
    final offsetY = ((resized.height - targetH) / 2).floor().clamp(0, resized.height - targetH);

    final cropped = img.copyCrop(
      resized,
      x: offsetX,
      y: offsetY,
      width: targetW,
      height: targetH,
    );

    return (
      bytes: img.encodePng(cropped),
      width: targetW,
      height: targetH,
    );
  }

  /// Inpainting: 마스크 영역만 자연스럽게 수정
  ///
  /// - image: 원본/베이스 이미지
  /// - mask: 편집할 영역(흰색) / 유지할 영역(검정)
  /// - prompt: 마스크 영역에 반영할 의류 설명
  Future<File?> inpainting({
    required String baseImagePath,
    required String maskImagePath,
    required String prompt,
    String outputFormat = 'png',
    int? seed,
  }) async {
    if (!isConfigured) {
      debugPrint('[Stability] API 키가 비어 있습니다.');
      return null;
    }

    try {
      final baseImageFile = File(baseImagePath);
      if (!baseImageFile.existsSync()) {
        debugPrint('[Stability] 베이스 이미지 파일 없음: $baseImagePath');
        return null;
      }

      final maskFile = File(maskImagePath);
      if (!maskFile.existsSync()) {
        debugPrint('[Stability] 마스크 이미지 파일 없음: $maskImagePath');
        return null;
      }

      final baseImageBytes = await baseImageFile.readAsBytes();
      final maskBytes = await maskFile.readAsBytes();

      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] 🧩 Inpainting API 호출');
      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] Base Image: $baseImagePath');
      debugPrint('[Stability] Mask Image: $maskImagePath');
      debugPrint('[Stability] Base Size: ${baseImageBytes.length} bytes');
      debugPrint('[Stability] Mask Size: ${maskBytes.length} bytes');
      debugPrint('[Stability] Output Format: $outputFormat');
      debugPrint('[Stability] Seed: ${seed ?? "random"}');
      debugPrint('[Stability] Prompt Length: ${prompt.length} characters');
      debugPrint('[Stability] Endpoint: $_baseUrl/stable-image/edit/inpaint');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/stable-image/edit/inpaint'),
      )
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..headers['Accept'] = 'image/*'
        ..fields['prompt'] = prompt
        ..fields['output_format'] = outputFormat
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            baseImageBytes,
            filename: 'base_image.png',
          ),
        )
        ..files.add(
          http.MultipartFile.fromBytes(
            'mask',
            maskBytes,
            filename: 'mask_image.png',
          ),
        );

      if (seed != null) {
        request.fields['seed'] = seed.toString();
      }

      debugPrint('[Stability] ⏳ Inpainting 요청 전송 중...');
      final startTime = DateTime.now();

      final streamed = await request.send();

      final duration = DateTime.now().difference(startTime);
      debugPrint('[Stability] Inpainting 응답 받음 (소요 시간: ${duration.inSeconds}초)');
      debugPrint('[Stability] HTTP Status: ${streamed.statusCode}');

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        debugPrint('[Stability] ❌ Inpainting 요청 실패');
        debugPrint('[Stability] Status: ${streamed.statusCode}');
        debugPrint('[Stability] Response: $body');
        return null;
      }

      final bytes = await streamed.stream.toBytes();
      if (bytes.isEmpty) {
        debugPrint('[Stability] ❌ 빈 이미지 응답');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/stability_inpaint');
      await outputDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${outputDir.path}/inpaint_$timestamp.$outputFormat');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] ✅ Inpainting 완료');
      debugPrint('[Stability] ════════════════════════════════════════');
      debugPrint('[Stability] 📍 결과 파일: ${file.path}');
      debugPrint('[Stability] 📦 이미지 크기: ${bytes.length} bytes');
      debugPrint('[Stability] ⏱️  생성 시간: ${duration.inSeconds}초');
      debugPrint('[Stability] ════════════════════════════════════════');

      return file;
    } catch (e) {
      debugPrint('[Stability] ❌ Inpainting 예외: $e');
      return null;
    }
  }

  /// 배경 제거 (투명 PNG 반환)
  Future<File?> removeBackground(String imagePath) async {
    if (!isConfigured) {
      debugPrint('[Stability] API 키가 비어 있습니다.');
      return null;
    }

    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        debugPrint('[Stability] 이미지 파일 없음: $imagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/stable-image/edit/remove-background'),
      )
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..headers['Accept'] = 'image/*'
        ..fields['output_format'] = 'png'
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'image.png',
          ),
        );

      final streamed = await request.send();
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        debugPrint('[Stability] 배경 제거 실패(${streamed.statusCode}): $body');
        return null;
      }

      final bytes = await streamed.stream.toBytes();
      if (bytes.isEmpty) {
        debugPrint('[Stability] 빈 이미지 응답');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/removed_background');
      await outputDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${outputDir.path}/nobg_$timestamp.png');
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('[Stability] 배경 제거 완료: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[Stability] 배경 제거 예외: $e');
      return null;
    }
  }

  /// 아바타 진화용 이미지 생성
  ///
  /// 현재 Core API 기반 프롬프트 생성 방식으로 동작한다.
  Future<File?> evolveAvatarSilhouette({
    required String bodyType,
  }) async {
    final prompt = ConfigService.instance.getPrompt(
      'evolve_avatar',
      params: {'body_type': bodyType},
    );

    return generateCoreImage(
      prompt: prompt,
      aspectRatio: '2:3',
      outputFormat: 'png',
    );
  }

  /// 코디 이미지 생성 (v3.0)
  ///
  /// 여러 옷 아이템을 조합하여 마네킹 착용 이미지를 생성합니다.
  /// 
  /// 파라미터:
  /// - coordinationPrompt: Gemini가 생성한 코디 프롬프트
  /// - aspectRatio: 이미지 비율 (기본: 2:3, 마네킹 전신)
  /// - seed: 재현 가능성을 위한 시드 (선택)
  /// 
  /// 반환: 생성된 코디 이미지 파일 (실패 시 null)
  Future<File?> generateCoordinationImage({
    required String coordinationPrompt,
    String aspectRatio = '2:3',
    int? seed,
  }) async {
    if (!isConfigured) {
      debugPrint('[StabilityV3] API 키가 비어 있습니다.');
      return null;
    }

    try {
      debugPrint('[StabilityV3] ════════════════════════════════════════');
      debugPrint('[StabilityV3] 🚀 코디 이미지 생성 시작');
      debugPrint('[StabilityV3] ════════════════════════════════════════');
      debugPrint('[StabilityV3] Prompt Length: ${coordinationPrompt.length} characters');
      debugPrint('[StabilityV3] Aspect Ratio: $aspectRatio');
      debugPrint('[StabilityV3] Seed: ${seed ?? "random"}');
      debugPrint('[StabilityV3] Prompt Preview: ${coordinationPrompt.substring(0, math.min(200, coordinationPrompt.length))}...');

      final result = await generateCoreImage(
        prompt: coordinationPrompt,
        aspectRatio: aspectRatio,
        seed: seed,
      );

      if (result != null) {
        debugPrint('[StabilityV3] ✅ 코디 이미지 생성 완료: ${result.path}');
      } else {
        debugPrint('[StabilityV3] ❌ 코디 이미지 생성 실패');
      }

      return result;
    } catch (e) {
      debugPrint('[StabilityV3] 코디 이미지 생성 예외: $e');
      return null;
    }
  }
}