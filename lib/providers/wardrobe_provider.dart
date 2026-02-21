import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/clothing_item.dart';
import '../models/codi_record.dart';
import '../models/codi_score.dart';
import '../models/wardrobe_part.dart';
import '../models/clothing_analysis.dart';
import '../models/simple_clothing_item.dart';
import '../models/outfit_combination.dart';
import '../models/photo_analysis_record.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/stability_service.dart';
import '../services/config_service.dart';

/// 옷장 및 코디 기록 관리 Provider
class WardrobeProvider extends ChangeNotifier {
  final StorageService _storage;
  final GeminiService _gemini;
  final StabilityService _stability;

  // 기존 데이터
  List<ClothingItem> _clothes = [];
  List<CodiRecord> _records = [];
  
  // 새로운 부위 컬렉션 (사용자 노출)
  List<WardrobePart> _hairCollection = [];
  List<WardrobePart> _topCollection = [];
  List<WardrobePart> _bottomCollection = [];
  List<WardrobePart> _shoeCollection = [];
  List<WardrobePart> _accessoryCollection = [];
  
  // v3.0 간소화 데이터
  List<SimpleClothingItem> _simpleItems = [];
  List<OutfitCombination> _outfitCombinations = [];
  List<PhotoAnalysisRecord> _photoAnalyses = [];
  
  bool _isLoading = false;
  String? _error;

  WardrobeProvider({
    required StorageService storage,
    required GeminiService gemini,
    required StabilityService stability,
  })  : _storage = storage,
        _gemini = gemini,
        _stability = stability {
    _loadData();
  }

  // === 기존 Getter ===
  List<ClothingItem> get clothes => _clothes;
  List<CodiRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // === 새로운 부위 컬렉션 Getter ===
  List<WardrobePart> get hairCollection => _hairCollection;
  List<WardrobePart> get topCollection => _topCollection;
  List<WardrobePart> get bottomCollection => _bottomCollection;
  List<WardrobePart> get shoeCollection => _shoeCollection;
  List<WardrobePart> get accessoryCollection => _accessoryCollection;
  
  // === v3.0 간소화 Getter ===
  List<SimpleClothingItem> get simpleItems => _simpleItems;
  List<OutfitCombination> get outfitCombinations => _outfitCombinations;
  List<PhotoAnalysisRecord> get photoAnalyses => _photoAnalyses;

