import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/simple_clothing_item.dart';
import '../models/outfit_combination.dart';
import '../models/photo_analysis_record.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/grok_service.dart';
import '../services/config_service.dart';

class _PendingSecondStageContext {
  final String originalImagePath;
  final String analysisImagePath;
  final String generatedPreviewPath;
  final int personCount;
  final int? selectedPersonId;
  final double brightnessScore;
  final double sharpnessScore;
  final double topCoverageScore;
  final double bottomCoverageScore;
  final bool cropImmediately;

  const _PendingSecondStageContext({
    required this.originalImagePath,
    required this.analysisImagePath,
    required this.generatedPreviewPath,
    required this.personCount,
    required this.selectedPersonId,
    required this.brightnessScore,
    required this.sharpnessScore,
    required this.topCoverageScore,
    required this.bottomCoverageScore,
    required this.cropImmediately,
  });
}

/// 옷장 및 코디 기록 관리 Provider (v3.0 - 간소화 버전)
class WardrobeProvider extends ChangeNotifier {
  final StorageService _storage;
  final GeminiService _gemini;
  final GrokService? _grok;
  static const Set<String> _supportedSceneCategories = {
    'top',
    'outerwear',
    'bottom',
    'hat',
    'shoes',
    'accessory',
  };

  // v3.0 데이터
  List<SimpleClothingItem> _simpleItems = [];
  List<OutfitCombination> _outfitCombinations = [];
  List<PhotoAnalysisRecord> _photoAnalyses = [];

  bool _isLoading = false;
  String? _error;
  String? _lastReceivedImagePath;
  bool _lastFirstStageSuccess = false;
  bool _lastSecondStageSuccess = false;
  bool _lastSecondStageAttempted = false;
  String? _lastSecondStageError;
  String? _lastSecondStageFailureCode;
  List<String> _lastSecondStageSelectedCropPaths = <String>[];
  int _lastSecondStageExpectedBlocks = 0;
  int _lastSecondStageMatchedBlocks = 0;
  _PendingSecondStageContext? _pendingSecondStageContext;

  static const Duration _secondStageTimeout = Duration(seconds: 15);

  WardrobeProvider({
    required StorageService storage,
    required GeminiService gemini,
    GrokService? grok,
  }) : _storage = storage,
       _gemini = gemini,
       _grok = grok {
    _loadData();
  }

  // ===== Getters =====
  List<SimpleClothingItem> get simpleItems => _simpleItems;
  List<OutfitCombination> get outfitCombinations => _outfitCombinations;
  List<PhotoAnalysisRecord> get photoAnalyses => _photoAnalyses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastReceivedImagePath => _lastReceivedImagePath;
  bool get lastFirstStageSuccess => _lastFirstStageSuccess;
  bool get lastSecondStageSuccess => _lastSecondStageSuccess;
  bool get lastSecondStageAttempted => _lastSecondStageAttempted;
  String? get lastSecondStageError => _lastSecondStageError;
  String? get lastSecondStageFailureCode => _lastSecondStageFailureCode;
  List<String> get lastSecondStageSelectedCropPaths =>
      List.unmodifiable(_lastSecondStageSelectedCropPaths);
  int get lastSecondStageExpectedBlocks => _lastSecondStageExpectedBlocks;
  int get lastSecondStageMatchedBlocks => _lastSecondStageMatchedBlocks;
  bool get canRetrySecondStage =>
      _lastFirstStageSuccess &&
      !_lastSecondStageSuccess &&
      _pendingSecondStageContext != null;
  String? get generatedPreviewImagePath {
    final path = _lastReceivedImagePath?.trim();
    if (path == null || path.isEmpty) return null;
    if (_isGeneratedImagePath(path)) return path;
    return null;
  }

  void setLastReceivedImagePath(String path) {
    final normalized = path.trim();
    _lastReceivedImagePath = _isGeneratedImagePath(normalized)
        ? normalized
        : null;
    notifyListeners();
  }

  bool prepareSecondStageFromRecord(PhotoAnalysisRecord record) {
    final originalPath = record.imagePath.trim();
    final generatedPath = record.generatedImagePath.trim();

    if (originalPath.isEmpty || !File(originalPath).existsSync()) {
      _error = '원본 이미지가 없어 2차 분석을 준비할 수 없습니다.';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'SOURCE_NOT_FOUND';
      notifyListeners();
      return false;
    }

    final generatedExists =
        generatedPath.isNotEmpty && File(generatedPath).existsSync();
    final analysisPath = generatedExists ? generatedPath : originalPath;

    _error = null;
    _lastReceivedImagePath = generatedExists ? generatedPath : null;
    _lastFirstStageSuccess = true;
    _lastSecondStageSuccess = false;
    _lastSecondStageAttempted = false;
    _lastSecondStageError = null;
    _lastSecondStageFailureCode = null;
    _lastSecondStageSelectedCropPaths = <String>[];
    _pendingSecondStageContext = _PendingSecondStageContext(
      originalImagePath: originalPath,
      analysisImagePath: analysisPath,
      generatedPreviewPath: analysisPath,
      personCount: record.personCount,
      selectedPersonId: record.selectedPersonId,
      brightnessScore: record.brightnessScore,
      sharpnessScore: record.sharpnessScore,
      topCoverageScore: record.topCoverageScore,
      bottomCoverageScore: record.bottomCoverageScore,
      cropImmediately: true,
    );
    notifyListeners();
    return true;
  }

  void clearTransientAnalysisState() {
    _lastReceivedImagePath = null;
    _lastFirstStageSuccess = false;
    _lastSecondStageSuccess = false;
    _lastSecondStageAttempted = false;
    _lastSecondStageError = null;
    _lastSecondStageFailureCode = null;
    _lastSecondStageSelectedCropPaths = <String>[];
    _pendingSecondStageContext = null;
    _error = null;
    notifyListeners();
  }

  bool _isGeneratedImagePath(String path) {
    return path.contains('/grok_generated/') ||
        path.contains('\\grok_generated\\') ||
        path.contains('/wardrobe_grid_standardized/') ||
        path.contains('\\wardrobe_grid_standardized\\');
  }

  // ===== v3.0 Category Getters =====
  List<SimpleClothingItem> get simpleTopItems => getByCategory('top');
    List<SimpleClothingItem> get simpleOuterwearItems =>
      getByCategory('outerwear');
  List<SimpleClothingItem> get simpleBottomItems => getByCategory('bottom');
  List<SimpleClothingItem> get simpleHatItems => getByCategory('hat');
  List<SimpleClothingItem> get simpleShoeItems => getByCategory('shoes');
  List<SimpleClothingItem> get simpleAccessoryItems =>
      getByCategory('accessory');

  // ===== Getters by Category =====
  List<SimpleClothingItem> getByCategory(String category) {
    final targetCategory = _normalizeSceneCategory(category);
    return _simpleItems
        .where((item) => item.itemCategory == targetCategory)
        .toList();
  }

  // ===== Data Loading/Saving =====
  void _loadData() async {
    try {
      // photoAnalyses를 먼저 로드해야 구형 데이터 판단 가능
      await _loadPhotoAnalyses();
      await _loadSimpleItems();
      await _loadOutfitCombinations();
      notifyListeners();
    } catch (e) {
      debugPrint('[Wardrobe] 데이터 로드 실패: $e');
    }
  }

  Future<void> _loadSimpleItems() async {
    try {
      final jsonString = await _storage.loadWardrobe('simple_items');
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as List;
        _simpleItems = json
            .map(
              (item) =>
                  SimpleClothingItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        // 구형 데이터 감지: simple_items는 있는데 photoAnalyses는 없는 경우
        // (새로 추가된 데이터는 photoAnalyses에 먼저 저장되고 그 다음 itemCategory로 저장됨)
        final isLegacyData = _simpleItems.isNotEmpty && _photoAnalyses.isEmpty;

        if (isLegacyData) {
          debugPrint('[Wardrobe] ⚠️ 구형 데이터 감지 → 초기화');
          _simpleItems = [];
          await _saveSimpleItems();
        } else {
          final migrated = _migrateSimpleItemsForOuterwear();
          if (migrated) {
            await _saveSimpleItems();
          }

          for (final item in _simpleItems) {
            debugPrint(
              '[Wardrobe] ✅ 로드됨: ${item.itemType} → 카테고리=${item.itemCategory}',
            );
          }
        }

        debugPrint(
          '[Wardrobe] SimpleClothingItem 로드 완료: ${_simpleItems.length}개',
        );
      }
    } catch (e) {
      debugPrint('[Wardrobe] SimpleClothingItem 로드 실패: $e');
    }
  }

  Future<void> _loadPhotoAnalyses() async {
    try {
      final jsonString = await _storage.loadWardrobe('photo_analyses');
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as List;
        _photoAnalyses = json
            .map(
              (item) =>
                  PhotoAnalysisRecord.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        final migrated = _migratePhotoAnalysesForOuterwear();
        if (migrated) {
          await _savePhotoAnalyses();
        }

        debugPrint(
          '[Wardrobe] PhotoAnalysisRecord 로드 완료: ${_photoAnalyses.length}개',
        );
      }
    } catch (e) {
      debugPrint('[Wardrobe] PhotoAnalysisRecord 로드 실패: $e');
    }
  }

  Future<void> _loadOutfitCombinations() async {
    try {
      final jsonString = await _storage.loadWardrobe('outfit_combinations');
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as List;
        _outfitCombinations = json
            .map(
              (item) =>
                  OutfitCombination.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        debugPrint(
          '[Wardrobe] OutfitCombination 로드 완료: ${_outfitCombinations.length}개',
        );
      }
    } catch (e) {
      debugPrint('[Wardrobe] outfit_combinations.json 없음 또는 비어있음');
    }
  }

  Future<void> _saveSimpleItems() async {
    try {
      final jsonList = _simpleItems.map((item) => item.toJson()).toList();
      await _storage.saveWardrobe('simple_items', jsonEncode(jsonList));
      debugPrint(
        '[Wardrobe] SimpleClothingItem 저장 완료: ${_simpleItems.length}개',
      );
    } catch (e) {
      debugPrint('[Wardrobe] SimpleClothingItem 저장 실패: $e');
    }
  }

  Future<void> _savePhotoAnalyses() async {
    try {
      final jsonList = _photoAnalyses.map((item) => item.toJson()).toList();
      await _storage.saveWardrobe('photo_analyses', jsonEncode(jsonList));
      debugPrint(
        '[Wardrobe] PhotoAnalysisRecord 저장 완료: ${_photoAnalyses.length}개',
      );
    } catch (e) {
      debugPrint('[Wardrobe] PhotoAnalysisRecord 저장 실패: $e');
    }
  }

