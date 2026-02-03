import 'package:flutter/foundation.dart';
import '../models/my_avatar.dart';
import '../models/body_measurements.dart';
import '../models/avatar_stage.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/config_service.dart';

/// MyAvatar 상태 관리 Provider
/// 
/// **헌법적 원칙:**
/// - 항상 1개의 아바타만 존재
/// - 생성이 아닌 "진화"
class AvatarProvider extends ChangeNotifier {
  final StorageService _storage;
  final GeminiService _gemini;

  MyAvatar? _avatar;
  bool _isLoading = false;
  String? _error;

  AvatarProvider({
    required StorageService storage,
    required GeminiService gemini,
  })  : _storage = storage,
        _gemini = gemini {
    _loadAvatar();
  }

  MyAvatar? get avatar => _avatar;
  MyAvatar? get currentAvatar => _avatar;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAvatar => _avatar != null;

  /// 아바타 불러오기
  Future<void> _loadAvatar() async {
    _isLoading = true;
    notifyListeners();

    try {
      _avatar = await _storage.loadAvatar();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stage-0: 초기 아바타 생성 (마네킹 선택)
  Future<void> createInitialAvatar({
    required String mannequinId,
    required BodyMeasurements measurements,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _avatar = MyAvatar(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        baseMannequinId: mannequinId,
        bodyMeasurements: measurements,
        stage: AvatarStage.anchor,
      );

      await _storage.saveAvatar(_avatar!);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 기존 아바타 업데이트 (마네킹/신체 정보 수정)
  Future<void> updateAvatar({
    required String mannequinId,
    required BodyMeasurements measurements,
  }) async {
    if (_avatar == null) {
      _error = ConfigService.instance.getString('strings.errors.no_avatar');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _avatar = _avatar!.copyWith(
        baseMannequinId: mannequinId,
        bodyMeasurements: measurements,
      );

      await _storage.saveAvatar(_avatar!);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stage-1: 아바타 진화 (사진 기반)
  Future<bool> evolveAvatar(String referencePath) async {
    if (_avatar == null) {
      _error = ConfigService.instance.getString('strings.errors.no_avatar');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[진화] 시작합니다.');
      
      // Gemini로 실루엣 진화
      final mannequin =
          ConfigService.instance.getMannequinById(_avatar!.baseMannequinId);
      if (mannequin == null) {
        debugPrint('[진화] 마네킹을 찾지 못했습니다: ${_avatar!.baseMannequinId}');
        _error =
          ConfigService.instance.getString('strings.errors.mannequin_not_found');
        notifyListeners();
        return false;
      }

      debugPrint('[진화] 마네킹: ${mannequin.id} (asset: ${mannequin.assetPath})');
      debugPrint('[진화] 참고사진 경로: $referencePath');
      debugPrint('[진화] 체형 정보: ${_avatar!.bodyMeasurements.bodyType}');

      final evolvedImage = await _gemini.evolveAvatarSilhouette(
        baseAvatarPath: mannequin.assetPath,
        referencePath: referencePath,
        bodyType: _avatar!.bodyMeasurements.bodyType,
      );

      debugPrint('[진화] 결과 이미지: ${evolvedImage != null ? evolvedImage.path : '없음'}');

      if (evolvedImage != null) {
        debugPrint('[진화] 성공');
        // 진화된 이미지로 업데이트
        _avatar = _avatar!.copyWith(
          stage: AvatarStage.silhouette,
          evolvedImagePath: evolvedImage.path,
          referencePaths: _mergeReferencePaths(
            _avatar!.referencePaths,
            referencePath,
          ),
          evolutionHistory: [
            ..._avatar!.evolutionHistory,
            'Evolved at ${DateTime.now()}'
          ],
        );

        await _storage.saveAvatar(_avatar!);
        _error = null;
        notifyListeners();
        return true;
      } else {
        debugPrint('[진화] 실패: 결과 이미지가 없습니다.');
        _error = ConfigService.instance.getString('strings.errors.evolve_failed');
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[진화] 예외 발생: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 참고 사진 추가 (중복 방지)
  Future<void> addReferencePhoto(String path) async {
    if (_avatar == null) return;
    final updated = _mergeReferencePaths(_avatar!.referencePaths, path);
    if (updated.length == _avatar!.referencePaths.length) return;

    _avatar = _avatar!.copyWith(referencePaths: updated);
    await _storage.saveAvatar(_avatar!);
    notifyListeners();
  }

  /// 참고 사진 제거 (목록에서만 제거)
  Future<void> removeReferencePhoto(String path) async {
    if (_avatar == null) return;
    final updated = _avatar!.referencePaths.where((p) => p != path).toList();

    _avatar = _avatar!.copyWith(referencePaths: updated);
    await _storage.saveAvatar(_avatar!);
    notifyListeners();
  }

  List<String> _mergeReferencePaths(List<String> current, String path) {
    if (current.contains(path)) return current;
    return [...current, path];
  }

  /// 신체 정보 업데이트
  Future<void> updateBodyMeasurements(BodyMeasurements measurements) async {
    if (_avatar == null) return;

    _avatar = _avatar!.copyWith(bodyMeasurements: measurements);
    await _storage.saveAvatar(_avatar!);
    notifyListeners();
  }

  /// 아바타 초기화
  Future<void> resetAvatar() async {
    _avatar = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