  List<ClothingItem> get tops {
    final filtered = _clothes
        .where((item) => item.category.toLowerCase() == 'top')
        .toList();
    debugPrint('[Wardrobe] tops 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    return filtered;
  }

  List<ClothingItem> get bottoms {
    final filtered = _clothes
        .where((item) => item.category.toLowerCase() == 'bottom')
        .toList();
    debugPrint('[Wardrobe] bottoms 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    return filtered;
  }

  List<ClothingItem> get shoes {
    final filtered = _clothes
        .where((item) => item.category.toLowerCase() == 'shoes')
        .toList();
    debugPrint('[Wardrobe] shoes 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    return filtered;
  }

  List<ClothingItem> get accessories {
    final filtered = _clothes
        .where((item) => item.category.toLowerCase() == 'accessory')
        .toList();
    debugPrint('[Wardrobe] accessories 필터: ${filtered.length}개 (전체: ${_clothes.length})');
    return filtered;
  }

  /// 사진에서 상/하의 여부 및 설명 분석
  Future<Map<String, dynamic>?> analyzeClothingFromImage(String imagePath) async {
    try {
      final result = await _gemini.analyzeImage(imagePath, 'analyze_clothing_json');
      debugPrint('[Wardrobe] Gemini 응답: $result');
      if (result == null) {
        debugPrint('[Wardrobe] Gemini 응답이 null입니다. fallback people 사용');
        return _fallbackPeoplePayload();
      }

      final decoded = _decodeGeminiJson(result);
      final normalized = _normalizePeoplePayload(decoded);
      if (normalized != null) return normalized;

      debugPrint('[Wardrobe] people 구조 변환 실패. fallback people 사용');
      return _fallbackPeoplePayload();
    } catch (e) {
      debugPrint('[Wardrobe] 의류 분석 실패: $e');
      return _fallbackPeoplePayload();
    }
  }

  String _normalizeTypeId(String typeId, String name) {
    final raw = typeId.trim().toLowerCase();
    if (raw == 'top' || raw == 'bottom' || raw == 'shoes' || raw == 'accessory' || raw == 'hair') {
      return raw;
    }

    final nameLower = name.toLowerCase();
    if (raw.contains('상의') || raw.contains('top') ||
        nameLower.contains('상의') || nameLower.contains('top')) {
      return 'top';
    }

    if (raw.contains('하의') || raw.contains('bottom') ||
        nameLower.contains('하의') || nameLower.contains('bottom')) {
      return 'bottom';
    }

    if (raw.contains('신발') || raw.contains('shoe') || raw.contains('shoes') ||
        nameLower.contains('신발') || nameLower.contains('shoe') || nameLower.contains('sneaker') || nameLower.contains('boots')) {
      return 'shoes';
    }

    if (raw.contains('악세') || raw.contains('악세서리') || raw.contains('accessory') ||
        nameLower.contains('악세') || nameLower.contains('악세서리') || nameLower.contains('necklace') ||
        nameLower.contains('ring') || nameLower.contains('bracelet') || nameLower.contains('bag')) {
      return 'accessory';
    }

    if (raw.contains('머리') || raw.contains('hair') ||
        nameLower.contains('머리') || nameLower.contains('hair')) {
      return 'hair';
    }

    return raw;
  }

  ClothingItem _normalizeItemType(ClothingItem item) {
    final normalized = _normalizeTypeId(item.typeId, item.name);
    if (normalized == item.typeId) return item;

    return ClothingItem(
      id: item.id,
      category: normalized,
      name: item.name,
      createdAt: item.createdAt,
      sourceImagePath: item.sourceImagePath,
      imagePath: item.imagePath,
      dominantColor: item.dominantColor,
      imageOnMannequinPath: item.imageOnMannequinPath,
      hairAnalysisJson: item.hairAnalysisJson,
      clothingAnalysisJson: item.clothingAnalysisJson,
      accessoryAnalysisJson: item.accessoryAnalysisJson,
      maskImagePath: item.maskImagePath,
      maskCoordinates: item.maskCoordinates,
      memo: item.memo,
    );
  }

  /// 이미지를 정규화된 좌표로 크롭
  /// 좌표는 0.0~1.0 범위의 상대 좌표

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
      
      // 새로운 부위 컬렉션 로드
      _hairCollection = await _storage.loadWardrobeParts('hair');
      _topCollection = await _storage.loadWardrobeParts('top');
      _bottomCollection = await _storage.loadWardrobeParts('bottom');
      _shoeCollection = await _storage.loadWardrobeParts('shoes');
      _accessoryCollection = await _storage.loadWardrobeParts('accessory');
      
      // v3.0 간소화 데이터 로드
      await _loadSimpleItems();
      await _loadOutfitCombinations();
      await _loadPhotoAnalyses();
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 옷 추가
  /// 옷 추가 (간소화 버전 - 직접 이미지 경로 지정)
  /// 
  /// generateClothingItems와 달리 이미 생성된 이미지를 직접 추가할 때 사용
  /// category: 'hair', 'top', 'bottom', 'shoes', 'accessory'
  Future<bool> addClothing({
    required String name,
    required String category,
    required String imagePath,
    String? sourceImagePath,
    ClothingAnalysis? analysis,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final item = ClothingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        category: category,
        name: name,
        sourceImagePath: sourceImagePath ?? imagePath,
        imagePath: imagePath,
        hairAnalysisJson: null,
        clothingAnalysisJson: category == 'top' ? analysis?.top?.toJson() :
                             category == 'bottom' ? analysis?.bottom?.toJson() :
                             category == 'shoes' ? analysis?.shoes?.toJson() : null,
        accessoryAnalysisJson: category == 'accessory' && analysis?.accessories.isNotEmpty == true
            ? analysis!.accessories.first.toJson()
            : null,
      );

      _clothes.add(item);
      await _storage.saveClothes(_clothes);

      final wardrobePart = WardrobePart(
        id: item.id,
        category: category,
        imagePath: imagePath,
      );

      switch (category) {
        case 'hair':
          _hairCollection.add(wardrobePart);
          await _storage.saveWardrobeParts('hair', _hairCollection);
        case 'top':
          _topCollection.add(wardrobePart);
          await _storage.saveWardrobeParts('top', _topCollection);
        case 'bottom':
          _bottomCollection.add(wardrobePart);
          await _storage.saveWardrobeParts('bottom', _bottomCollection);
        case 'shoes':
          _shoeCollection.add(wardrobePart);
          await _storage.saveWardrobeParts('shoes', _shoeCollection);
        case 'accessory':
          _accessoryCollection.add(wardrobePart);
          await _storage.saveWardrobeParts('accessory', _accessoryCollection);
      }

      debugPrint('[Wardrobe] 옷 추가: name="$name", category="$category"');
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Wardrobe] 옷 추가 예외: $e');
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

  /// 의류 아이템 생성 (Image-to-Image)
  ///
  /// 흐름:
  /// 1. 원본 이미지를 Gemini로 분석 (상의, 하의, 신발, 악세사리)
  /// 2. 각 부위별로 원본 이미지에 Image-to-Image 적용
  /// 3. 결과 저장
  Future<bool> generateClothingItems(String imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] 👗 의류 생성 파이프라인 시작: $imagePath');
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      
      // Step 1: 원본 이미지 분석
      debugPrint('[Wardrobe] Step 1️⃣: 의류 분석 중...');
      final analysis = await analyzeClothingDetailed(imagePath);
      if (analysis == null) {
        _error = '의류 분석 실패';
        debugPrint('[Wardrobe] ❌ 분석 실패');
        notifyListeners();
        return false;
      }
      debugPrint('[Wardrobe] ✅ 분석 완료');

      if (!_stability.isConfigured) {
        _error = 'Stability API 미설정';
        notifyListeners();
        return false;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Step 2: 각 부위별 Image-to-Image 생성
      
      // Top
      if (analysis.top != null) {
        debugPrint('[Wardrobe] Step 2️⃣: Top 생성 중...');
        final topPrompt = _buildClothingPrompt(analysis.top!);
        
        final topImage = await _stability.imageToImage(
          baseImagePath: imagePath,
          prompt: topPrompt,
          strength: 0.8,
        );

        if (topImage != null) {
          final item = ClothingItem(
            id: 'top_${timestamp}_0',
            category: 'top',
            name: analysis.top!.type,
            sourceImagePath: imagePath,
            imagePath: topImage.path,
            clothingAnalysisJson: analysis.top!.toJson(),
          );
          _clothes.add(item);
          _topCollection.add(WardrobePart(id: item.id, category: 'top', imagePath: topImage.path));
          debugPrint('[Wardrobe] ✅ Top 생성 완료');
        }
      }

      // Bottom
      if (analysis.bottom != null) {
        debugPrint('[Wardrobe] Step 2️⃣: Bottom 생성 중...');
        final bottomPrompt = _buildClothingPrompt(analysis.bottom!);
        
        final bottomImage = await _stability.imageToImage(
          baseImagePath: imagePath,
          prompt: bottomPrompt,
          strength: 0.8,
        );

        if (bottomImage != null) {
          final item = ClothingItem(
            id: 'bottom_${timestamp}_0',
            category: 'bottom',
            name: analysis.bottom!.type,
            sourceImagePath: imagePath,
            imagePath: bottomImage.path,
            clothingAnalysisJson: analysis.bottom!.toJson(),
          );
          _clothes.add(item);
          _bottomCollection.add(WardrobePart(id: item.id, category: 'bottom', imagePath: bottomImage.path));
          debugPrint('[Wardrobe] ✅ Bottom 생성 완료');
        }
      }

      // Shoes
      if (analysis.shoes != null) {
        debugPrint('[Wardrobe] Step 2️⃣: Shoes 생성 중...');
        final shoesPrompt = _buildClothingPrompt(analysis.shoes!);
        
        final shoesImage = await _stability.imageToImage(
          baseImagePath: imagePath,
          prompt: shoesPrompt,
          strength: 0.8,
        );

        if (shoesImage != null) {
          final item = ClothingItem(
            id: 'shoes_${timestamp}_0',
            category: 'shoes',
            name: analysis.shoes!.type,
            sourceImagePath: imagePath,
            imagePath: shoesImage.path,
            clothingAnalysisJson: analysis.shoes!.toJson(),
          );
          _clothes.add(item);
          _shoeCollection.add(WardrobePart(id: item.id, category: 'shoes', imagePath: shoesImage.path));
          debugPrint('[Wardrobe] ✅ Shoes 생성 완료');
        }
      }

      // Accessories
      if (analysis.accessories.isNotEmpty) {
        debugPrint('[Wardrobe] Step 2️⃣: Accessories 생성 중... (${analysis.accessories.length}개)');
        
        for (int i = 0; i < analysis.accessories.length; i++) {
          final acc = analysis.accessories[i];
          final accPrompt = _buildAccessoryPrompt(acc);
          
          final accImage = await _stability.imageToImage(
            baseImagePath: imagePath,
            prompt: accPrompt,
            strength: 0.8,
          );

          if (accImage != null) {
            final item = ClothingItem(
              id: 'accessory_${timestamp}_$i',
              category: 'accessory',
              name: acc.type,
              sourceImagePath: imagePath,
              imagePath: accImage.path,
              accessoryAnalysisJson: acc.toJson(),
            );
            _clothes.add(item);
            _accessoryCollection.add(WardrobePart(id: item.id, category: 'accessory', imagePath: accImage.path));
            debugPrint('[Wardrobe] ✅ Accessory #$i 생성 완료');
          }
        }
      }

      // Step 3: 저장
      await _storage.saveClothes(_clothes);
      await _storage.saveWardrobeParts('hair', _hairCollection);
      await _storage.saveWardrobeParts('top', _topCollection);
      await _storage.saveWardrobeParts('bottom', _bottomCollection);
      await _storage.saveWardrobeParts('shoes', _shoeCollection);
      await _storage.saveWardrobeParts('accessory', _accessoryCollection);

      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] ✅ 의류 생성 완료!');
      debugPrint('[Wardrobe] 총 ${_clothes.length}개 항목 저장됨');
      debugPrint('[Wardrobe] ════════════════════════════════════════');

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Wardrobe] 의류 생성 예외: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clothing (top/bottom/shoes)에 대한 Stability 프롬프트 생성
  String _buildClothingPrompt(ClothingPartAnalysis clothing) {
    return '''High-quality product photo of clothing item, professional fashion photography.
Type: ${clothing.type}
Material: ${clothing.material}
Color: ${clothing.color} (${clothing.colorHex})
Pattern: ${clothing.pattern}
Fit: ${clothing.fit}
Details: ${clothing.details}

White background, product photography, clean lighting, professional styling.''';
  }

  /// Accessory에 대한 Stability 프롬프트 생성
  String _buildAccessoryPrompt(AccessoryAnalysis accessory) {
    return '''High-quality product photo of accessory.
Type: ${accessory.type}
Material: ${accessory.material}
Color: ${accessory.color} (${accessory.colorHex})
Style: ${accessory.style}
Details: ${accessory.details}

White background, product photography, professional styling.''';
  }

  /// 마네킹에 옷 입히기 (Image-to-Image)
  /// 
  /// 1. 섬세한 분석 수행
  /// 2. Stability AI Image-to-Image로 마네킹에 옷 입혀 이미지 생성
  /// 3. 결과 저장
  Future<File?> dressUpMannequin({
    required String mannequinImagePath,
    required String clothingImagePath,
    String? maskImagePath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] 🎨 마네킹에 옷 입히기 시작');
      debugPrint('[Wardrobe] ════════════════════════════════════════');

      // Step 1: 의류에 대한 섬세한 분석
      final analysis = await analyzeClothingDetailed(clothingImagePath);
      if (analysis == null) {
        _error = '의류 분석 실패';
        notifyListeners();
        return null;
      }

      // Step 2: Stability Image-to-Image 호출
      if (!_stability.isConfigured) {
        _error = 'Stability API 키 미설정';
        notifyListeners();
        return null;
      }

      final prompt = analysis.generateStabilityPrompt();
      
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] 📝 STABILITY에 전송되는 프롬프트');
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint(prompt);
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] 프롬프트 길이: ${prompt.length} characters');

      File? outfitImage;
      if (maskImagePath != null && maskImagePath.isNotEmpty) {
        debugPrint('[Wardrobe] 🧩 Inpainting 호출 중...');
        debugPrint('  Base Image: $mannequinImagePath');
        debugPrint('  Mask Image: $maskImagePath');

        outfitImage = await _stability.inpainting(
          baseImagePath: mannequinImagePath,
          maskImagePath: maskImagePath,
          prompt: prompt,
          outputFormat: 'png',
        );
      } else {
        debugPrint('[Wardrobe] 🖼️  Image-to-Image 호출 중...');
        debugPrint('  Base Image: $mannequinImagePath');
        debugPrint('  Strength: 0.8');

        outfitImage = await _stability.imageToImage(
          baseImagePath: mannequinImagePath,
          prompt: prompt,
          strength: 0.8, // 높은 강도로 확실하게 옷 반영
          outputFormat: 'png',
        );
      }

      if (outfitImage == null) {
        _error = '이미지 생성 실패';
        notifyListeners();
        return null;
      }

      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('[Wardrobe] ✅ 마네킹 드레싱 완료!');
      debugPrint('[Wardrobe] ════════════════════════════════════════');
      debugPrint('  📍 결과 이미지 경로: ${outfitImage.path}');
      debugPrint('  📦 파일 크기: ${outfitImage.lengthSync()} bytes');
      debugPrint('  ⏱️  완료 시간: ${DateTime.now()}');
      debugPrint('[Wardrobe] ════════════════════════════════════════');

      _error = null;
      return outfitImage;
    } catch (e) {
      debugPrint('[Wardrobe] ❌ 마네킹 드레싱 예외: $e');
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 의류 상세 분석 (Gemini)
  ///
  /// 상의/하의/신발/악세사리를 각각 분석하고 하나의 ClothingAnalysis로 합친다.
  Future<ClothingAnalysis?> analyzeClothingDetailed(String imagePath) async {
    try {
      debugPrint('[Wardrobe] 🎨 상세 분석 시작: $imagePath');

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('[Wardrobe] ❌ 파일 없음: $imagePath');
        return null;
      }

      final topJson = await _analyzeAsMap(imagePath, 'analyze_top');
      final bottomJson = await _analyzeAsMap(imagePath, 'analyze_bottom');
      final shoesJson = await _analyzeAsMap(imagePath, 'analyze_shoes');
      final accessoriesJson = await _analyzeAsList(imagePath, 'analyze_accessories');

      final top = topJson != null ? _toClothingPart(topJson, fallbackType: 'top') : null;
      final bottom = bottomJson != null ? _toClothingPart(bottomJson, fallbackType: 'bottom') : null;
      final shoes = shoesJson != null ? _toClothingPart(shoesJson, fallbackType: 'shoes') : null;
      final accessories = accessoriesJson
          .map(_toAccessoryPart)
          .whereType<AccessoryAnalysis>()
          .toList();

      if (top == null && bottom == null && shoes == null && accessories.isEmpty) {
        debugPrint('[Wardrobe] ❌ 유효한 분석 결과 없음');
        return null;
      }

      return ClothingAnalysis(
        top: top,
        bottom: bottom,
        shoes: shoes,
        accessories: accessories,
      );
    } catch (e) {
      debugPrint('[Wardrobe] ❌ 분석 예외: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _analyzeAsMap(String imagePath, String promptKey) async {
    final raw = await _gemini.analyzeImage(imagePath, promptKey);
    if (raw == null) {
      debugPrint('[Wardrobe] ❌ $promptKey 분석 실패(null)');
      return null;
    }

    try {
      final decoded = _decodeGeminiJson(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
        return decoded.first as Map<String, dynamic>;
      }
    } catch (_) {
      // fallback below
    }

    final fallback = _inferClothingMapFromText(raw, promptKey);
    if (fallback != null) {
      debugPrint('[Wardrobe] ⚠️ $promptKey JSON 파싱 실패, 텍스트 fallback 사용');
      return fallback;
    }

    debugPrint('[Wardrobe] ❌ $promptKey JSON 형식 불일치');
    return null;
  }

  Future<List<Map<String, dynamic>>> _analyzeAsList(String imagePath, String promptKey) async {
    final raw = await _gemini.analyzeImage(imagePath, promptKey);
    if (raw == null) {
      debugPrint('[Wardrobe] ❌ $promptKey 분석 실패(null)');
      return const [];
    }

    try {
      final decoded = _decodeGeminiJson(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      if (decoded is Map<String, dynamic>) {
        return [decoded];
      }
    } catch (_) {
      // fallback below
    }

    final fallback = _inferAccessoriesFromText(raw);
    if (fallback.isNotEmpty) {
      debugPrint('[Wardrobe] ⚠️ $promptKey JSON 파싱 실패, 텍스트 fallback 사용');
      return fallback;
    }

    debugPrint('[Wardrobe] ❌ $promptKey JSON 형식 불일치');
    return const [];
  }

  dynamic _decodeGeminiJson(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    dynamic tryDecode(String input) {
      try {
        return jsonDecode(input);
      } catch (e) {
        debugPrint('[Wardrobe] JSON decode attempt failed: $e');
        return null;
      }
    }

    final direct = tryDecode(cleaned);
    if (direct != null) return direct;

    final noTrailingComma = cleaned.replaceFirst(RegExp(r',\\s*$'), '');
    final directNoComma = tryDecode(noTrailingComma);
    if (directNoComma != null) return directNoComma;

    if (noTrailingComma.startsWith('{') && noTrailingComma.contains('},')) {
      final wrapped = '[${noTrailingComma.replaceFirst(RegExp(r',\\s*$'), '')}]';
      final wrappedDecoded = tryDecode(wrapped);
      if (wrappedDecoded != null) return wrappedDecoded;
    }

    if (noTrailingComma.contains('{')) {
      final extractedObjects = RegExp(r'\{[\s\S]*?\}')
          .allMatches(noTrailingComma)
          .map((m) => m.group(0)!)
          .toList();

      if (extractedObjects.length > 1) {
        final objectList = extractedObjects
            .map(tryDecode)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (objectList.isNotEmpty) return objectList;
      }
    }

    final objectMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(noTrailingComma);
    if (objectMatch != null) {
      final objectDecoded = tryDecode(objectMatch.group(0)!);
      if (objectDecoded != null) return objectDecoded;
    }

    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(noTrailingComma);
    if (arrayMatch != null) {
      final arrayDecoded = tryDecode(arrayMatch.group(0)!);
      if (arrayDecoded != null) return arrayDecoded;
    }

    throw const FormatException('Gemini JSON 파싱 실패');
  }

  ClothingPartAnalysis _toClothingPart(Map<String, dynamic> json, {required String fallbackType}) {
    final sleevesValue = json['sleeves'];
    final sleeves = sleevesValue is Map<String, dynamic>
        ? (sleevesValue['type']?.toString() ?? sleevesValue['length']?.toString())
        : sleevesValue?.toString();

    final detailsSegments = <String>[
      json['details']?.toString() ?? '',
      json['silhouette']?.toString() ?? '',
      json['neckline']?.toString() ?? '',
      json['closure']?.toString() ?? '',
      json['waist']?.toString() ?? '',
      json['pockets']?.toString() ?? '',
      json['hem']?.toString() ?? '',
      json['fashionLevel']?.toString() ?? '',
      json['occasion']?.toString() ?? '',
    ].where((v) => v.trim().isNotEmpty).toSet().toList();

    return ClothingPartAnalysis(
      type: (json['type'] ?? json['garmentType'] ?? fallbackType).toString(),
      material: (json['material'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      colorHex: _normalizeHex(json['colorHex']?.toString()),
      pattern: (json['pattern'] ?? 'solid').toString(),
      fit: (json['fit'] ?? '').toString(),
      texture: (json['texture'] ?? '').toString(),
      sleeves: sleeves,
      length: json['length']?.toString(),
      details: detailsSegments.join(' / '),
      condition: json['condition']?.toString(),
    );
  }

  AccessoryAnalysis? _toAccessoryPart(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    if (type.trim().isEmpty) return null;

    return AccessoryAnalysis(
      type: type,
      material: (json['material'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      colorHex: _normalizeHex(json['colorHex']?.toString()),
      style: (json['style'] ?? '').toString(),
      details: (json['details'] ?? json['fashionLevel'] ?? '').toString(),
    );
  }

  String _normalizeHex(String? value) {
    if (value == null || value.trim().isEmpty) return '#000000';
    final v = value.trim();
    if (v.startsWith('#')) return v;
    return '#$v';
  }

  Map<String, dynamic>? _inferClothingMapFromText(String raw, String promptKey) {
    final text = raw.toLowerCase();

    String inferredType = '';
    if (promptKey == 'analyze_top') {
      inferredType = _containsAny(text, const ['jacket', 'blazer', 'coat'])
          ? 'jacket'
          : _containsAny(text, const ['sweater', 'knit'])
              ? 'sweater'
              : _containsAny(text, const ['shirt', 't-shirt', 'tee'])
                  ? 'shirt'
                  : 'top';
    } else if (promptKey == 'analyze_bottom') {
      inferredType = _containsAny(text, const ['jeans'])
          ? 'jeans'
          : _containsAny(text, const ['skirt'])
              ? 'skirt'
              : _containsAny(text, const ['pants', 'trouser'])
                  ? 'pants'
                  : 'bottom';
    } else if (promptKey == 'analyze_shoes') {
      inferredType = _containsAny(text, const ['boots'])
          ? 'boots'
          : _containsAny(text, const ['sneaker'])
              ? 'sneakers'
              : _containsAny(text, const ['loafer'])
                  ? 'loafers'
                  : _containsAny(text, const ['heel'])
                      ? 'heels'
                      : _containsAny(text, const ['shoe'])
                          ? 'shoes'
                          : 'shoes';
    } else {
      return null;
    }

    final inferredColor = _extractColor(text);
    return {
      'type': inferredType,
      'garmentType': inferredType,
      'material': _containsAny(text, const ['leather'])
          ? 'leather'
          : _containsAny(text, const ['wool'])
              ? 'wool'
              : _containsAny(text, const ['cotton'])
                  ? 'cotton'
                  : 'fabric',
      'color': inferredColor,
      'colorHex': '#000000',
      'pattern': 'solid',
      'fit': _containsAny(text, const ['oversized', 'loose'])
          ? 'relaxed'
          : _containsAny(text, const ['slim', 'tight'])
              ? 'slim'
              : 'regular',
      'texture': 'normal',
      'details': raw,
    };
  }

  List<Map<String, dynamic>> _inferAccessoriesFromText(String raw) {
    final text = raw.toLowerCase();
    final accessories = <Map<String, dynamic>>[];

    void maybeAdd(String type, List<String> keywords) {
      if (_containsAny(text, keywords)) {
        accessories.add({
          'type': type,
          'material': 'unknown',
          'color': _extractColor(text),
          'colorHex': '#000000',
          'style': 'casual',
          'details': raw,
        });
      }
    }

    maybeAdd('watch', const ['watch']);
    maybeAdd('belt', const ['belt']);
    maybeAdd('bag', const ['bag', 'backpack', 'purse']);
    maybeAdd('necklace', const ['necklace']);
    maybeAdd('ring', const ['ring']);
    maybeAdd('bracelet', const ['bracelet']);
    maybeAdd('earrings', const ['earring']);
    maybeAdd('hat', const ['hat', 'cap']);
    maybeAdd('scarf', const ['scarf']);
    maybeAdd('sunglasses', const ['sunglasses', 'glasses']);

    return accessories;
  }

  bool _containsAny(String text, List<String> words) {
    for (final word in words) {
      if (text.contains(word)) return true;
    }
    return false;
  }

  String _extractColor(String text) {
    const colors = [
      'black',
      'white',
      'gray',
      'grey',
      'navy',
      'blue',
      'brown',
      'beige',
      'green',
      'red',
      'pink',
      'purple',
      'yellow',
      'orange',
    ];

    for (final color in colors) {
      if (text.contains(color)) return color == 'grey' ? 'gray' : color;
    }
    return 'unknown';
  }

  Map<String, dynamic>? _normalizePeoplePayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final people = decoded['people'];
      if (people is List && people.isNotEmpty) {
        return {'people': people};
      }

      final label = decoded['label']?.toString().toLowerCase() ?? '';
      if (label.isNotEmpty) {
        return _payloadFromDetectedLabels([label]);
      }
    }

    if (decoded is List) {
      final labels = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => item['label']?.toString().toLowerCase() ?? '')
          .where((label) => label.isNotEmpty)
          .toList();

      if (labels.isNotEmpty) {
        return _payloadFromDetectedLabels(labels);
      }
    }

    return null;
  }

  Map<String, dynamic> _payloadFromDetectedLabels(List<String> labels) {
    final hasTop = labels.any((label) =>
        label.contains('top') || label.contains('shirt') || label.contains('jacket') || label.contains('coat') || label.contains('suit'));
    final hasBottom = labels.any((label) =>
        label.contains('bottom') || label.contains('pants') || label.contains('jeans') || label.contains('skirt') || label.contains('trouser'));
    final hasShoes = labels.any((label) =>
        label.contains('shoe') || label.contains('sneaker') || label.contains('boot') || label.contains('heel') || label.contains('loafer'));

    final person = <String, dynamic>{
      'id': 0,
      if (hasTop) 'topBounds': {'left': 0.2, 'top': 0.15, 'right': 0.8, 'bottom': 0.55},
      if (hasBottom) 'bottomBounds': {'left': 0.25, 'top': 0.5, 'right': 0.75, 'bottom': 0.9},
      if (hasShoes) 'shoesBounds': {'left': 0.3, 'top': 0.85, 'right': 0.7, 'bottom': 1.0},
      'accessories': <Map<String, dynamic>>[],
    };

    if (!hasTop && !hasBottom && !hasShoes) {
      return _fallbackPeoplePayload();
    }

    return {'people': [person]};
  }

  Map<String, dynamic> _fallbackPeoplePayload() {
    return {
      'people': [
        {
          'id': 0,
          'topBounds': {'left': 0.2, 'top': 0.15, 'right': 0.8, 'bottom': 0.55},
          'bottomBounds': {'left': 0.25, 'top': 0.5, 'right': 0.75, 'bottom': 0.9},
          'shoesBounds': {'left': 0.3, 'top': 0.85, 'right': 0.7, 'bottom': 1.0},
          'accessories': <Map<String, dynamic>>[],
        }
      ],
    };
  }

  // ============================================================================
  // v3.0 간소화 API
  // ============================================================================

  /// 옷 사진 추가: Gemini 분석 → SimpleClothingItem 저장
  Future<bool> addClothingItemSimple(String photoPath) async {
    _error = null;

    try {
      debugPrint('[Wardrobe] v3.0 간소화 추가 시작: $photoPath');

      // 1. Gemini로 간단 분석 (analyze_clothing_item_simple 프롬프트)
      final response = await _gemini.analyzeImage(
        photoPath,
        'analyze_clothing_item_simple',
      );

      if (response == null || response.trim().isEmpty) {
        _error = 'Gemini 분석 응답이 비어있습니다.';
        notifyListeners();
        return false;
      }

      debugPrint('[Wardrobe] Gemini 전체 응답:\n$response');
      debugPrint('[Wardrobe] 응답 길이: ${response.length}');

      // 2. JSON 파싱
      dynamic decoded;
      try {
        decoded = _decodeGeminiJson(response);
      } catch (e, st) {
        debugPrint('[Wardrobe] JSON 파싱 예외: $e');
        debugPrint('[Wardrobe] StackTrace: $st');
        _error = 'JSON 파싱 실패: $e';
        notifyListeners();
        return false;
      }

      if (decoded == null) {
        _error = 'Gemini 응답을 JSON으로 파싱할 수 없습니다.';
        notifyListeners();
        return false;
      }

      debugPrint('[Wardrobe] 파싱된 JSON: $decoded');

      // 3. SimpleClothingItem 생성
      final item = SimpleClothingItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        photoPath: photoPath,
        itemType: decoded['itemType'] as String? ?? 'unknown',
        description: decoded['description'] as String? ?? '',
        color: decoded['color'] as String? ?? '',
        colorHex: decoded['colorHex'] as String? ?? '#808080',
        style: decoded['style'] as String? ?? '',
        season: (decoded['season'] as List?)?.map((e) => e.toString()).toList() ?? [],
        occasion: (decoded['occasion'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.now(),
        memo: '',
      );

      debugPrint('[Wardrobe] SimpleClothingItem 생성: ${item.itemType} - ${item.description}');

      // 4. 리스트에 추가 & 저장
      _simpleItems.add(item);
      await _saveSimpleItems();

      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('[Wardrobe] addClothingItemSimple 실패: $e');
      debugPrint('[Wardrobe] StackTrace: $st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 전체 사진 기준 멀티 분류 저장
  Future<bool> addPhotoAnalysisFromImage(
    String imagePath, {
    required int personCount,
    int? selectedPersonId,
    required double brightnessScore,
    required double sharpnessScore,
    required double topCoverageScore,
    required double bottomCoverageScore,
  }) async {
    _error = null;

    try {
      final response = await _gemini.analyzeImage(imagePath, 'analyze_scene_items');
      if (response == null || response.trim().isEmpty) {
        _error = 'Gemini 분석 응답이 비어있습니다.';
        notifyListeners();
        return false;
      }

      final decoded = _decodeGeminiJson(response);
      final parsed = _parseSceneItems(decoded);
      if (parsed == null) {
        _error = '분석 결과를 해석할 수 없습니다.';
        notifyListeners();
        return false;
      }

      final normalizedItems = _applyCategoryCoverageRule(
        parsed.$1,
        topCoverageScore: topCoverageScore,
        bottomCoverageScore: bottomCoverageScore,
      );

      final record = PhotoAnalysisRecord(
        id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: imagePath,
        createdAt: DateTime.now(),
        personCount: personCount,
        selectedPersonId: selectedPersonId,
        brightnessScore: brightnessScore,
        sharpnessScore: sharpnessScore,
        topCoverageScore: topCoverageScore,
        bottomCoverageScore: bottomCoverageScore,
        items: normalizedItems,
        summary: parsed.$2,
      );

      _photoAnalyses.insert(0, record);
      await _savePhotoAnalyses();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  (List<AnalysisItemTag>, String)? _parseSceneItems(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final summary = (decoded['summary'] ?? '').toString();
    final rawItems = decoded['items'];
    if (rawItems is! List) {
      return (const [], summary);
    }

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) => AnalysisItemTag(
              category: _normalizeSceneCategory((item['category'] ?? '').toString()),
              label: (item['label'] ?? '').toString(),
              description: (item['description'] ?? '').toString(),
            ))
        .where((item) => item.category.isNotEmpty && item.label.isNotEmpty)
        .toList();

    return (items, summary);
  }

  List<AnalysisItemTag> _applyCategoryCoverageRule(
    List<AnalysisItemTag> items, {
    required double topCoverageScore,
    required double bottomCoverageScore,
  }) {
    return items.map((item) {
      if (item.category == 'top' && topCoverageScore < 0.90) {
        return AnalysisItemTag(
          category: item.category,
          label: item.label,
          description: item.description,
          eligibleForCategory: false,
          qualityStatus: 'insufficient_top_visibility',
        );
      }

      if (item.category == 'bottom' && bottomCoverageScore < 0.90) {
        return AnalysisItemTag(
          category: item.category,
          label: item.label,
          description: item.description,
          eligibleForCategory: false,
          qualityStatus: 'insufficient_bottom_visibility',
        );
      }

      return AnalysisItemTag(
        category: item.category,
        label: item.label,
        description: item.description,
        eligibleForCategory: true,
        qualityStatus: 'ok',
      );
    }).toList();
  }

  List<AnalysisItemTag> photoItemsByCategory(String category) {
    final normalizedCategory = category.trim().toLowerCase();
    final all = _photoAnalyses.expand((record) => record.items).toList();
    return all
        .where((item) => item.category == normalizedCategory && item.eligibleForCategory)
        .toList();
  }

  String _normalizeSceneCategory(String value) {
    final category = value.trim().toLowerCase();
    if (category == 'top' || category == 'bottom' || category == 'hat' || category == 'shoes' || category == 'accessory') {
      return category;
    }
    if (category.contains('상의') || category.contains('top') || category.contains('shirt') || category.contains('jacket')) {
      return 'top';
    }
    if (category.contains('하의') || category.contains('bottom') || category.contains('pants') || category.contains('skirt')) {
      return 'bottom';
    }
    if (category.contains('모자') || category.contains('hat') || category.contains('cap')) {
      return 'hat';
    }
    if (category.contains('신발') || category.contains('shoe') || category.contains('sneaker') || category.contains('boot')) {
      return 'shoes';
    }
    return 'accessory';
  }

  /// SimpleClothingItem 삭제
  Future<bool> removeSimpleItem(String id) async {
    try {
      _simpleItems.removeWhere((item) => item.id == id);
      await _saveSimpleItems();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// SimpleClothingItem 저장
  Future<void> _saveSimpleItems() async {
    try {
      final json = jsonEncode(_simpleItems.map((item) => item.toJson()).toList());
      await _storage.saveWardrobe('simple_items.json', json);
      debugPrint('[Wardrobe] SimpleClothingItem 저장 완료: ${_simpleItems.length}개');
    } catch (e) {
      debugPrint('[Wardrobe] SimpleClothingItem 저장 실패: $e');
      rethrow;
    }
  }

  /// SimpleClothingItem 로드
  Future<void> _loadSimpleItems() async {
    try {
      final json = await _storage.loadWardrobe('simple_items.json');
      if (json == null || json.trim().isEmpty) {
        debugPrint('[Wardrobe] simple_items.json 없음 또는 비어있음');
        return;
      }

      final List<dynamic> decoded = jsonDecode(json);
      _simpleItems = decoded.map((item) => SimpleClothingItem.fromJson(item)).toList();
      debugPrint('[Wardrobe] SimpleClothingItem 로드 완료: ${_simpleItems.length}개');
    } catch (e) {
      debugPrint('[Wardrobe] SimpleClothingItem 로드 실패: $e');
    }
  }

  /// OutfitCombination 추가
  Future<bool> addOutfitCombination(OutfitCombination combination) async {
    try {
      _outfitCombinations.add(combination);
      await _saveOutfitCombinations();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// OutfitCombination 삭제
  Future<bool> removeOutfitCombination(String id) async {
    try {
      _outfitCombinations.removeWhere((combo) => combo.id == id);
      await _saveOutfitCombinations();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// OutfitCombination 저장
  Future<void> _saveOutfitCombinations() async {
    try {
      final json = jsonEncode(_outfitCombinations.map((combo) => combo.toJson()).toList());
      await _storage.saveWardrobe('outfit_combinations.json', json);
      debugPrint('[Wardrobe] OutfitCombination 저장 완료: ${_outfitCombinations.length}개');
    } catch (e) {
      debugPrint('[Wardrobe] OutfitCombination 저장 실패: $e');
      rethrow;
    }
  }

  /// OutfitCombination 로드
  Future<void> _loadOutfitCombinations() async {
    try {
      final json = await _storage.loadWardrobe('outfit_combinations.json');
      if (json == null || json.trim().isEmpty) {
        debugPrint('[Wardrobe] outfit_combinations.json 없음 또는 비어있음');
        return;
      }

      final List<dynamic> decoded = jsonDecode(json);
      _outfitCombinations = decoded.map((combo) => OutfitCombination.fromJson(combo)).toList();
      debugPrint('[Wardrobe] OutfitCombination 로드 완료: ${_outfitCombinations.length}개');
    } catch (e) {
      debugPrint('[Wardrobe] OutfitCombination 로드 실패: $e');
    }
  }

  Future<void> _savePhotoAnalyses() async {
    try {
      final json = jsonEncode(_photoAnalyses.map((record) => record.toJson()).toList());
      await _storage.saveWardrobe('photo_analyses.json', json);
    } catch (e) {
      debugPrint('[Wardrobe] PhotoAnalysis 저장 실패: $e');
      rethrow;
    }
  }

  Future<void> _loadPhotoAnalyses() async {
    try {
      final json = await _storage.loadWardrobe('photo_analyses.json');
      if (json == null || json.trim().isEmpty) {
        return;
      }
      final list = jsonDecode(json) as List<dynamic>;
      _photoAnalyses = list
          .whereType<Map<String, dynamic>>()
          .map(PhotoAnalysisRecord.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[Wardrobe] PhotoAnalysis 로드 실패: $e');
    }
  }

  /// 사진 분석 기록 삭제 (사진 파일 + 분석 데이터)
  Future<bool> deletePhotoAnalysis(String recordId) async {
    try {
      final recordIndex = _photoAnalyses.indexWhere((r) => r.id == recordId);
      if (recordIndex < 0) return false;

      final record = _photoAnalyses[recordIndex];

      // 1. 사진 파일 삭제
      try {
        final imageFile = File(record.imagePath);
        if (imageFile.existsSync()) {
          await imageFile.delete();
        }
      } catch (e) {
        debugPrint('[Wardrobe] 사진 파일 삭제 실패: $e');
      }

      // 2. 분석 기록 삭제
      _photoAnalyses.removeAt(recordIndex);
      await _savePhotoAnalyses();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Wardrobe] 분석 기록 삭제 실패: $e');
      return false;
    }
  }
}