  Future<void> _saveOutfitCombinations() async {
    try {
      final jsonList = _outfitCombinations
          .map((item) => item.toJson())
          .toList();
      await _storage.saveWardrobe('outfit_combinations', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[Wardrobe] OutfitCombination 저장 실패: $e');
    }
  }

  bool _migrateSimpleItemsForOuterwear() {
    var changed = false;
    final migrated = <SimpleClothingItem>[];

    for (final item in _simpleItems) {
      final originalCategory = _normalizeSceneCategory(item.itemCategory);
      var nextCategory = originalCategory;

      if (originalCategory == 'top' &&
          _isOuterwearLikeText(
            [
              item.itemType,
              item.labelEn,
              item.labelKo,
              item.description,
              item.descriptionKo,
            ].join(' '),
          )) {
        nextCategory = 'outerwear';
      }

      if (nextCategory != item.itemCategory) {
        changed = true;
        migrated.add(item.copyWith(itemCategory: nextCategory));
      } else {
        migrated.add(item);
      }
    }

    if (changed) {
      _simpleItems = migrated;
      debugPrint('[Wardrobe] 🔄 simple_items outerwear 마이그레이션 적용');
    }

    return changed;
  }

  bool _migratePhotoAnalysesForOuterwear() {
    var changed = false;
    final migratedRecords = <PhotoAnalysisRecord>[];

    for (final record in _photoAnalyses) {
      var recordChanged = false;
      final migratedItems = <AnalysisItemTag>[];

      for (final item in record.items) {
        final normalizedCategory = _normalizeSceneCategory(item.category);
        var nextCategory = normalizedCategory;

        if (normalizedCategory == 'top' &&
            _isOuterwearLikeText(
              [
                item.label,
                item.labelEn,
                item.labelKo,
                item.description,
                item.descriptionKo ?? '',
              ].join(' '),
            )) {
          nextCategory = 'outerwear';
        }

        if (nextCategory != item.category) {
          recordChanged = true;
          migratedItems.add(_copyAnalysisItemWithCategory(item, nextCategory));
        } else {
          migratedItems.add(item);
        }
      }

      if (recordChanged) {
        changed = true;
        migratedRecords.add(
          PhotoAnalysisRecord(
            id: record.id,
            imagePath: record.imagePath,
            generatedImagePath: record.generatedImagePath,
            croppedImagePaths: record.croppedImagePaths,
            selectedCellIndexes: record.selectedCellIndexes,
            selectedRegions: record.selectedRegions,
            createdAt: record.createdAt,
            personCount: record.personCount,
            selectedPersonId: record.selectedPersonId,
            brightnessScore: record.brightnessScore,
            sharpnessScore: record.sharpnessScore,
            topCoverageScore: record.topCoverageScore,
            bottomCoverageScore: record.bottomCoverageScore,
            items: migratedItems,
            summary: record.summary,
          ),
        );
      } else {
        migratedRecords.add(record);
      }
    }

    if (changed) {
      _photoAnalyses = migratedRecords;
      debugPrint('[Wardrobe] 🔄 photo_analyses outerwear 마이그레이션 적용');
    }

    return changed;
  }

  AnalysisItemTag _copyAnalysisItemWithCategory(
    AnalysisItemTag item,
    String category,
  ) {
    return AnalysisItemTag(
      category: category,
      label: item.label,
      labelKey: item.labelKey,
      labelEn: item.labelEn,
      labelKo: item.labelKo,
      description: item.description,
      descriptionKo: item.descriptionKo,
      color: item.color,
      colorHex: item.colorHex,
      material: item.material,
      pattern: item.pattern,
      style: item.style,
      season: item.season,
      occasion: item.occasion,
      eligibleForCategory: item.eligibleForCategory,
      qualityStatus: item.qualityStatus,
    );
  }

  bool _isOuterwearLikeText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains(
      RegExp(
        r'outer|outerwear|jacket|coat|cardigan|blazer|parka|windbreaker|jumper|puffer|down|padding|trench|아우터|외투|자켓|재킷|코트|가디건|블레이저|점퍼|잠바|바람막이|패딩',
      ),
    );
  }

