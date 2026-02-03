import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/clothing_item.dart';
import '../models/codi_record.dart';
import '../models/codi_score.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/config_service.dart';

/// 옷장 및 코디 기록 관리 Provider
class WardrobeProvider extends ChangeNotifier {
  final StorageService _storage;
  final GeminiService _gemini;

  List<ClothingItem> _clothes = [];
  List<CodiRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  WardrobeProvider({
    required StorageService storage,
    required GeminiService gemini,
  })  : _storage = storage,
        _gemini = gemini {
    _loadData();
  }

  List<ClothingItem> get clothes => _clothes;
  List<CodiRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ClothingItem> get tops {
    final filtered = _clothes
        .where((item) => item.typeId.trim().toLowerCase() == 'top')
        .toList();
    debugPrint('[Wardrobe] tops 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    for (final item in _clothes) {
      debugPrint('  - ${item.name}: typeId="${item.typeId}"');
    }
    return filtered;
  }

  List<ClothingItem> get bottoms {
    final filtered = _clothes
        .where((item) => item.typeId.trim().toLowerCase() == 'bottom')
        .toList();
    debugPrint('[Wardrobe] bottoms 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    return filtered;
  }

  /// 사진에서 상/하의 여부 및 설명 분석
  Future<Map<String, dynamic>?> analyzeClothingFromImage(String imagePath) async {
    try {
      final result = await _gemini.analyzeImage(imagePath, 'analyze_clothing_json');
      debugPrint('[Wardrobe] Gemini 응답: $result');
      if (result == null) {
        debugPrint('[Wardrobe] Gemini 응답이 null입니다');
        return null;
      }

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(result);
      if (jsonMatch == null) {
        debugPrint('[Wardrobe] JSON을 찾을 수 없습니다. 응답: $result');
        return null;
      }

      final jsonStr = jsonMatch.group(0)!;
      debugPrint('[Wardrobe] JSON 매치: $jsonStr');
      
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;

      return Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      debugPrint('[Wardrobe] 의류 분석 실패: $e');
      return null;
    }
  }

  String _normalizeTypeId(String typeId, String name) {
    final raw = typeId.trim().toLowerCase();
    if (raw == 'top' || raw == 'bottom') return raw;

    final nameLower = name.toLowerCase();
    if (raw.contains('상의') || raw.contains('top') ||
        nameLower.contains('상의') || nameLower.contains('top')) {
      return 'top';
    }

    if (raw.contains('하의') || raw.contains('bottom') ||
        nameLower.contains('하의') || nameLower.contains('bottom')) {
      return 'bottom';
    }

    return raw;
  }

  ClothingItem _normalizeItemType(ClothingItem item) {
    final normalized = _normalizeTypeId(item.typeId, item.name);
    if (normalized == item.typeId) return item;

    return ClothingItem(
      id: item.id,
      name: item.name,
      typeId: normalized,
      createdAt: item.createdAt,
      originalImagePath: item.originalImagePath,
      extractedImagePath: item.extractedImagePath,
      dominantColor: item.dominantColor,
      memo: item.memo,
    );
  }

  /// 이미지를 정규화된 좌표로 크롭
  /// 좌표는 0.0~1.0 범위의 상대 좌표
  Future<String?> _cropImageByBounds(
    String imagePath, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    try {
      final imageFile = img.decodeImage(await File(imagePath).readAsBytes());
      if (imageFile == null) return null;

      final width = imageFile.width;
      final height = imageFile.height;

      final x1 = (left * width).toInt().clamp(0, width);
      final y1 = (top * height).toInt().clamp(0, height);
      final x2 = (right * width).toInt().clamp(0, width);
      final y2 = (bottom * height).toInt().clamp(0, height);

      if (x1 >= x2 || y1 >= y2) {
        debugPrint('[Wardrobe] 크롭 좌표 무효: ($x1,$y1) - ($x2,$y2)');
        return null;
      }

      final cropped = img.copyCrop(
        imageFile,
        x: x1,
        y: y1,
        width: x2 - x1,
        height: y2 - y1,
      );

      // 임시 폴더에 크롭된 이미지 저장
      final tempDir = await getTemporaryDirectory();
      final croppedDir = Directory('${tempDir.path}/cropped_clothes');
      await croppedDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${croppedDir.path}/cropped_$timestamp.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodePng(cropped));

      debugPrint('[Wardrobe] 크롭 완료: $outputPath (${x2-x1}x${y2-y1})');
      return outputPath;
    } catch (e) {
      debugPrint('[Wardrobe] 크롭 실패: $e');
      return null;
    }
  }

