import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'config_service.dart';

class GrokService {
  final String _apiKey;
  final http.Client _client;

  GrokService({required String apiKey, http.Client? client})
    : _apiKey = apiKey,
      _client = client ?? http.Client();

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<String?> analyzeImage(String imagePath, String promptKey) async {
    if (!isConfigured) {
      debugPrint('[Grok] API 키가 비어 있습니다.');
      return null;
    }

    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        debugPrint('[Grok] 이미지 파일 없음: $imagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imagePath);
      final prompt = ConfigService.instance.getPrompt(promptKey);
      final dataUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
      const primaryModel = String.fromEnvironment(
        'XAI_VISION_MODEL',
        defaultValue: 'grok-4-latest',
      );
      const fallbackModel = String.fromEnvironment(
        'XAI_VISION_FALLBACK_MODEL',
        defaultValue: 'grok-2-latest',
      );

      final modelCandidates = <String>[];
      void addModel(String model) {
        final normalized = model.trim();
        if (normalized.isEmpty) return;
        if (modelCandidates.contains(normalized)) return;
        modelCandidates.add(normalized);
      }

      addModel(primaryModel);
      addModel('grok-4-latest');
      addModel('grok-4');
      addModel(fallbackModel);

      debugPrint('[Grok-Vision] ===== 분석 요청 시작 =====');
      debugPrint('[Grok-Vision] PromptKey: $promptKey');
      debugPrint('[Grok-Vision] ImagePath: $imagePath');
      debugPrint('[Grok-Vision] MimeType: $mimeType');
      debugPrint('[Grok-Vision] ImageBytes: ${imageBytes.length} bytes');

      final endpoint = Uri.parse('https://api.x.ai/v1/chat/completions');
      final headers = {
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

      for (final model in modelCandidates) {
        final requestBodies = <Map<String, dynamic>>[
          {
            'model': model,
            'stream': false,
            'temperature': 0,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are a strict fashion vision extractor. Return JSON only.',
              },
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUrl},
                  },
                ],
              },
            ],
          },
        ];

        for (var variant = 0; variant < requestBodies.length; variant++) {
          final body = requestBodies[variant];
          http.Response? response;
          Object? lastError;
          const maxAttempts = 2;

          debugPrint('[Grok-Vision] Model 시도: $model (variant=${variant + 1})');
          for (var attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
              debugPrint('[Grok-Vision] 요청 시도 $attempt/$maxAttempts');
              response = await _client
                  .post(endpoint, headers: headers, body: jsonEncode(body))
                  .timeout(const Duration(seconds: 25));
              break;
            } on SocketException catch (e) {
              lastError = e;
              debugPrint('[Grok-Vision] 네트워크 오류(시도 $attempt): $e');
            } on http.ClientException catch (e) {
              lastError = e;
              debugPrint('[Grok-Vision] 클라이언트 오류(시도 $attempt): $e');
            } on TimeoutException catch (e) {
              lastError = e;
              debugPrint('[Grok-Vision] 타임아웃(시도 $attempt): $e');
            }

            if (attempt < maxAttempts) {
              final delayMs = 500 * attempt;
              await Future<void>.delayed(Duration(milliseconds: delayMs));
            }
          }

          if (response == null) {
            debugPrint('[Grok-Vision] 요청 실패(재시도 소진): $lastError');
            continue;
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            debugPrint(
              '[Grok-Vision] 요청 실패(${response.statusCode}) model=$model variant=${variant + 1}: ${response.body}',
            );
            continue;
          }

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final content = _extractAssistantContent(decoded);
          if (content == null || content.trim().isEmpty) {
            debugPrint(
              '[Grok-Vision] 응답 텍스트가 비어 있습니다. model=$model variant=${variant + 1}',
            );
            continue;
          }

          _logLongText('[Grok-Vision] 응답 원문', content, chunkSize: 500);
          debugPrint('[Grok-Vision] ===== 분석 요청 종료 =====');
          return content;
        }
      }

      debugPrint('[Grok-Vision] 사용 가능한 비전 모델/요청 형식을 찾지 못했습니다.');
      return null;
    } catch (e) {
      debugPrint('[Grok-Vision] 이미지 분석 실패: $e');
      return null;
    }
  }

  Future<File?> generateImageFromPrompt({
    required String prompt,
    String? sourceImagePath,
  }) async {
    if (!isConfigured) {
      debugPrint('[Grok] API 키가 비어 있습니다.');
      return null;
    }

    try {
      const primaryModel = String.fromEnvironment(
        'XAI_IMAGE_MODEL',
        defaultValue: 'grok-2-image',
      );
      const fallbackModel = String.fromEnvironment(
        'XAI_IMAGE_FALLBACK_MODEL',
        defaultValue: 'grok-2-image-latest',
      );

      final modelCandidates = <String>[];
      void addModel(String model) {
        final normalized = model.trim();
        if (normalized.isEmpty) return;
        if (modelCandidates.contains(normalized)) return;
        modelCandidates.add(normalized);
      }

      addModel('grok-imagine-image');
      addModel('grok-imagine-image-pro');
      addModel(primaryModel);
      addModel(fallbackModel);
      addModel('grok-2-image');
      addModel('grok-2-image-latest');

      final effectiveModels = List<String>.from(modelCandidates);

      if (effectiveModels.isEmpty) {
        debugPrint('[Grok-Image] 모델 후보가 비어 있습니다.');
        return null;
      }

      final sourcePath = (sourceImagePath ?? '').trim();
      String? sourceDataUrl;
      if (sourcePath.isEmpty) {
        debugPrint('[Grok-Image] edits 전용 모드: sourceImagePath 필수');
        return null;
      }
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        debugPrint('[Grok-Image] 입력 이미지 파일 없음: $sourcePath');
        return null;
      }
      final bytes = await sourceFile.readAsBytes();
      final mimeType = _getMimeType(sourcePath);
      sourceDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      debugPrint('[Grok-Image] ===== 생성 요청 시작 =====');
      debugPrint('[Grok-Image] Prompt(${prompt.length}): $prompt');
      debugPrint('[Grok-Image] HasSourceImage: true');
      debugPrint(
        '[Grok-Image] ModelCandidates(사용): ${effectiveModels.join(', ')}',
      );
      final endpoint = Uri.parse('https://api.x.ai/v1/images/edits');

      const totalTimeout = Duration(seconds: 75);
      const perRequestTimeout = Duration(seconds: 20);
      const retryDelay503 = Duration(seconds: 6);
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < effectiveModels.length; i++) {
        if (stopwatch.elapsed >= totalTimeout) {
          debugPrint('[Grok-Image] 전체 생성 타임아웃 도달(${totalTimeout.inSeconds}s)');
          return null;
        }

        final model = effectiveModels[i];
        final isLastModel = i == effectiveModels.length - 1;
        debugPrint(
          '[Grok-Image] Model 시도 ${i + 1}/${effectiveModels.length}: $model',
        );

        try {
          final body = <String, dynamic>{
            'model': model,
            'prompt': prompt,
            'n': 1,
            'image': {'url': sourceDataUrl},
            'image_url': sourceDataUrl,
            'input_image': {'url': sourceDataUrl},
          };

          debugPrint('[Grok-Image] Endpoint 시도: edits');

          final response = await _client
              .post(
                endpoint,
                headers: {
                  HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
                  HttpHeaders.contentTypeHeader: 'application/json',
                },
                body: jsonEncode(body),
              )
              .timeout(perRequestTimeout);

          if (response.statusCode < 200 || response.statusCode >= 300) {
            debugPrint(
              '[Grok-Image] 이미지 생성 실패(${response.statusCode}) model=$model endpoint=edits: ${response.body}',
            );

            final is503 = response.statusCode == 503;
            final isTemporary = is503 || response.statusCode >= 500;
            if (isTemporary && !isLastModel) {
              if (is503) {
                final remaining = totalTimeout - stopwatch.elapsed;
                if (remaining <= Duration.zero) {
                  debugPrint('[Grok-Image] 503 이후 대기 전 전체 타임아웃 도달');
                  return null;
                }
                final wait = remaining < retryDelay503
                    ? remaining
                    : retryDelay503;
                debugPrint(
                  '[Grok-Image] 503 감지 → ${wait.inSeconds}s 대기 후 다음 모델 시도',
                );
                await Future<void>.delayed(wait);
              }
              continue;
            }
            if (!isLastModel) {
              continue;
            }
            return null;
          }

          final first = _extractFirstImageData(response.body);
          if (first == null) {
            debugPrint(
              '[Grok-Image] 응답 data 형식 오류(model=$model, endpoint=edits)',
            );
            if (!isLastModel) {
              continue;
            }
            return null;
          }

          final saved = await _extractGeneratedFileFromData(first);
          if (saved != null) {
            debugPrint(
              '[Grok-Image] ✅ 이미지 생성 성공(model=$model, endpoint=edits): ${saved.path}',
            );
            debugPrint('[Grok-Image] ===== 생성 요청 종료(성공) =====');
            return saved;
          }

          debugPrint(
            '[Grok-Image] 저장 가능한 이미지 필드 없음(model=$model, endpoint=edits)',
          );
          if (!isLastModel) {
            continue;
          }
          return null;
        } catch (e) {
          debugPrint('[Grok-Image] Model $model 실패: $e');
          final is503Error = e.toString().contains('503');
          if (is503Error && !isLastModel) {
            final remaining = totalTimeout - stopwatch.elapsed;
            if (remaining <= Duration.zero) {
              debugPrint('[Grok-Image] 예외 503 이후 전체 타임아웃 도달');
              return null;
            }
            final wait = remaining < retryDelay503 ? remaining : retryDelay503;
            debugPrint(
              '[Grok-Image] 예외에서 503 감지 → ${wait.inSeconds}s 대기 후 다음 모델 시도',
            );
            await Future<void>.delayed(wait);
            continue;
          }
          return null;
        }
      }

      debugPrint('[Grok-Image] 이미지 생성 가능한 모델을 찾지 못했습니다.');
      return null;
    } catch (e) {
      debugPrint('[Grok-Image] 이미지 생성 예외: $e');
      return null;
    }
  }

  Map<String, dynamic>? _extractFirstImageData(String rawBody) {
    try {
      final root = jsonDecode(rawBody) as Map<String, dynamic>;
      final data = root['data'];
      if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        return data.first as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Grok-Image] 응답 JSON 파싱 실패: $e');
    }
    return null;
  }

  Future<File?> _extractGeneratedFileFromData(Map<String, dynamic> data) async {
    final b64 = (data['b64_json'] ?? '').toString();
    if (b64.trim().isNotEmpty) {
      return _saveGeneratedBytes(base64Decode(b64));
    }

    final url = (data['url'] ?? '').toString();
    if (url.trim().isNotEmpty) {
      return _downloadGeneratedImage(url);
    }

    return null;
  }

  Future<File?> _saveGeneratedBytes(List<int> bytes) async {
    if (bytes.isEmpty) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${appDir.path}/grok_generated');
    await outDir.create(recursive: true);

    final outFile = File(
      '${outDir.path}/generated_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await outFile.writeAsBytes(bytes, flush: true);
    await _pruneGeneratedFiles(outDir, maxFiles: 80);
    return outFile;
  }

  Future<void> _pruneGeneratedFiles(
    Directory dir, {
    required int maxFiles,
  }) async {
    try {
      if (!dir.existsSync()) return;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList();

      if (files.length <= maxFiles) return;

      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      final deleteTargets = files.take(files.length - maxFiles);
      for (final file in deleteTargets) {
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Grok-Image] 생성 이미지 정리 실패: $e');
    }
  }

  Future<File?> _downloadGeneratedImage(String url) async {
    try {
      final res = await _client.get(Uri.parse(url));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Grok-Image] URL 이미지 다운로드 실패(${res.statusCode})');
        return null;
      }
      return _saveGeneratedBytes(res.bodyBytes);
    } catch (e) {
      debugPrint('[Grok-Image] URL 이미지 다운로드 예외: $e');
      return null;
    }
  }

  String? _extractAssistantContent(Map<String, dynamic> root) {
    final choices = root['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final message = choices.first['message'];
    if (message is! Map<String, dynamic>) return null;

    final content = message['content'];
    if (content is String) return content;

    if (content is List) {
      final texts = content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .toList();
      if (texts.isEmpty) return null;
      return texts.join('\n');
    }

    return null;
  }

  String _getMimeType(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
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

  void dispose() {
    _client.close();
  }
}