  // ===== SimpleClothingItem CRUD =====
  Future<bool> addClothingItemSimple(String photoPath) async {
    try {
      _isLoading = true;
      notifyListeners();

      final imageFile = File(photoPath);
      if (!imageFile.existsSync()) {
        _error = '사진 파일이 없습니다.';
        notifyListeners();
        return false;
      }

      final imageHash = await _calculateImageHash(photoPath);

      // 동일한 사진 중복 검사
      final alreadyExists = _simpleItems.any(
        (item) => item.imageHash == imageHash,
      );
      if (alreadyExists) {
        _error = '동일한 사진으로 이미 저장됨';
        debugPrint('[Wardrobe] ⚠️ 동일한 사진 중복: $photoPath');
        notifyListeners();
        return false;
      }

      final decoded = await _requestSceneItemsDecoded(
        photoPath,
        emptyErrorMessage: 'Gemini 응답이 비어있습니다.',
      );
      if (decoded == null) {
        notifyListeners();
        return false;
      }

      final normalizedItem = _extractSingleClothingItem(decoded);
      if (normalizedItem == null) {
        _error = '의류 아이템 파싱 실패';
        notifyListeners();
        return false;
      }

      final itemTypeForDescription =
          (normalizedItem['label_en'] as String?) ??
          (normalizedItem['itemType'] as String?) ??
          (normalizedItem['label'] as String?) ??
          (normalizedItem['category'] as String?) ??
          'unknown';
      final labelKoForDisplay =
          (normalizedItem['label_ko'] as String?) ??
          (normalizedItem['description_ko'] as String?) ??
          '';
      final labelKeyForStorage = _normalizeLabelKey(
        (normalizedItem['label_key'] as String?) ?? itemTypeForDescription,
      );
      final itemCategoryForDescription = _normalizeSceneCategory(
        normalizedItem['category'] as String? ?? 'accessory',
      );

      final descriptionEn = _ensureDetailedDescription(
        label: itemTypeForDescription,
        category: itemCategoryForDescription,
        description: (normalizedItem['description'] as String?) ?? '',
        color: (normalizedItem['color'] as String?) ?? '',
        material: (normalizedItem['material'] as String?) ?? '',
        pattern: (normalizedItem['pattern'] as String?) ?? '',
        style: (normalizedItem['style'] as String?) ?? '',
        season: _toStringList(normalizedItem['season']),
        occasion: _toStringList(normalizedItem['occasion']),
      );

      final item = SimpleClothingItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        photoPath: photoPath,
        imageHash: imageHash,
        itemType: itemTypeForDescription,
        labelKey: labelKeyForStorage,
        labelEn: itemTypeForDescription,
        labelKo: labelKoForDisplay,
        itemCategory: itemCategoryForDescription,
        description: descriptionEn,
        descriptionKo:
            (normalizedItem['description_ko'] as String?) ?? descriptionEn,
        color: normalizedItem['color'] as String? ?? '',
        colorHex: _validateColorHex(
          normalizedItem['colorHex'] as String? ?? '#808080',
        ),
        material: normalizedItem['material'] as String? ?? '',
        pattern: normalizedItem['pattern'] as String? ?? 'Solid',
        style: normalizedItem['style'] as String? ?? '',
        season: _resolveSeason(
          rawSeason: normalizedItem['season'],
          itemType:
              (normalizedItem['itemType'] as String?) ??
              (normalizedItem['label'] as String?) ??
              '',
          description:
              (normalizedItem['description'] as String?) ??
              (normalizedItem['description_ko'] as String?) ??
              '',
          material: normalizedItem['material'] as String?,
          style: normalizedItem['style'] as String?,
        ),
        occasion:
            (normalizedItem['occasion'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt: DateTime.now(),
        memo: '',
      );

      debugPrint(
        '[Wardrobe] ✅ 단일 아이템 추가: "${item.itemType}" → itemCategory="${item.itemCategory}"',
      );

      _simpleItems.add(item);
      await _saveSimpleItems();

      notifyListeners();
      return true;
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[Wardrobe] addClothingItemSimple 실패: $e');
      debugPrint('[Wardrobe] StackTrace: $st');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeSimpleItem(String id) async {
    try {
      final itemToRemove = _simpleItems.firstWhere((item) => item.id == id);
      final targetPath = itemToRemove.photoPath.trim();
      debugPrint(
        '[Wardrobe] 🗑️ SimpleClothingItem 삭제: id=$id, description=${itemToRemove.description}',
      );

      _simpleItems.removeWhere((item) => item.id == id);

      // 관련 분석 데이터 동기화: 크롭 경로/원본 경로 매칭 항목 제거
      _unlinkPhotoAnalysisByPath(targetPath);

      await Future.wait([_saveSimpleItems(), _savePhotoAnalyses()]);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Wardrobe] ❌ SimpleClothingItem 삭제 실패: $e');
      notifyListeners();
      return false;
    }
  }

  void _unlinkPhotoAnalysisByPath(String targetPath) {
    if (targetPath.isEmpty) return;

    final updatedRecords = <PhotoAnalysisRecord>[];
    for (final record in _photoAnalyses) {
      if (record.imagePath.trim() == targetPath) {
        continue;
      }

      final keepIndexes = <int>[];
      for (var i = 0; i < record.croppedImagePaths.length; i++) {
        final cropPath = record.croppedImagePaths[i].trim();
        if (cropPath != targetPath) {
          keepIndexes.add(i);
        }
      }

      if (keepIndexes.length == record.croppedImagePaths.length) {
        updatedRecords.add(record);
        continue;
      }

      final nextCroppedPaths = keepIndexes
          .where((i) => i >= 0 && i < record.croppedImagePaths.length)
          .map((i) => record.croppedImagePaths[i])
          .toList(growable: false);
      final nextItems = keepIndexes
          .where((i) => i >= 0 && i < record.items.length)
          .map((i) => record.items[i])
          .toList(growable: false);
      final nextSelectedCells = keepIndexes
          .where((i) => i >= 0 && i < record.selectedCellIndexes.length)
          .map((i) => record.selectedCellIndexes[i])
          .toList(growable: false);
      final nextSelectedRegions = keepIndexes
          .where((i) => i >= 0 && i < record.selectedRegions.length)
          .map((i) => record.selectedRegions[i])
          .toList(growable: false);

      if (nextCroppedPaths.isEmpty && nextItems.isEmpty) {
        continue;
      }

      updatedRecords.add(
        PhotoAnalysisRecord(
          id: record.id,
          imagePath: record.imagePath,
          generatedImagePath: record.generatedImagePath,
          croppedImagePaths: nextCroppedPaths,
          selectedCellIndexes: nextSelectedCells,
          selectedRegions: nextSelectedRegions,
          createdAt: record.createdAt,
          personCount: record.personCount,
          selectedPersonId: record.selectedPersonId,
          brightnessScore: record.brightnessScore,
          sharpnessScore: record.sharpnessScore,
          topCoverageScore: record.topCoverageScore,
          bottomCoverageScore: record.bottomCoverageScore,
          items: nextItems,
          summary: record.summary,
        ),
      );
    }

    _photoAnalyses = updatedRecords;
  }

  // ===== Photo Analysis =====
  Future<bool> addPhotoAnalysisFromImage(
    String imagePath, {
    required int personCount,
    int? selectedPersonId,
    double brightnessScore = 0.85,
    double sharpnessScore = 0.90,
    double topCoverageScore = 1.0,
    double bottomCoverageScore = 1.0,
    bool cropImmediately = false,
    bool generatePreviewImage = true,
    bool runSecondStageAutomatically = true,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _lastFirstStageSuccess = false;
      _lastSecondStageSuccess = false;
      _lastSecondStageAttempted = false;
      _lastSecondStageError = null;
      _lastSecondStageFailureCode = null;
      _lastSecondStageSelectedCropPaths = <String>[];
      _pendingSecondStageContext = null;
      notifyListeners();

      debugPrint('[Wardrobe] 📸 addPhotoAnalysisFromImage 시작: $imagePath');
      _lastReceivedImagePath = null;

      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        _error = '이미지 파일 없음';
        notifyListeners();
        return false;
      }

      // 동일한 사진 중복 검사
      final imageHash = await _calculateImageHash(imagePath);
      final alreadyAnalyzed = _photoAnalyses.any((p) {
        // imagePath가 같거나 imageHash가 같으면 동일 사진
        return p.imagePath == imagePath ||
            _simpleItems.any((item) => item.imageHash == imageHash);
      });

      if (alreadyAnalyzed) {
        _error = '동일한 사진으로 이미 분석됨';
        debugPrint('[Wardrobe] ⚠️ 동일한 사진 중복: $imagePath');
        notifyListeners();
        return false;
      }

      File? generatedPreviewFile;
      String analysisImagePath = imagePath;

      if (generatePreviewImage) {
        final generatedPreview = await _requestGeneratedPreviewImage(
          sourceImagePath: imagePath,
          items: const <AnalysisItemTag>[],
          summary: '',
        );
        if (generatedPreview != null) {
          generatedPreviewFile = generatedPreview;
          analysisImagePath = generatedPreview.path;
          _lastReceivedImagePath = generatedPreview.path;
          _lastFirstStageSuccess = true;
          _lastSecondStageSuccess = false;
          _lastSecondStageError = null;
          _pendingSecondStageContext = _PendingSecondStageContext(
            originalImagePath: imagePath,
            analysisImagePath: analysisImagePath,
            generatedPreviewPath: generatedPreview.path,
            personCount: personCount,
            selectedPersonId: selectedPersonId,
            brightnessScore: brightnessScore,
            sharpnessScore: sharpnessScore,
            topCoverageScore: topCoverageScore,
            bottomCoverageScore: bottomCoverageScore,
            cropImmediately: cropImmediately,
          );
          debugPrint('[Wardrobe] ✅ 생성 이미지 표시 경로 적용: ${generatedPreview.path}');
          notifyListeners();
        } else {
          _error = '사진에서 아이템을 추출하지 못했습니다.';
          _lastFirstStageSuccess = false;
          _lastSecondStageSuccess = false;
          _lastSecondStageAttempted = false;
          _lastSecondStageError = _error;
          _lastSecondStageFailureCode = 'FIRST_STAGE_FAIL';
          _pendingSecondStageContext = null;
          debugPrint('[Wardrobe] ❌ Grok 1차 실패로 파이프라인 중단');
          notifyListeners();
          return false;
        }
      } else {
        debugPrint('[Wardrobe] ⏭️ 생성 이미지 요청 비활성화(generatePreviewImage=false)');
      }

      if (!runSecondStageAutomatically && _pendingSecondStageContext != null) {
        debugPrint('[Wardrobe] ⏸️ 1차 완료 후 2차 대기(수동 실행)');
        notifyListeners();
        return true;
      }

      _lastSecondStageAttempted = true;

      final secondStageSuccess = await _runSecondStagePipeline(
        originalImagePath: imagePath,
        analysisImagePath: analysisImagePath,
        generatedPreviewPath: generatedPreviewFile?.path,
        personCount: personCount,
        selectedPersonId: selectedPersonId,
        brightnessScore: brightnessScore,
        sharpnessScore: sharpnessScore,
        topCoverageScore: topCoverageScore,
        bottomCoverageScore: bottomCoverageScore,
        cropImmediately: cropImmediately,
      );

      if (secondStageSuccess) {
        _lastSecondStageSuccess = true;
        _lastSecondStageError = null;
        _lastSecondStageFailureCode = null;
        _pendingSecondStageContext = null;
        notifyListeners();
        return true;
      }

      _lastSecondStageSuccess = false;
      _lastSecondStageError ??= _error ?? '2차 분석/크롭 실패';
      _lastSecondStageFailureCode ??= 'SECOND_STAGE_FAIL';
      notifyListeners();

      if (_lastFirstStageSuccess) {
        debugPrint('[Wardrobe] ⚠️ 1차 성공, 2차 실패 -> 부분 성공 처리');
        return true;
      }

      return false;
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[Wardrobe] ❌ addPhotoAnalysisFromImage 실패: $e');
      debugPrint('[Wardrobe] StackTrace: $st');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> retrySecondStageFromLastGenerated() async {
    return retrySecondStageFromLastGeneratedWithSelection();
  }

  Future<File?> regenerateFirstStagePreviewForPending() async {
    final context = _pendingSecondStageContext;
    if (context == null) {
      _error = '사진 다시 추출할 작업이 없습니다.';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'NO_PENDING_CONTEXT';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final generatedPreview = await _requestGeneratedPreviewImage(
        sourceImagePath: context.originalImagePath,
        items: const <AnalysisItemTag>[],
        summary: '',
      );

      if (generatedPreview == null || !generatedPreview.existsSync()) {
        _error = '사진 다시 추출 실패';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'FIRST_STAGE_REGEN_FAIL';
        notifyListeners();
        return null;
      }

      _lastReceivedImagePath = generatedPreview.path;
      _lastFirstStageSuccess = true;
      _lastSecondStageSuccess = false;
      _lastSecondStageAttempted = false;
      _lastSecondStageError = null;
      _lastSecondStageFailureCode = null;
      _lastSecondStageSelectedCropPaths = <String>[];
      _pendingSecondStageContext = _PendingSecondStageContext(
        originalImagePath: context.originalImagePath,
        analysisImagePath: generatedPreview.path,
        generatedPreviewPath: generatedPreview.path,
        personCount: context.personCount,
        selectedPersonId: context.selectedPersonId,
        brightnessScore: context.brightnessScore,
        sharpnessScore: context.sharpnessScore,
        topCoverageScore: context.topCoverageScore,
        bottomCoverageScore: context.bottomCoverageScore,
        cropImmediately: context.cropImmediately,
      );
      notifyListeners();
      return generatedPreview;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> retrySecondStageFromLastGeneratedWithSelection({
    Set<int>? selectedCellIndexes,
    List<Map<String, double>>? selectedRegions,
    String? replaceAnalysisId,
  }) async {
    final context = _pendingSecondStageContext;
    if (context == null) {
      _error = '재시도 가능한 2차 작업이 없습니다.';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'NO_PENDING_CONTEXT';
      notifyListeners();
      return false;
    }

    final hasSelection =
        (selectedCellIndexes?.isNotEmpty ?? false) ||
        (selectedRegions?.isNotEmpty ?? false);
    if (!hasSelection) {
      _error = '최소 1개 블럭을 선택한 후 2차 실행이 가능합니다.';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'NO_SELECTION';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      _lastSecondStageAttempted = true;
      _lastSecondStageSuccess = false;
      _lastSecondStageError = null;
      _lastSecondStageFailureCode = null;
      _lastSecondStageSelectedCropPaths = <String>[];
      _lastSecondStageExpectedBlocks = 0;
      _lastSecondStageMatchedBlocks = 0;
      notifyListeners();

      final success = await _runSecondStagePipeline(
        originalImagePath: context.originalImagePath,
        analysisImagePath: context.analysisImagePath,
        generatedPreviewPath: context.generatedPreviewPath,
        personCount: context.personCount,
        selectedPersonId: context.selectedPersonId,
        brightnessScore: context.brightnessScore,
        sharpnessScore: context.sharpnessScore,
        topCoverageScore: context.topCoverageScore,
        bottomCoverageScore: context.bottomCoverageScore,
        cropImmediately: context.cropImmediately,
        selectedCellIndexes: selectedCellIndexes,
        selectedRegions: selectedRegions,
        replaceAnalysisId: replaceAnalysisId,
      );

      _lastSecondStageSuccess = success;
      if (success) {
        _lastSecondStageError = null;
        _lastSecondStageFailureCode = null;
        _pendingSecondStageContext = null;
      } else {
        _lastSecondStageError ??= _error ?? '2차 분석/크롭 실패';
        _lastSecondStageFailureCode ??= 'SECOND_STAGE_FAIL';
      }
      notifyListeners();
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _runSecondStagePipeline({
    required String originalImagePath,
    required String analysisImagePath,
    required String? generatedPreviewPath,
    required int personCount,
    required int? selectedPersonId,
    required double brightnessScore,
    required double sharpnessScore,
    required double topCoverageScore,
    required double bottomCoverageScore,
    required bool cropImmediately,
    Set<int>? selectedCellIndexes,
    List<Map<String, double>>? selectedRegions,
    String? replaceAnalysisId,
  }) async {
    final normalizedReplaceAnalysisId = (replaceAnalysisId ?? '').trim();
    final isReplacingAnalysis = normalizedReplaceAnalysisId.isNotEmpty;

    PhotoAnalysisRecord? existingRecordForReplace;
    var existingRecordIndex = -1;
    var existingCropPathsForReplace = <String>{};
    if (isReplacingAnalysis) {
      existingRecordIndex = _photoAnalyses.indexWhere(
        (record) => record.id == normalizedReplaceAnalysisId,
      );
      if (existingRecordIndex < 0) {
        existingRecordIndex = _photoAnalyses.lastIndexWhere(
          (record) => record.imagePath.trim() == originalImagePath.trim(),
        );
      }
      if (existingRecordIndex >= 0) {
        existingRecordForReplace = _photoAnalyses[existingRecordIndex];
        existingCropPathsForReplace = existingRecordForReplace.croppedImagePaths
            .map((path) => path.trim())
            .where((path) => path.isNotEmpty)
            .toSet();
      } else {
        _error = '교체할 기존 분석 기록을 찾지 못했습니다.';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'REPLACE_TARGET_MISSING';
        debugPrint(
          '[Wardrobe] ❌ replace target missing: $normalizedReplaceAnalysisId',
        );
        return false;
      }
    }

    final normalizedSelectedCells = (selectedCellIndexes ?? <int>{})
        .where((index) => index >= 0 && index < 6)
        .toSet();
    final normalizedSelectedRegions =
        (selectedRegions ?? const <Map<String, double>>[])
            .map((raw) {
              final x = _clamp01(_parseDoubleOrZero(raw['x']));
              final y = _clamp01(_parseDoubleOrZero(raw['y']));
              final w = _clamp01(_parseDoubleOrZero(raw['width']));
              final h = _clamp01(_parseDoubleOrZero(raw['height']));
              final clampedW = _clamp01((x + w) > 1 ? (1 - x) : w);
              final clampedH = _clamp01((y + h) > 1 ? (1 - y) : h);
              return <String, double>{
                'x': x,
                'y': y,
                'width': clampedW,
                'height': clampedH,
              };
            })
            .where((rect) => rect['width']! > 0 && rect['height']! > 0)
            .toList(growable: false);

    List<AnalysisItemTag> normalizedItems = const <AnalysisItemTag>[];
    List<String?>? extractedPhotoPaths;
    String summary = '';
    File? generatedPreviewFile =
        (generatedPreviewPath ?? '').trim().isNotEmpty &&
            File(generatedPreviewPath!.trim()).existsSync()
        ? File(generatedPreviewPath.trim())
        : null;

    if (normalizedSelectedRegions.isNotEmpty) {
      final analyzed = await _analyzeSelectedRegionsForSecondStage(
        sourceImagePath: analysisImagePath,
        selectedRegions: normalizedSelectedRegions,
      );
      if (analyzed == null) {
        return false;
      }

      final regionItems = analyzed.$1;
      summary = analyzed.$2;
      extractedPhotoPaths = analyzed.$3.cast<String?>();

      normalizedItems = _applyCategoryCoverageRule(
        regionItems,
        topCoverageScore: topCoverageScore,
        bottomCoverageScore: bottomCoverageScore,
      );
    } else {
      dynamic decoded;
      try {
        decoded = await _requestSceneItemsDecoded(
          analysisImagePath,
          emptyErrorMessage: '분석 응답이 비어있습니다.',
          promptKey: 'analyze_scene_items_en',
        ).timeout(_secondStageTimeout);
      } on TimeoutException {
        _error = '2차 분석 시간이 초과되었습니다.';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'TIMEOUT';
        debugPrint(
          '[Wardrobe] ⏱️ 2차 분석 타임아웃(${_secondStageTimeout.inSeconds}s)',
        );
        return false;
      }

      if (decoded == null) {
        _lastSecondStageError = _error ?? '2차 분석 실패';
        _lastSecondStageFailureCode = 'ANALYZE_EMPTY';
        return false;
      }
      debugPrint('[Wardrobe] 📸 SceneItems JSON 디코딩 완료');

      final parsed = _parseSceneItems(decoded);
      if (parsed == null) {
        _error = '아이템 파싱 실패';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'PARSE_FAIL';
        debugPrint('[Wardrobe] ❌ _parseSceneItems 실패');
        return false;
      }

      final (items, parsedSummary) = parsed;
      summary = parsedSummary;

      final hasSelectionFilter = normalizedSelectedCells.isNotEmpty;
      final selectedItemIndexes = _resolveSelectedItemIndexesFromDecoded(
        decoded: decoded,
        itemCount: items.length,
        selectedCellIndexes: normalizedSelectedCells,
        selectedRegions: const <Map<String, double>>[],
      );
      if (hasSelectionFilter && selectedItemIndexes.isEmpty) {
        _error = '선택한 셀에 해당하는 아이템이 없습니다.';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'NO_MATCH';
        debugPrint(
          '[Wardrobe][CropTrace] ❌ 선택 셀에 매칭되는 아이템 없음: cells=$normalizedSelectedCells',
        );
        return false;
      }

      final filteredItems = selectedItemIndexes
          .map((index) => items[index])
          .toList(growable: false);

      normalizedItems = _applyCategoryCoverageRule(
        filteredItems,
        topCoverageScore: topCoverageScore,
        bottomCoverageScore: bottomCoverageScore,
      );

      if (cropImmediately) {
        final cellBasedPaths = await _extractCellCropPathsFromDecoded(
          imagePath: analysisImagePath,
          decoded: decoded,
          maxCount: 6,
        );

        final cellBasedValidCount = cellBasedPaths
            .where((path) => (path ?? '').trim().isNotEmpty)
            .length;
        debugPrint(
          '[Wardrobe][CropTrace] bbox crop result: valid=$cellBasedValidCount/${cellBasedPaths.length}',
        );

        final hasCellBasedPath = cellBasedPaths.any(
          (path) => (path ?? '').trim().isNotEmpty,
        );

        if (!hasCellBasedPath) {
          _error = 'bbox 셀 좌표 크롭 실패';
          _lastSecondStageError = _error;
          _lastSecondStageFailureCode = 'BBOX_CROP_FAIL';
          debugPrint('[Wardrobe][CropTrace] ❌ bbox crop failed (no fallback)');
          return false;
        }
        debugPrint('[Wardrobe][CropTrace] ✅ bbox crop selected');

        extractedPhotoPaths = selectedItemIndexes
            .map((index) {
              if (index < 0 || index >= cellBasedPaths.length) return null;
              final path = (cellBasedPaths[index] ?? '').trim();
              return path.isEmpty ? null : path;
            })
            .toList(growable: false);
      }
    }

    if (cropImmediately) {
      if (extractedPhotoPaths == null) {
        _error = '크롭 결과를 생성하지 못했습니다.';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'EMPTY_CROP';
        return false;
      }

      final hasValidCrop = extractedPhotoPaths.any(
        (path) => (path ?? '').trim().isNotEmpty,
      );
      final assignedValidCount = extractedPhotoPaths
          .where((path) => (path ?? '').trim().isNotEmpty)
          .length;
      debugPrint(
        '[Wardrobe][CropTrace] assigned paths: valid=$assignedValidCount/${normalizedItems.length}, selected_cells=$normalizedSelectedCells, selected_regions=${normalizedSelectedRegions.length}',
      );
      if (!hasValidCrop) {
        _error = normalizedSelectedRegions.isNotEmpty
            ? '선택 영역 기준 크롭 결과 없음'
            : 'bbox 셀 좌표 크롭 결과 없음';
        _lastSecondStageError = _error;
        _lastSecondStageFailureCode = 'EMPTY_CROP';
        debugPrint('[Wardrobe] ❌ 분리 실패: ${_error ?? '크롭 결과 없음'}');
        return false;
      }
      debugPrint('[Wardrobe][CropTrace] ℹ️ 선택 기준 크롭 성공으로 1차 이미지 유지(정규 합성 생략)');
    }

    final normalizedCroppedPaths = (extractedPhotoPaths ?? const <String?>[])
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    final effectiveItems = normalizedItems;
    final effectiveCroppedPaths = normalizedCroppedPaths;
    final effectiveExtractedPhotoPaths = extractedPhotoPaths;
    final effectiveSelectedCellIndexes = normalizedSelectedCells.toList()..sort();
    final effectiveSelectedRegions = normalizedSelectedRegions;
    final replacedOldCropPaths = existingCropPathsForReplace;

    final record = PhotoAnalysisRecord(
      id: isReplacingAnalysis
          ? normalizedReplaceAnalysisId
          : 'photo_${DateTime.now().millisecondsSinceEpoch}',
      imagePath: originalImagePath,
      generatedImagePath:
          generatedPreviewFile?.path ?? generatedPreviewPath ?? '',
      croppedImagePaths: effectiveCroppedPaths,
      selectedCellIndexes: effectiveSelectedCellIndexes,
      selectedRegions: effectiveSelectedRegions
          .map(
            (region) => <String, double>{
              'x': _clamp01(_parseDoubleOrZero(region['x'])),
              'y': _clamp01(_parseDoubleOrZero(region['y'])),
              'width': _clamp01(_parseDoubleOrZero(region['width'])),
              'height': _clamp01(_parseDoubleOrZero(region['height'])),
            },
          )
          .toList(growable: false),
      createdAt: DateTime.now(),
      personCount: personCount,
      selectedPersonId: selectedPersonId,
      brightnessScore: brightnessScore,
      sharpnessScore: sharpnessScore,
      topCoverageScore: topCoverageScore,
      bottomCoverageScore: bottomCoverageScore,
      items: effectiveItems,
      summary: summary,
    );
    _lastSecondStageSelectedCropPaths = normalizedCroppedPaths;

    debugPrint('[Wardrobe] 📸 addItemsFromAnalysis 호출 시작...');
    final success = await addItemsFromAnalysis(
      record,
      extractedPhotoPaths: effectiveExtractedPhotoPaths,
      allowSameImageHash: isReplacingAnalysis,
      ignoreDuplicatePhotoPaths: replacedOldCropPaths,
    );

    if (!success) {
      _lastSecondStageFailureCode ??= 'SAVE_ZERO';
      debugPrint('[Wardrobe] ❌ addItemsFromAnalysis 실패');
      return false;
    }

    if (isReplacingAnalysis && existingRecordForReplace != null) {
      if (existingCropPathsForReplace.isNotEmpty) {
        _simpleItems.removeWhere(
          (item) => existingCropPathsForReplace.contains(item.photoPath.trim()),
        );
        await _saveSimpleItems();
      }

      if (existingRecordIndex >= 0 &&
          existingRecordIndex < _photoAnalyses.length) {
        _photoAnalyses.removeAt(existingRecordIndex);
        _photoAnalyses.insert(existingRecordIndex, record);
      } else {
        _photoAnalyses.removeWhere((entry) => entry.id == record.id);
        _photoAnalyses.add(record);
      }
    } else {
      _photoAnalyses.add(record);
    }

    await _savePhotoAnalyses();
    debugPrint('[Wardrobe] 📸 _photoAnalyses 저장 완료');

    return true;
  }

  Future<(List<AnalysisItemTag>, String, List<String>)?>
  _analyzeSelectedRegionsForSecondStage({
    required String sourceImagePath,
    required List<Map<String, double>> selectedRegions,
  }) async {
    final expectedBlockCount = selectedRegions.length;
    _lastSecondStageExpectedBlocks = expectedBlockCount;
    _lastSecondStageMatchedBlocks = 0;
    final exactCrops = await _extractExactRegionCropPaths(
      imagePath: sourceImagePath,
      selectedRegions: selectedRegions,
    );
    final validCrops = exactCrops
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    _lastSecondStageSelectedCropPaths = validCrops;

    if (validCrops.isEmpty) {
      _error = '선택 영역 기준 크롭 결과 없음';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'EMPTY_CROP';
      return null;
    }

    if (validCrops.length < expectedBlockCount) {
      debugPrint(
        '[Wardrobe][CropTrace] ⚠️ 크롭 일부 누락 상태로 계속 진행: selected=$expectedBlockCount, valid=${validCrops.length}',
      );
    }

    final analyzedItems = <AnalysisItemTag>[];
    final analyzedPaths = <String>[];
    final summaryParts = <String>[];
    var matchedBlockCount = 0;

    for (var cropIndex = 0; cropIndex < validCrops.length; cropIndex++) {
      final cropPath = validCrops[cropIndex];
      dynamic decoded;
      try {
        decoded = await _requestSceneItemsDecoded(
          cropPath,
          emptyErrorMessage: '선택 영역 분석 응답이 비어있습니다.',
          promptKey: 'analyze_scene_items_en',
        ).timeout(_secondStageTimeout);
      } on TimeoutException {
        debugPrint(
          '[Wardrobe][CropTrace] ⏱️ 선택 블럭 분석 타임아웃(index=$cropIndex, sec=${_secondStageTimeout.inSeconds})',
        );
        continue;
      }

      if (decoded == null) {
        debugPrint('[Wardrobe][CropTrace] ⚠️ 선택 블럭 분석 응답 없음(index=$cropIndex)');
        continue;
      }
      final parsed = _parseSceneItems(decoded);
      if (parsed == null) {
        debugPrint('[Wardrobe][CropTrace] ⚠️ 선택 블럭 파싱 실패(index=$cropIndex)');
        continue;
      }
      final regionItems = parsed.$1;
      if (regionItems.isEmpty) {
        debugPrint('[Wardrobe][CropTrace] ℹ️ 선택 블럭 아이템 없음(index=$cropIndex)');
        continue;
      }
      matchedBlockCount++;
      _lastSecondStageMatchedBlocks = matchedBlockCount;

      final representativeItem = regionItems.first;
      analyzedItems.add(representativeItem);
      analyzedPaths.add(cropPath);
      debugPrint(
        '[Wardrobe][CropTrace] ✅ 선택 블럭 아이템 채택(index=$cropIndex, detected=${regionItems.length}, saved=1)',
      );

      final regionSummary = parsed.$2.trim();
      if (regionSummary.isNotEmpty) {
        summaryParts.add(regionSummary);
      }
    }

    if (analyzedItems.isEmpty) {
      _error = '선택 블럭 분석 결과 없음';
      _lastSecondStageError = _error;
      _lastSecondStageFailureCode = 'NO_MATCH';
      return null;
    }

    _lastSecondStageMatchedBlocks = matchedBlockCount;
    if (matchedBlockCount < expectedBlockCount) {
      debugPrint(
        '[Wardrobe][CropTrace] ⚠️ 부분 인식 저장 진행: selected=$expectedBlockCount, matched=$matchedBlockCount',
      );
    }

    final summary = summaryParts.join(' / ');
    return (analyzedItems, summary, analyzedPaths);
  }

  Future<List<String?>> _extractExactRegionCropPaths({
    required String imagePath,
    required List<Map<String, double>> selectedRegions,
  }) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return const <String?>[];

      final bytes = await file.readAsBytes();
      final source = img.decodeImage(bytes);
      if (source == null) return const <String?>[];

      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${appDir.path}/wardrobe_grid_parts');
      await outputDir.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final paths = <String?>[];
      for (var i = 0; i < selectedRegions.length; i++) {
        final region = selectedRegions[i];
        final xNorm = _clamp01(_parseDoubleOrZero(region['x']));
        final yNorm = _clamp01(_parseDoubleOrZero(region['y']));
        final wNorm = _clamp01(_parseDoubleOrZero(region['width']));
        final hNorm = _clamp01(_parseDoubleOrZero(region['height']));

        final x = (xNorm * source.width).round().clamp(0, source.width - 1);
        final y = (yNorm * source.height).round().clamp(0, source.height - 1);
        final w = (wNorm * source.width).round();
        final h = (hNorm * source.height).round();

        final safeW = min(w, source.width - x);
        final safeH = min(h, source.height - y);
        if (safeW <= 0 || safeH <= 0) {
          paths.add(null);
          continue;
        }

        final cropped = img.copyCrop(
          source,
          x: x,
          y: y,
          width: safeW,
          height: safeH,
        );

        final outputFile = File(
          '${outputDir.path}/grid_${timestamp}_region_$i.png',
        );
        await outputFile.writeAsBytes(img.encodePng(cropped), flush: true);
        paths.add(outputFile.path);
      }

      return paths;
    } catch (e) {
      debugPrint('[Wardrobe] ⚠️ 선택 블럭 직접 크롭 실패: $e');
      return const <String?>[];
    }
  }

  List<int> _resolveSelectedItemIndexesFromDecoded({
    required dynamic decoded,
    required int itemCount,
    required Set<int> selectedCellIndexes,
    required List<Map<String, double>> selectedRegions,
  }) {
    final allIndexes = List<int>.generate(itemCount, (index) => index);
    if (selectedCellIndexes.isEmpty && selectedRegions.isEmpty)
      return allIndexes;

    if (decoded is! Map<String, dynamic>) return const <int>[];
    final rawItems = decoded['items'];
    if (rawItems is! List) return const <int>[];

    final selectedIndexes = <int>[];
    for (var index = 0; index < itemCount; index++) {
      if (index >= rawItems.length) break;
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final bbox = raw['bounding_box'];
      if (bbox is! Map) continue;

      var matched = false;
      if (selectedRegions.isNotEmpty) {
        final center = _resolveBoundingBoxCenter(bbox);
        if (center != null) {
          for (final region in selectedRegions) {
            final x = region['x'] ?? 0;
            final y = region['y'] ?? 0;
            final w = region['width'] ?? 0;
            final h = region['height'] ?? 0;
            final right = x + w;
            final bottom = y + h;
            if (center.$1 >= x &&
                center.$1 <= right &&
                center.$2 >= y &&
                center.$2 <= bottom) {
              matched = true;
              break;
            }
          }
        }
      }

      if (!matched && selectedCellIndexes.isNotEmpty) {
        final cellIndex = _resolveCellIndexFromBoundingBox(bbox);
        if (cellIndex != null && selectedCellIndexes.contains(cellIndex)) {
          matched = true;
        }
      }

      if (matched) {
        selectedIndexes.add(index);
      }
    }

    return selectedIndexes;
  }

  int? _resolveCellIndexFromBoundingBox(Map bbox) {
    final x = _asNormalizedDouble(bbox['x']);
    final y = _asNormalizedDouble(bbox['y']);
    final w = _asNormalizedDouble(bbox['width']);
    final h = _asNormalizedDouble(bbox['height']);
    if (x == null || y == null || w == null || h == null) return null;

    final centerX = (x + (w / 2)).clamp(0.0, 0.999999);
    final centerY = (y + (h / 2)).clamp(0.0, 0.999999);
    final col = (centerX * 2).floor().clamp(0, 1);
    final row = (centerY * 3).floor().clamp(0, 2);
    return row * 2 + col;
  }

  (double, double)? _resolveBoundingBoxCenter(Map bbox) {
    final x = _asNormalizedDouble(bbox['x']);
    final y = _asNormalizedDouble(bbox['y']);
    final w = _asNormalizedDouble(bbox['width']);
    final h = _asNormalizedDouble(bbox['height']);
    if (x == null || y == null || w == null || h == null) return null;
    final centerX = _clamp01(x + (w / 2));
    final centerY = _clamp01(y + (h / 2));
    return (centerX, centerY);
  }

  Future<List<String?>> _extractCellCropPathsFromDecoded({
    required String imagePath,
    required dynamic decoded,
    required int maxCount,
  }) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return const [];

      final bytes = await file.readAsBytes();
      final source = img.decodeImage(bytes);
      if (source == null) return const [];

      final itemList =
          (decoded is Map<String, dynamic> && decoded['items'] is List)
          ? (decoded['items'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];
      if (itemList.isEmpty) return const [];

      final target = min(maxCount, itemList.length);
      final paths = <String?>[];
      var missingBoundingBoxCount = 0;
      var invalidBoundingBoxCount = 0;
      var invalidPixelSizeCount = 0;
      var emptyCellCount = 0;
      var savedCount = 0;

      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${appDir.path}/wardrobe_grid_parts');
      await outputDir.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < target; i++) {
        final item = itemList[i];
        final bboxRaw = item['bounding_box'];
        if (bboxRaw is! Map) {
          missingBoundingBoxCount++;
          paths.add(null);
          continue;
        }

        final xNorm = _asNormalizedDouble(bboxRaw['x']);
        final yNorm = _asNormalizedDouble(bboxRaw['y']);
        final wNorm = _asNormalizedDouble(bboxRaw['width']);
        final hNorm = _asNormalizedDouble(bboxRaw['height']);

        if (xNorm == null || yNorm == null || wNorm == null || hNorm == null) {
          invalidBoundingBoxCount++;
          paths.add(null);
          continue;
        }

        final x = (xNorm * source.width).round();
        final y = (yNorm * source.height).round();
        final w = (wNorm * source.width).round();
        final h = (hNorm * source.height).round();

        if (w <= 0 || h <= 0) {
          invalidPixelSizeCount++;
          paths.add(null);
          continue;
        }

        final safeX = x.clamp(0, source.width - 1);
        final safeY = y.clamp(0, source.height - 1);
        final safeW = min(w, source.width - safeX);
        final safeH = min(h, source.height - safeY);

        if (safeW <= 0 || safeH <= 0) {
          invalidPixelSizeCount++;
          paths.add(null);
          continue;
        }

        final cropped = img.copyCrop(
          source,
          x: safeX,
          y: safeY,
          width: safeW,
          height: safeH,
        );

        if (_isLikelyEmptyGridCell(cropped)) {
          emptyCellCount++;
          paths.add(null);
          continue;
        }

        final outputFile = File('${outputDir.path}/grid_${timestamp}_$i.png');
        await outputFile.writeAsBytes(img.encodePng(cropped), flush: true);
        paths.add(outputFile.path);
        savedCount++;
      }

      debugPrint(
        '[Wardrobe][CropTrace] bbox summary: target=$target, saved=$savedCount, missing_bbox=$missingBoundingBoxCount, invalid_bbox=$invalidBoundingBoxCount, invalid_size=$invalidPixelSizeCount, empty_cell=$emptyCellCount',
      );

      return paths;
    } catch (e) {
      debugPrint('[Wardrobe] ⚠️ 셀 좌표 기반 크롭 실패: $e');
      return const [];
    }
  }

  double? _asNormalizedDouble(dynamic value) {
    if (value == null) return null;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().trim());
    if (parsed == null) return null;
    if (parsed.isNaN || parsed.isInfinite) return null;
    if (parsed < 0 || parsed > 1) return null;
    return parsed;
  }

  Future<File?> _requestGeneratedPreviewImage({
    required String sourceImagePath,
    required List<AnalysisItemTag> items,
    required String summary,
  }) async {
    if (_grok?.isConfigured != true) {
      debugPrint('[Wardrobe] ⚠️ Grok 이미지 생성 스킵: API 미설정');
      return null;
    }

    final sourcePath = sourceImagePath.trim();
    if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
      debugPrint('[Wardrobe] ❌ 생성 스킵: 원본 이미지 경로가 유효하지 않음');
      return null;
    }

    final labels = items
        .map((item) => item.labelEn.isNotEmpty ? item.labelEn : item.label)
        .where((label) => label.trim().isNotEmpty)
        .take(8)
        .join(', ');

    final summaryText = summary.trim();
    final prompt = _buildExtractionPrompt(labels: labels);

    debugPrint('[Wardrobe] 🖼️ Grok 이미지 생성 요청 시작');
    debugPrint('[Wardrobe] 🖼️ Labels: $labels');
    debugPrint('[Wardrobe] 🖼️ Summary(${summaryText.length})');

    return _grok!.generateImageFromPrompt(
      prompt: prompt,
      sourceImagePath: sourcePath,
    );
  }

  Future<File?> requestGeneratedImageOnly({
    String? prompt,
    String? sourceImagePath,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _lastReceivedImagePath = null;
      notifyListeners();

      if (_grok?.isConfigured != true) {
        _error = '이미지 생성 기능이 준비되지 않았습니다. 설정을 확인해 주세요.';
        return null;
      }

      final sourcePath = (sourceImagePath ?? '').trim();
      if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
        _error = '업로드한 원본 이미지가 필요합니다.';
        debugPrint('[Wardrobe] ❌ 이미지 단건 생성 중단: sourceImagePath 없음/파일없음');
        return null;
      }

      final defaultPrompt = _buildExtractionPrompt();

      var resolvedPrompt = (prompt ?? '').trim().isNotEmpty
          ? prompt!.trim()
          : defaultPrompt;

      debugPrint('[Wardrobe] 🖼️ 이미지 단건 생성 요청 시작');
      debugPrint('[Wardrobe] 🖼️ Final Prompt(${resolvedPrompt.length})');
      final file = await _grok!.generateImageFromPrompt(
        prompt: resolvedPrompt,
        sourceImagePath: sourcePath,
      );
      if (file == null || !file.existsSync()) {
        _error = 'Grok 이미지 생성 실패';
        debugPrint('[Wardrobe] ❌ 이미지 단건 생성 실패');
        return null;
      }

      _lastReceivedImagePath = file.path;
      debugPrint('[Wardrobe] ✅ 이미지 단건 생성 성공: ${file.path}');
      return file;
    } catch (e) {
      _error = '이미지 생성 중 오류: $e';
      debugPrint('[Wardrobe] ❌ 이미지 단건 생성 예외: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addItemsFromAnalysis(
    PhotoAnalysisRecord record, {
    List<String?>? extractedPhotoPaths,
    bool allowSameImageHash = false,
    Set<String>? ignoreDuplicatePhotoPaths,
  }) async {
    try {
      debugPrint('[Wardrobe] 📊 addItemsFromAnalysis 시작');
      debugPrint(
        '[Wardrobe] 📊 PhotoAnalysisRecord - ID: ${record.id}, Items 개수: ${record.items.length}',
      );

      if (record.items.isEmpty) {
        debugPrint('[Wardrobe] ⚠️ record.items가 비어있음!');
        return false;
      }

      // 중복 이미지 확인: imageHash를 한 번만 계산하고 전체 사진 중복 체크
      final imageHash = await _calculateImageHash(record.imagePath);
      final photoAlreadyExists = _simpleItems.any(
        (existing) => existing.imageHash == imageHash,
      );

      if (photoAlreadyExists && !allowSameImageHash) {
        debugPrint('[Wardrobe] ⚠️ 이미 추가된 사진입니다 (imageHash 중복)');
        return false;
      }

      final normalizedIgnorePaths =
          (ignoreDuplicatePhotoPaths ?? const <String>{})
              .map((path) => path.trim())
              .where((path) => path.isNotEmpty)
              .toSet();

      int addedCount = 0;

      for (var index = 0; index < record.items.length; index++) {
        final item = record.items[index];
        final category = item.category;
        debugPrint(
          '[Wardrobe] 📊 아이템 파싱[$index]: category=$category, label=${item.label}',
        );

        // 중복 확인: 동일한 label + category 조합만 체크
        final duplicateExists = _simpleItems.any((existing) {
          if (normalizedIgnorePaths.contains(existing.photoPath.trim())) {
            return false;
          }
          final sameLabel =
              existing.description.toLowerCase() == item.label.toLowerCase();
          final sameCategory =
              existing.itemType.toLowerCase() == category.toLowerCase();
          return sameLabel && sameCategory;
        });

        if (duplicateExists) {
          debugPrint('[Wardrobe] ⚠️ 중복 아이템 스킵: ${item.label} ($category)');
          continue;
        }

        final normalizedCategory = _normalizeSceneCategory(category);
        final labelEn = item.labelEn.isNotEmpty ? item.labelEn : item.label;
        final partImagePath =
            (extractedPhotoPaths != null && index < extractedPhotoPaths.length)
            ? extractedPhotoPaths[index]
            : null;

        if (partImagePath == null || partImagePath.trim().isEmpty) {
          debugPrint('[Wardrobe] ⏭️ 크롭 이미지 없음으로 스킵: ${item.label}');
          continue;
        }

        final clothingItem = SimpleClothingItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
          photoPath: partImagePath,
          imageHash: imageHash,
          itemType: labelEn,
          labelKey: item.labelKey.isNotEmpty
              ? item.labelKey
              : _normalizeLabelKey(labelEn),
          labelEn: labelEn,
          labelKo: item.labelKo,
          itemCategory: normalizedCategory,
          description: item.description.isNotEmpty
              ? item.description
              : item.label,
          descriptionKo: item.descriptionKo ?? '',
          color: item.color ?? '',
          colorHex: item.colorHex ?? '#808080',
          material: item.material ?? '',
          pattern: item.pattern ?? 'Solid',
          style: item.style ?? '',
          season: _resolveSeason(
            rawSeason: item.season,
            itemType: item.label,
            description: item.description,
            material: item.material,
            style: item.style,
          ),
          occasion: item.occasion ?? ['캐주얼', '정장', '스포츠'],
          createdAt: DateTime.now(),
        );

        debugPrint(
          '[Wardrobe] ✅ 아이템 추가: "${item.label}" → image=${clothingItem.photoPath}',
        );

        _simpleItems.add(clothingItem);
        addedCount++;
      }

      debugPrint('[Wardrobe] 📊 총 추가된 아이템: $addedCount');
      debugPrint('[Wardrobe] 📊 현재 _simpleItems 개수: ${_simpleItems.length}');

      if (addedCount == 0) {
        _error = '크롭된 아이템이 없어 저장하지 않았습니다.';
        debugPrint('[Wardrobe] ❌ 저장된 크롭 아이템 없음');
        notifyListeners();
        return false;
      }

      await _saveSimpleItems();
      debugPrint('[Wardrobe] ✅ _saveSimpleItems 완료');

      notifyListeners();
      debugPrint('[Wardrobe] ✅ addItemsFromAnalysis 성공!');
      return true;
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[Wardrobe] ❌ 분석 항목 추가 실패: $e');
      debugPrint('[Wardrobe] Stack trace: $st');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removePhotoAnalysis(String analysisId) async {
    try {
      final record = _photoAnalyses.firstWhere((r) => r.id == analysisId);
      final imageHash = await _calculateImageHash(record.imagePath);

      debugPrint(
        '[Wardrobe] 🗑️ PhotoAnalysisRecord 삭제 시작: id=$analysisId, imagePath=${record.imagePath}',
      );

      // 사진 파일 삭제
      try {
        final file = File(record.imagePath);
        if (file.existsSync()) {
          await file.delete();
          debugPrint('[Wardrobe] 🗑️ 사진 파일 삭제됨: ${record.imagePath}');
        }
      } catch (e) {
        debugPrint('[Wardrobe] ⚠️ 사진 파일 삭제 실패: $e');
      }

      // 관련 SimpleClothingItem 삭제
      final itemsToRemove = _simpleItems
          .where(
            (item) =>
                item.photoPath == record.imagePath ||
                (imageHash.isNotEmpty && item.imageHash == imageHash),
          )
          .toList();
      for (final item in itemsToRemove) {
        _simpleItems.remove(item);
        debugPrint('[Wardrobe] 🗑️ 항목 삭제됨: ${item.description}');
      }
      debugPrint(
        '[Wardrobe] 🗑️ SimpleClothingItem 삭제: ${itemsToRemove.length}개',
      );

      // PhotoAnalysisRecord 삭제
      _photoAnalyses.removeWhere((r) => r.id == analysisId);

      if (itemsToRemove.isEmpty) {
        debugPrint(
          '[Wardrobe] 🗑️ PhotoAnalysisRecord 삭제 (항목 없음): $analysisId',
        );
      }

      await Future.wait([_saveSimpleItems(), _savePhotoAnalyses()]);

      debugPrint('[Wardrobe] ✅ PhotoAnalysisRecord 삭제 완료');
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Wardrobe] ❌ PhotoAnalysisRecord 삭제 실패: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeAnalyzedCropItem({
    required String analysisId,
    required String cropPath,
  }) async {
    try {
      final recordIndex = _photoAnalyses.indexWhere((r) => r.id == analysisId);
      if (recordIndex < 0) {
        _error = '분석 기록을 찾지 못했습니다.';
        notifyListeners();
        return false;
      }

      final targetPath = cropPath.trim();
      if (targetPath.isEmpty) {
        _error = '삭제할 경로가 비어있습니다.';
        notifyListeners();
        return false;
      }

      final record = _photoAnalyses[recordIndex];
      final cropIndex = record.croppedImagePaths.indexWhere(
        (path) => path.trim() == targetPath,
      );

      if (cropIndex < 0) {
        _error = '삭제할 항목을 찾지 못했습니다.';
        notifyListeners();
        return false;
      }

      final nextItems = [...record.items];
      if (cropIndex >= 0 && cropIndex < nextItems.length) {
        nextItems.removeAt(cropIndex);
      }

      final nextCroppedPaths = [...record.croppedImagePaths];
      nextCroppedPaths.removeAt(cropIndex);

      final nextSelectedCells = [...record.selectedCellIndexes];
      if (cropIndex >= 0 && cropIndex < nextSelectedCells.length) {
        nextSelectedCells.removeAt(cropIndex);
      }

      final nextSelectedRegions = [...record.selectedRegions];
      if (cropIndex >= 0 && cropIndex < nextSelectedRegions.length) {
        nextSelectedRegions.removeAt(cropIndex);
      }

      final updatedRecord = PhotoAnalysisRecord(
        id: record.id,
        imagePath: record.imagePath,
        generatedImagePath: record.generatedImagePath,
        croppedImagePaths: nextCroppedPaths,
        selectedCellIndexes: nextSelectedCells,
        selectedRegions: nextSelectedRegions,
        createdAt: record.createdAt,
        personCount: record.personCount,
        selectedPersonId: record.selectedPersonId,
        brightnessScore: record.brightnessScore,
        sharpnessScore: record.sharpnessScore,
        topCoverageScore: record.topCoverageScore,
        bottomCoverageScore: record.bottomCoverageScore,
        items: nextItems,
        summary: record.summary,
      );

      _photoAnalyses[recordIndex] = updatedRecord;
      _simpleItems.removeWhere((item) => item.photoPath.trim() == targetPath);

      await Future.wait([_savePhotoAnalyses(), _saveSimpleItems()]);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Wardrobe] ❌ 분석 크롭 항목 삭제 실패: $e');
      notifyListeners();
      return false;
    }
  }

  // Alias for evolve_screen compatibility
  Future<bool> deletePhotoAnalysis(String analysisId) =>
      removePhotoAnalysis(analysisId);

  // ===== Outfit Combinations =====
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

  // ===== v3.0 Query Methods =====
  PhotoAnalysisRecord? getPhotoAnalysisForItem(String itemPhotoPath) {
    try {
      final target = itemPhotoPath.trim();
      return _photoAnalyses.firstWhere(
        (record) =>
            record.imagePath == target ||
            record.generatedImagePath == target ||
            record.croppedImagePaths.any((path) => path.trim() == target),
      );
    } catch (e) {
      return null;
    }
  }

  List<AnalysisItemTag>? getItemAnalysisDetail(String itemPhotoPath) {
    try {
      final target = itemPhotoPath.trim();
      final record = _photoAnalyses.firstWhere(
        (r) =>
            r.imagePath == target ||
            r.generatedImagePath == target ||
            r.croppedImagePaths.any((path) => path.trim() == target),
      );
      return record.items;
    } catch (e) {
      return null;
    }
  }

  // ===== Utility Functions =====
  Future<String> _calculateImageHash(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return '';
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('[Wardrobe] 이미지 해시 계산 실패: $e');
      return '';
    }
  }

  String _validateColorHex(String? hex) {
    if (hex == null || hex.isEmpty) return '#808080';

    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F#]'), '');
    if (cleaned.startsWith('#')) {
      final code = cleaned.substring(1);
      if (code.length == 6) return '#$code';
      if (code.length == 3) {
        final expanded = code.split('').map((c) => '$c$c').join();
        return '#$expanded';
      }
    }

    // Try extracting hex-like digits
    final digits = RegExp(r'[0-9a-fA-F]{3,6}').firstMatch(cleaned);
    if (digits != null) {
      final match = digits.group(0)!;
      if (match.length == 3) {
        final expanded = match.split('').map((c) => '$c$c').join();
        return '#$expanded';
      }
      if (match.length == 6) {
        return '#$match';
      }
    }

    return '#808080'; // 기본값
  }

  Map<String, dynamic>? _extractSingleClothingItem(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          return entry;
        }
      }
    }