  /// 데이터 불러오기
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _clothes = await _storage.loadClothes();
      var changed = false;
      final normalized = _clothes.map((item) {
        final updated = _normalizeItemType(item);
        if (updated.typeId != item.typeId) changed = true;
        return updated;
      }).toList();
      if (changed) {
        _clothes = normalized;
        await _storage.saveClothes(_clothes);
      }
      _records = await _storage.loadRecords();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 옷 추가
  Future<bool> addClothing({
    required String name,
    required String typeId,
    required String imagePath,
    Map<String, double>? bounds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final normalizedTypeId = _normalizeTypeId(typeId, name);
      final typeConfig =
          ConfigService.instance.getClothingTypeById(normalizedTypeId);
      if (typeConfig == null) {
        _error = ConfigService.instance.getString('strings.errors.clothing_type_not_found');
        notifyListeners();
        return false;
      }

      // 좌표 기반 크롭 시도
      String? extractedImagePath;
      if (bounds != null &&
          bounds['left'] != null &&
          bounds['top'] != null &&
          bounds['right'] != null &&
          bounds['bottom'] != null) {
        extractedImagePath = await _cropImageByBounds(
          imagePath,
          left: bounds['left']!,
          top: bounds['top']!,
          right: bounds['right']!,
          bottom: bounds['bottom']!,
        );
      }

      // 크롭 실패 시 원본 이미지 사용
      if (extractedImagePath == null) {
        final extractedImage = await _gemini.extractClothing(
          imagePath: imagePath,
          clothingType: typeConfig.promptToken,
        );
        extractedImagePath = extractedImage?.path;
      }

      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        typeId: normalizedTypeId,
        originalImagePath: imagePath,
        extractedImagePath: extractedImagePath,
      );

      debugPrint('[Wardrobe] 옷 추가: name="$name", typeId="$normalizedTypeId" (원본: "$typeId")');
      _clothes.add(item);
      await _storage.saveClothes(_clothes);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 옷 삭제
  Future<void> removeClothing(String id) async {
    _clothes.removeWhere((item) => item.id == id);
    await _storage.saveClothes(_clothes);
    notifyListeners();
  }

  /// 코디 기록 추가
  Future<void> addCodiRecord({
    required String topId,
    required String bottomId,
    required String composedImagePath,
    required CodiScore score,
    String? memo,
  }) async {
    final record = CodiRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topId: topId,
      bottomId: bottomId,
      composedImagePath: composedImagePath,
      score: score,
      memo: memo,
    );

    _records.add(record);
    await _storage.saveRecords(_records);
    notifyListeners();
  }

  /// 코디 기록 업데이트
  Future<void> updateCodiRecord(String id, CodiRecord updatedRecord) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      _records[index] = updatedRecord;
      await _storage.saveRecords(_records);
      notifyListeners();
    }
  }

  /// 코디 기록 삭제
  Future<void> removeCodiRecord(String id) async {
    _records.removeWhere((record) => record.id == id);
    await _storage.saveRecords(_records);
    notifyListeners();
  }

  /// 특정 옷이 포함된 코디 기록 조회
  List<CodiRecord> getRecordsWithClothing(String clothingId) {
    return _records
        .where((record) =>
            record.topId == clothingId || record.bottomId == clothingId)
        .toList();
  }

  /// 점수별 정렬된 코디 기록
  List<CodiRecord> get recordsByScore {
    final sorted = List<CodiRecord>.from(_records);
    final weights = _scoreWeights();
    sorted.sort((a, b) => b.score
        .weightedAverage(weights)
        .compareTo(a.score.weightedAverage(weights)));
    return sorted;
  }

  Map<String, double> _scoreWeights() {
    final items = ConfigService.instance.scoreItems;
    return {for (final item in items) item.id: item.weight};
  }
}