    return null;
  }

  Future<dynamic> _requestSceneItemsDecoded(
    String imagePath, {
    required String emptyErrorMessage,
    String promptKey = 'analyze_scene_items_en',
  }) async {
    debugPrint('[Wardrobe] ===== SceneItems 요청 시작 =====');
    debugPrint('[Wardrobe] imagePath: $imagePath');
    debugPrint('[Wardrobe] promptKey: $promptKey');
    debugPrint('[Wardrobe] 🔌 분석 소스: Gemini 우선, Grok 폴백');

    String? response = await _gemini.analyzeImage(imagePath, promptKey);
    var responseSource = 'gemini';

    if (response == null || response.trim().isEmpty) {
      debugPrint('[Wardrobe] ⚠️ Gemini 응답 비어있음');
      if (_grok?.isConfigured == true) {
        response = await _grok!.analyzeImage(imagePath, promptKey);
        responseSource = 'grok';
        debugPrint('[Wardrobe] ↩️ Grok 폴백 시도');
      }
    }

    debugPrint(
      '[Wardrobe] 📸 응답 길이($responseSource): ${response?.length ?? 0}',
    );
    if (response != null) {
      _logLongText(
        '[Wardrobe] ${responseSource.toUpperCase()} 응답 원문',
        response,
        chunkSize: 500,
      );
    }

    if (response == null || response.trim().isEmpty) {
      _error = emptyErrorMessage;
      debugPrint('[Wardrobe] ❌ 분석 응답이 비어있음(gemini/grok 모두 실패)');
      debugPrint('[Wardrobe] ===== SceneItems 요청 종료(실패) =====');
      return null;
    }

    final decoded = _decodeGeminiJson(response);
    if (decoded == null) {
      _error = '분석 JSON 파싱 실패';
      debugPrint('[Wardrobe] ===== SceneItems 요청 종료(파싱실패) =====');
      return null;
    }

    _logLongText(
      '[Wardrobe] ${responseSource.toUpperCase()} 디코딩 결과 JSON',
      jsonEncode(decoded),
      chunkSize: 500,
    );
    debugPrint('[Wardrobe] ===== SceneItems 요청 종료(성공) =====');

    return decoded;
  }

  bool _isLikelyEmptyGridCell(img.Image image) {
    final width = image.width;
    final height = image.height;
    if (width < 8 || height < 8) return true;

    final cornerPixels = <img.Pixel>[
      image.getPixel(0, 0),
      image.getPixel(width - 1, 0),
      image.getPixel(0, height - 1),
      image.getPixel(width - 1, height - 1),
    ];

    final bgR =
        cornerPixels.map((p) => p.r.toDouble()).reduce((a, b) => a + b) /
        cornerPixels.length;
    final bgG =
        cornerPixels.map((p) => p.g.toDouble()).reduce((a, b) => a + b) /
        cornerPixels.length;
    final bgB =
        cornerPixels.map((p) => p.b.toDouble()).reduce((a, b) => a + b) /
        cornerPixels.length;

    final stepX = max(1, width ~/ 30);
    final stepY = max(1, height ~/ 30);

    var sampled = 0;
    var differentCount = 0;

    for (var y = 0; y < height; y += stepY) {
      for (var x = 0; x < width; x += stepX) {
        final px = image.getPixel(x, y);
        final dr = px.r - bgR;
        final dg = px.g - bgG;
        final db = px.b - bgB;
        final dist = sqrt(dr * dr + dg * dg + db * db);
        if (dist > 28) {
          differentCount++;
        }
        sampled++;
      }
    }

    if (sampled == 0) return true;
    final differentRatio = differentCount / sampled;

    return differentRatio < 0.08;
  }

  dynamic _decodeGeminiJson(String raw) {
    debugPrint('[Wardrobe] 📄 _decodeGeminiJson 시작, 원본 길이: ${raw.length}');
    debugPrint(
      '[Wardrobe] 📄 원본 내용 (처음 200자): ${raw.substring(0, min(200, raw.length))}',
    );

    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    final repaired = _repairMalformedBoundingBoxJson(cleaned);

    debugPrint('[Wardrobe] 📄 정제된 길이: ${repaired.length}');
    debugPrint(
      '[Wardrobe] 📄 정제된 내용 (처음 200자): ${repaired.substring(0, min(200, repaired.length))}',
    );

    dynamic tryDecode(String input) {
      try {
        final result = jsonDecode(input);
        _normalizeDecodedBoundingBox(result);
        debugPrint('[Wardrobe] ✅ JSON 디코딩 성공');
        return result;
      } catch (e) {
        debugPrint('[Wardrobe] ⚠️ JSON decode 시도 실패: $e');
        return null;
      }
    }

    // Try direct decode
    final direct = tryDecode(repaired);
    if (direct != null) {
      debugPrint('[Wardrobe] ✅ direct 디코딩 성공');
      return direct;
    }

    // Try removing trailing comma
    final noTrailingComma = repaired.replaceFirst(RegExp(r',\s*$'), '');
    final directNoComma = tryDecode(noTrailingComma);
    if (directNoComma != null) {
      debugPrint('[Wardrobe] ✅ noTrailingComma 디코딩 성공');
      return directNoComma;
    }

    // Try extracting array/object
    if (noTrailingComma.contains('{')) {
      final extractedObjects = RegExp(
        r'\{[\s\S]*?\}',
      ).allMatches(noTrailingComma).map((m) => m.group(0)!).toList();

      debugPrint('[Wardrobe] 📄 추출된 객체 개수: ${extractedObjects.length}');
      if (extractedObjects.length > 1) {
        final objectList = extractedObjects
            .map(tryDecode)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (objectList.isNotEmpty) {
          debugPrint('[Wardrobe] ✅ 다중 객체 디코딩 성공: ${objectList.length}개');
          return objectList;
        }
      }
    }

    // Try array
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(noTrailingComma);
    if (arrayMatch != null) {
      final arrayDecoded = tryDecode(arrayMatch.group(0)!);
      if (arrayDecoded != null) {
        debugPrint('[Wardrobe] ✅ arrayMatch 디코딩 성공');
        return arrayDecoded;
      }
    }

    debugPrint('[Wardrobe] ❌ 모든 디코딩 시도 실패');
    return null;
  }

  String _repairMalformedBoundingBoxJson(String input) {
    var output = input;

    final malformedObjectPattern = RegExp(
      r'"bounding_box"\s*:\s*\{\s*(?:"x"\s*:\s*)?(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\}',
      multiLine: true,
    );

    output = output.replaceAllMapped(malformedObjectPattern, (match) {
      final x = match.group(1)!;
      final y = match.group(2)!;
      final third = match.group(3)!;
      final fourth = match.group(4)!;
      return '"bounding_box":{"x":$x,"y":$y,"width":$third,"height":$fourth}';
    });

    final malformedArrayPattern = RegExp(
      r'"bounding_box"\s*:\s*\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]',
      multiLine: true,
    );

    output = output.replaceAllMapped(malformedArrayPattern, (match) {
      final x = match.group(1)!;
      final y = match.group(2)!;
      final width = match.group(3)!;
      final height = match.group(4)!;
      return '"bounding_box":{"x":$x,"y":$y,"width":$width,"height":$height}';
    });

    if (output != input) {
      debugPrint('[Wardrobe] 🛠️ malformed bounding_box 자동 복구 적용');
    }

    return output;
  }

  void _normalizeDecodedBoundingBox(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return;
    final items = decoded['items'];
    if (items is! List) return;

    for (final rawItem in items) {
      if (rawItem is! Map) continue;
      final rawBox = rawItem['bounding_box'];
      if (rawBox is! Map) continue;

      final x = _parseDoubleOrZero(rawBox['x']);
      final y = _parseDoubleOrZero(rawBox['y']);
      var width = _parseDoubleOrZero(rawBox['width']);
      var height = _parseDoubleOrZero(rawBox['height']);

      if (x > 0 && width > x && width > 0.5) {
        width = width - x;
      }
      if (y > 0 && height > y && height > 0.5) {
        height = height - y;
      }

      rawItem['bounding_box'] = <String, double>{
        'x': _clamp01(x),
        'y': _clamp01(y),
        'width': _clamp01(width),
        'height': _clamp01(height),
      };
    }
  }

  double _parseDoubleOrZero(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  (List<AnalysisItemTag>, String)? _parseSceneItems(dynamic decoded) {
    debugPrint(
      '[Wardrobe] 📊 _parseSceneItems 시작: decoded 타입=${decoded.runtimeType}',
    );

    if (decoded is! Map<String, dynamic>) {
      debugPrint('[Wardrobe] ❌ decoded가 Map 형식이 아님: ${decoded.runtimeType}');
      return null;
    }

    final summary = (decoded['summary'] ?? '').toString();
    final itemsValue = decoded['items'];
    if (itemsValue is! List) {
      debugPrint(
        '[Wardrobe] ❌ decoded.items가 List 형식이 아님: ${itemsValue.runtimeType}',
      );
      return null;
    }

    final rawItems = itemsValue.whereType<Map<String, dynamic>>().toList();
    debugPrint('[Wardrobe] 📊 단일 스키마(Map.summary + Map.items) 감지');

    debugPrint('[Wardrobe] 📊 rawItems 개수: ${rawItems.length}');

    final items = rawItems
        .map((item) {
          final rawCategory = (item['category'] ?? '').toString();
          final rawLabel = (item['label'] ?? '').toString();
          debugPrint(
            '[Wardrobe] 📊 아이템 파싱: category="$rawCategory", label="$rawLabel"',
          );

          final finalCategory = rawCategory.trim().isEmpty
              ? _classifyByLabel(rawLabel)
              : _normalizeSceneCategory(rawCategory);

          final normalized = AnalysisItemTag(
            category: finalCategory,
            label: rawLabel,
            labelKey: _normalizeLabelKey(
              (item['label_key'] ?? rawLabel).toString(),
            ),
            labelEn: (item['label_en'] ?? rawLabel).toString(),
            labelKo: (item['label_ko'] ?? '').toString(),
            description: _ensureDetailedDescription(
              label: rawLabel,
              category: finalCategory,
              description: (item['description'] ?? '').toString(),
              color: item['color']?.toString() ?? '',
              material: item['material']?.toString() ?? '',
              pattern: item['pattern']?.toString() ?? '',
              style: item['style']?.toString() ?? '',
              season: _toStringList(item['season']),
              occasion: _toStringList(item['occasion']),
            ),
            descriptionKo: _ensureDetailedDescriptionKo(
              labelKo: (item['label_ko'] ?? rawLabel).toString(),
              category: finalCategory,
              descriptionKo: (item['description_ko'] ?? '').toString(),
              color: item['color']?.toString() ?? '',
              material: item['material']?.toString() ?? '',
              pattern: item['pattern']?.toString() ?? '',
              style: item['style']?.toString() ?? '',
              season: _toStringList(item['season']),
              occasion: _toStringList(item['occasion']),
            ),
            color: item['color']?.toString(),
            colorHex: _validateColorHex(
              item['colorHex']?.toString() ?? '#808080',
            ),
            material: item['material']?.toString(),
            pattern: item['pattern']?.toString(),
            style: item['style']?.toString(),
            season: _resolveSeason(
              rawSeason: item['season'],
              itemType: rawLabel,
              description: (item['description'] ?? '').toString(),
              material: item['material']?.toString(),
              style: item['style']?.toString(),
            ),
            occasion: _toStringList(item['occasion']),
          );
          debugPrint('[Wardrobe] 📊 정규화됨: category="${normalized.category}"');
          return normalized;
        })
        .where((item) {
          final isValid = item.category.isNotEmpty && item.label.isNotEmpty;
          if (!isValid) {
            debugPrint(
              '[Wardrobe] ⚠️ 필터링됨 (유효하지 않음): category="${item.category}", label="${item.label}"',
            );
          }
          return isValid;
        })
        .toList();

    debugPrint('[Wardrobe] 📊 최종 items 개수: ${items.length}');
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
          labelKey: item.labelKey,
          labelEn: item.labelEn,
          labelKo: item.labelKo,
          description: item.description,
          descriptionKo: item.descriptionKo,
          color: item.color,
          colorHex: item.colorHex,
          material: item.material,
          pattern: item.pattern,
          style: item.style,
          season: item.season,
          occasion: item.occasion,
          eligibleForCategory: false,
          qualityStatus: 'insufficient_top_visibility',
        );
      }

      if (item.category == 'bottom' && bottomCoverageScore < 0.90) {
        return AnalysisItemTag(
          category: item.category,
          label: item.label,
          labelKey: item.labelKey,
          labelEn: item.labelEn,
          labelKo: item.labelKo,
          description: item.description,
          descriptionKo: item.descriptionKo,
          color: item.color,
          colorHex: item.colorHex,
          material: item.material,
          pattern: item.pattern,
          style: item.style,
          season: item.season,
          occasion: item.occasion,
          eligibleForCategory: false,
          qualityStatus: 'insufficient_bottom_visibility',
        );
      }

      return AnalysisItemTag(
        category: item.category,
        label: item.label,
        labelKey: item.labelKey,
        labelEn: item.labelEn,
        labelKo: item.labelKo,
        description: item.description,
        descriptionKo: item.descriptionKo,
        color: item.color,
        colorHex: item.colorHex,
        material: item.material,
        pattern: item.pattern,
        style: item.style,
        season: item.season,
        occasion: item.occasion,
        eligibleForCategory: true,
        qualityStatus: 'ok',
      );
    }).toList();
  }

  String _classifyByLabel(String label) {
    final lower = label.trim().toLowerCase();

    if (lower.contains(
      RegExp(
        r'shirt|blouse|t-shirt|tee|sweater|sweatshirt|hoodie|vest|top',
      ),
    )) {
      return 'top';
    }

    if (lower.contains(
      RegExp(
        r'outer|outerwear|jacket|coat|cardigan|blazer|parka|windbreaker|jumper|puffer|down|padding|trench',
      ),
    )) {
      return 'outerwear';
    }

    if (lower.contains(
      RegExp(r'pant|jean|skirt|short|legging|trouser|pants|capri|khaki|chino'),
    )) {
      return 'bottom';
    }

    if (lower.contains(RegExp(r'hat|cap|beanie|bonnet|fedora|baseball cap'))) {
      return 'hat';
    }

    if (lower.contains(
      RegExp(r'shoe|sneaker|boot|heel|flat|sandal|loafer|oxford|pump|slipper'),
    )) {
      return 'shoes';
    }

    if (lower.contains(RegExp(r'dress|gown'))) {
      return 'bottom';
    }

    return 'accessory';
  }

  String _normalizeSceneCategory(String value) {
    final category = value.trim().toLowerCase();
    if (_supportedSceneCategories.contains(category)) {
      return category;
    }
    if (category.contains('외투') ||
        category.contains('아우터') ||
        category.contains('outer') ||
        category.contains('outerwear') ||
        category.contains('jacket') ||
        category.contains('coat') ||
        category.contains('cardigan') ||
        category.contains('blazer') ||
        category.contains('parka') ||
        category.contains('windbreaker')) {
      return 'outerwear';
    }
    if (category.contains('상의') ||
        category.contains('top') ||
        category.contains('shirt') ||
        category.contains('blouse')) {
      return 'top';
    }
    if (category.contains('하의') ||
        category.contains('bottom') ||
        category.contains('pants') ||
        category.contains('skirt')) {
      return 'bottom';
    }
    if (category.contains('모자') ||
        category.contains('hat') ||
        category.contains('cap')) {
      return 'hat';
    }
    if (category.contains('신발') ||
        category.contains('shoe') ||
        category.contains('sneaker') ||
        category.contains('boot')) {
      return 'shoes';
    }
    return 'accessory';
  }

  String _normalizeLabelKey(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
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

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return [];
      return normalized
          .split(RegExp(r'[,/|]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _buildExtractionPrompt({String? labels}) {
    final basePrompt = _promptOrFallback(
      'extraction_prompt_base_ko',
      '이미지는 반드시 2x3 고정 그리드(총 6칸)로 구성하고 각 칸에 아이템 1개만 배치하세요.',
    );

    final trimmed = (labels ?? '').trim();
    if (trimmed.isEmpty) {
      return basePrompt;
    }

    return _promptOrFallback(
      'extraction_prompt_with_labels_ko',
      '$basePrompt\n추출 대상 참고: $trimmed',
      params: {'base': basePrompt, 'labels': trimmed},
    );
  }

  String _ensureDetailedDescription({
    required String label,
    required String category,
    required String description,
    required String color,
    required String material,
    required String pattern,
    required String style,
    required List<String> season,
    required List<String> occasion,
  }) {
    final normalizedDescription = description.trim();
    if (normalizedDescription.length >= 40) {
      return normalizedDescription;
    }

    final detailParts = <String>[];
    if (color.trim().isNotEmpty) detailParts.add('color: ${color.trim()}');
    if (material.trim().isNotEmpty) {
      detailParts.add('material: ${material.trim()}');
    }
    if (pattern.trim().isNotEmpty)
      detailParts.add('pattern: ${pattern.trim()}');
    if (style.trim().isNotEmpty) detailParts.add('style: ${style.trim()}');
    if (season.isNotEmpty) detailParts.add('season: ${season.join('/')}');
    if (occasion.isNotEmpty) {
      detailParts.add('occasion: ${occasion.join('/')}');
    }

    final detailText = detailParts.isEmpty
        ? 'visual details are limited in the source analysis'
        : detailParts.join(', ');

    final baseText = normalizedDescription.isEmpty
        ? 'a ${label.trim()} item'
        : normalizedDescription;

    return _promptOrFallback(
      'analysis_detail_en_template',
      'Detected $baseText in category $category, with $detailText, suitable for image generation guidance.',
      params: {
        'base_text': baseText,
        'category': category,
        'detail_text': detailText,
      },
    );
  }

  String _ensureDetailedDescriptionKo({
    required String labelKo,
    required String category,
    required String descriptionKo,
    required String color,
    required String material,
    required String pattern,
    required String style,
    required List<String> season,
    required List<String> occasion,
  }) {
    final normalizedDescription = descriptionKo.trim();
    if (normalizedDescription.length >= 40) {
      return normalizedDescription;
    }

    final detailParts = <String>[];
    if (color.trim().isNotEmpty) detailParts.add('색상 ${color.trim()}');
    if (material.trim().isNotEmpty) detailParts.add('소재 ${material.trim()}');
    if (pattern.trim().isNotEmpty) detailParts.add('패턴 ${pattern.trim()}');
    if (style.trim().isNotEmpty) detailParts.add('스타일 ${style.trim()}');
    if (season.isNotEmpty) detailParts.add('권장계절 ${season.join('/')}');
    if (occasion.isNotEmpty) detailParts.add('활용상황 ${occasion.join('/')}');

    final detailText = detailParts.isEmpty
        ? '시각적 속성 정보가 제한적입니다'
        : detailParts.join(', ');
    final baseText = normalizedDescription.isEmpty
        ? '${labelKo.trim()} 아이템($category)'
        : normalizedDescription;

    return _promptOrFallback(
      'analysis_detail_ko_template',
      '$baseText. 상세 해설: $detailText. 평가: 코디 활용성을 고려해 조합 가능한 아이템입니다.',
      params: {
        'base_text': baseText,
        'category': category,
        'detail_text': detailText,
      },
    );
  }

  String _promptOrFallback(
    String key,
    String fallback, {
    Map<String, String>? params,
  }) {
    final resolved = ConfigService.instance.getPrompt(key, params: params);
    if (resolved.trim().isEmpty || resolved == key) {
      return fallback;
    }
    return resolved;
  }

  List<String> _resolveSeason({
    required dynamic rawSeason,
    required String itemType,
    required String description,
    String? material,
    String? style,
  }) {
    final parsed = _toStringList(
      rawSeason,
    ).map(_normalizeSeasonLabel).where((e) => e.isNotEmpty).toSet().toList();

    final sourceText = [
      itemType,
      description,
      material ?? '',
      style ?? '',
    ].join(' ').toLowerCase();

    final isHeavyOuterwear = sourceText.contains(
      RegExp(
        r'패딩|다운|점퍼|잠바|롱패딩|숏패딩|parka|puffer|down|padding|heavy|thick|winter jacket|duvet',
      ),
    );

    if (isHeavyOuterwear) {
      final winterFocused = <String>{'겨울'};
      if (sourceText.contains('초겨울') || sourceText.contains('late fall')) {
        winterFocused.add('가을');
      }
      return winterFocused.toList();
    }

    if (parsed.isNotEmpty) {
      return parsed;
    }

    return ['봄', '여름', '가을', '겨울'];
  }

  String _normalizeSeasonLabel(String value) {
    final season = value.trim().toLowerCase();
    if (season.isEmpty) return '';

    if (season.contains('spring') || season.contains('봄')) return '봄';
    if (season.contains('summer') || season.contains('여름')) return '여름';
    if (season.contains('fall') ||
        season.contains('autumn') ||
        season.contains('가을')) {
      return '가을';
    }
    if (season.contains('winter') || season.contains('겨울')) return '겨울';

    return '';
  }
}
