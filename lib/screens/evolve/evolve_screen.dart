import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/photo_analysis_record.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/ondevice_precheck_service.dart';
import '../../widgets/codi_styled_app_bar.dart';

/// 옷 추가 화면 (v3.0 - 간소화)
///
/// 원칙:
/// - 갤러리/카메라에서 옷 사진 선택
/// - Gemini로 자동 분석
/// - 크롭/마스크 없이 원본 사진 그대로 저장
class EvolveScreen extends StatefulWidget {
  final PhotoAnalysisRecord? initialEditRecord;

  const EvolveScreen({super.key, this.initialEditRecord});

  @override
  State<EvolveScreen> createState() => _EvolveScreenState();
}

class _EvolveScreenState extends State<EvolveScreen> {
  final ImagePicker _picker = ImagePicker();
  final OnDevicePrecheckService _precheckService = OnDevicePrecheckService();
  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey _generatedPreviewKey = GlobalKey();

  XFile? _selectedImage;
  CapturePrecheckResult? _precheckResult;
  int? _selectedPersonId;
  PhotoAnalysisRecord? _selectedRecord;
  Set<int> _selectedSecondStageCells = <int>{};
  List<double> _verticalGuides = <double>[0.5];
  List<double> _horizontalGuides = <double>[1 / 3, 2 / 3];
  Map<int, Rect> _customSelectedRegions = <int, Rect>{};
  int? _activeVerticalGuideIndex;
  int? _activeHorizontalGuideIndex;
  bool _isProcessing = false;
  String? _statusMessage;
  File? _generatedPreviewFile;
  bool _isThumbnailDetailMode = false;
  bool _isRecordEditMode = false;
  bool _showOriginalReloadOnFailure = false;

  static const double _guideEdgeInset = 0.02;
  static const double _guideMinGap = 0.03;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialEditRecord == null) {
        context.read<WardrobeProvider>().clearTransientAnalysisState();
        return;
      }

      _openAnalysisRecordForEdit(widget.initialEditRecord!);
    });
  }

  Future<void> _showBlockingMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.hideCurrentMaterialBanner();

    final colors = Theme.of(context).colorScheme;
    final isErrorTitle =
        title.contains('실패') || title.contains('오류') || title.contains('불가');
    final icon = isErrorTitle ? Icons.error_outline : Icons.info_outline;
    final iconColor = isErrorTitle ? colors.error : colors.primary;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                message,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnalysisCompleteModal({
    required String title,
    required String subtitle,
    required String description,
  }) async {
    if (!mounted) return;

    final colors = Theme.of(context).colorScheme;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'analysis-complete',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.primary.withValues(alpha: 0.92),
                      colors.primaryContainer.withValues(alpha: 0.92),
                      colors.surface.withValues(alpha: 0.95),
                    ],
                  ),
                  border: Border.all(
                    color: colors.surfaceBright.withValues(alpha: 0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: '닫기',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          Icons.close,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.surfaceBright,
                                  colors.primary.withValues(alpha: 0.82),
                                ],
                              ),
                              border: Border.all(
                                color: colors.surface.withValues(alpha: 0.8),
                                width: 1.8,
                              ),
                            ),
                            child: Icon(
                              Icons.priority_high_rounded,
                              size: 44,
                              color: colors.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.surfaceBright.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: colors.surfaceBright,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: colors.surfaceBright.withValues(
                                          alpha: 0.92,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  description,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: colors.surfaceBright.withValues(
                                          alpha: 0.9,
                                        ),
                                        height: 1.35,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: 170,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          colors.surfaceBright.withValues(
                                            alpha: 0.98,
                                          ),
                                          colors.primaryContainer.withValues(
                                            alpha: 0.95,
                                          ),
                                          colors.inversePrimary.withValues(
                                            alpha: 0.95,
                                          ),
                                          colors.primary.withValues(alpha: 0.86),
                                        ],
                                        stops: const [0.0, 0.32, 0.72, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: colors.primary.withValues(
                                          alpha: 0.98,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(999),
                                        onTap: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: colors.onPrimaryContainer,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '확인',
                                                style: Theme.of(dialogContext)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onPrimaryContainer,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  bool _isFirstStageFailureCode(String? code) {
    final normalized = (code ?? '').trim().toUpperCase();
    return normalized == 'FIRST_STAGE_FAIL' ||
        normalized == 'FIRST_STAGE_REGEN_FAIL';
  }

  bool _isTimeoutFailureCode(String? code) {
    return (code ?? '').trim().toUpperCase() == 'TIMEOUT';
  }

  String _buildFirstStageFailureGuide({
    required String fallbackMessage,
    String? rawReason,
  }) {
    final reason = (rawReason ?? '').trim();
    final lines = <String>[
      fallbackMessage,
      '',
      '실패가 자주 나는 대표 원인',
      '• 사진에 사람이 1명이 아니거나 전신이 명확하지 않은 경우',
      '• 옷이 화면 밖으로 잘리거나 많이 가려진 경우',
      '• 어둡거나 흐리거나 역광이라 옷 경계가 흐린 경우',
    ];

    if (reason.isNotEmpty) {
      lines.add('');
      lines.add('실제 오류: $reason');
    }

    return lines.join('\n');
  }

  String _buildTimeoutFailureGuide({required String fallbackMessage}) {
    return [
      fallbackMessage,
      '',
      '요청 시간이 초과되었습니다.',
      '• 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
      '• 잠시 후 다시 시도하면 정상 처리되는 경우가 많습니다.',
      '• 이 경우는 사진 내용 문제와 무관할 수 있습니다.',
    ].join('\n');
  }

  String _buildFriendlyFailureMessage({
    required WardrobeProvider provider,
    required String fallbackMessage,
  }) {
    if (_isTimeoutFailureCode(provider.lastSecondStageFailureCode)) {
      return _buildTimeoutFailureGuide(fallbackMessage: fallbackMessage);
    }

    if (_isFirstStageFailureCode(provider.lastSecondStageFailureCode)) {
      return _buildFirstStageFailureGuide(
        fallbackMessage: fallbackMessage,
        rawReason: provider.error,
      );
    }

    return provider.error ?? fallbackMessage;
  }

  Future<void> _showFirstStageCompleteModal() async {
    await _showAnalysisCompleteModal(
      title: '1차 분석 완료',
      subtitle: '의류 추출이 끝났어요',
      description:
          '이제 아래 생성 이미지에서 블록을 선택해 2차 분석을 진행해 주세요.\n선택한 블록만 저장됩니다.',
    );
  }

  void _finishProcessingState() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });
  }

  Future<void> _pickAndAddClothing(ImageSource source) async {
    if (_isProcessing) return;

    try {
      if (!mounted) return;
      context.read<WardrobeProvider>().clearTransientAnalysisState();
      setState(() {
        _isProcessing = true;
        _statusMessage = '사진을 선택하는 중...';
        _generatedPreviewFile = null;
        _showOriginalReloadOnFailure = false;
        _selectedRecord = null;
        _isThumbnailDetailMode = false;
        _isRecordEditMode = false;
        _selectedSecondStageCells = <int>{};
        _verticalGuides = <double>[0.5];
        _horizontalGuides = <double>[1 / 3, 2 / 3];
        _customSelectedRegions = <int, Rect>{};
        _activeVerticalGuideIndex = null;
        _activeHorizontalGuideIndex = null;
      });

      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedImage = picked;
        _precheckResult = null;
        _selectedPersonId = null;
        _generatedPreviewFile = null;
        _isThumbnailDetailMode = false;
        _isRecordEditMode = false;
        _selectedSecondStageCells = <int>{};
        _verticalGuides = <double>[0.5];
        _horizontalGuides = <double>[1 / 3, 2 / 3];
        _customSelectedRegions = <int, Rect>{};
        _activeVerticalGuideIndex = null;
        _activeHorizontalGuideIndex = null;
        _statusMessage = '온디바이스 검사 중...';
      });

      final precheck = await _precheckService.analyze(picked.path);
      if (!mounted) return;

      setState(() {
        _precheckResult = precheck;
      });

      if (!precheck.canAnalyze) {
        if (precheck.failReason == PrecheckFailReason.multiPersonNeedSelect) {
          setState(() {
            _statusMessage = precheck.message;
            _isProcessing = false;
            _showOriginalReloadOnFailure = true;
          });
          return;
        }

        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _showOriginalReloadOnFailure = true;
        });
        await _showBlockingMessageDialog(
          title: '분석 불가',
          message: precheck.message,
        );
        return;
      }

      final success = await _runFullAnalysis(precheck);

      if (!mounted) return;

      if (!success) {
        final wardrobeProvider = context.read<WardrobeProvider>();
        setState(() {
          _showOriginalReloadOnFailure = true;
        });
        _finishProcessingState();
        final message = _buildFriendlyFailureMessage(
          provider: wardrobeProvider,
          fallbackMessage: '사진에서 아이템을 추출하지 못했습니다.',
        );
        await _showBlockingMessageDialog(
          title: '생성 실패',
          message: message,
        );
        return;
      }

      setState(() {
        _showOriginalReloadOnFailure = false;
      });
      await _showFirstStageCompleteModal();
    } catch (e) {
      setState(() {
        _showOriginalReloadOnFailure = true;
      });
      _finishProcessingState();
      if (!mounted) return;
      await _showBlockingMessageDialog(title: '오류', message: e.toString());
    } finally {
      if (mounted && _isProcessing) {
        _finishProcessingState();
      }
    }
  }

  Future<bool> _runFullAnalysis(CapturePrecheckResult precheck) async {
    if (_selectedImage == null) return false;

    setState(() {
      _statusMessage = '사진에서 AI가 아이템을 추출 중입니다.';
      _selectedRecord = null;
      _isThumbnailDetailMode = false;
      _isRecordEditMode = false;
    });

    final wardrobeProvider = context.read<WardrobeProvider>();
    final selected = _selectedPerson(precheck);
    final selectedPersonId =
        _selectedPersonId ?? precheck.selectedPersonId ?? selected?.id;
    final topCoverage = selected?.topCoverageScore ?? 1.0;
    final bottomCoverage = selected?.bottomCoverageScore ?? 1.0;

    final success = await wardrobeProvider.addPhotoAnalysisFromImage(
      _selectedImage!.path,
      personCount: precheck.persons.length,
      selectedPersonId: selectedPersonId,
      brightnessScore: precheck.brightnessScore,
      sharpnessScore: precheck.sharpnessScore,
      topCoverageScore: topCoverage,
      bottomCoverageScore: bottomCoverage,
      cropImmediately: true,
      generatePreviewImage: true,
      runSecondStageAutomatically: false,
    );

    final generatedPath = (wardrobeProvider.generatedPreviewImagePath ?? '')
        .trim();
    final generated =
        generatedPath.isNotEmpty && File(generatedPath).existsSync()
        ? File(generatedPath)
        : null;

    setState(() {
      _generatedPreviewFile = generated;
      _selectedSecondStageCells = <int>{};
    });

    if (success) {
      _scrollToGeneratedPreview();
    }

    if (!success) {
      debugPrint('[Evolve] ❌ 1차 추출 실패');
    } else {
      debugPrint('[Evolve] ✅ 아이템 추출 완료. 2차 수동 실행 대기: ${generated?.path ?? ''}');
    }

    return success;
  }

  Future<void> _applySelectedPerson() async {
    if (_selectedImage == null || _selectedPersonId == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '선택 인물 기준으로 재검사 중...';
    });

    final precheck = await _precheckService.analyze(
      _selectedImage!.path,
      selectedPersonId: _selectedPersonId,
    );
    if (!mounted) return;

    setState(() {
      _precheckResult = precheck;
    });

    if (!precheck.canAnalyze) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
        _showOriginalReloadOnFailure = true;
      });
      await _showBlockingMessageDialog(
        title: '분석 불가',
        message: precheck.message,
      );
      return;
    }

    final success = await _runFullAnalysis(precheck);
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });

    if (!success) {
      final provider = context.read<WardrobeProvider>();
      final message = _buildFriendlyFailureMessage(
        provider: provider,
        fallbackMessage: '사진에서 아이템을 추출하지 못했습니다.',
      );
      setState(() {
        _showOriginalReloadOnFailure = true;
      });
      await _showBlockingMessageDialog(title: '분석 실패', message: message);
      return;
    }

    final latest = context.read<WardrobeProvider>().photoAnalyses.isNotEmpty
        ? context.read<WardrobeProvider>().photoAnalyses.last
        : null;
    setState(() {
      _selectedRecord = latest;
      _showOriginalReloadOnFailure = false;
    });

    await _showFirstStageCompleteModal();
  }

  Future<void> _retryFromTopImageAfterFailure() async {
    if (_isProcessing || _selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '사진에서 다시 추출 중...';
    });

    try {
      final precheck = await _precheckService.analyze(
        _selectedImage!.path,
        selectedPersonId: _selectedPersonId,
      );
      if (!mounted) return;

      setState(() {
        _precheckResult = precheck;
      });

      if (!precheck.canAnalyze) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _showOriginalReloadOnFailure = true;
        });
        await _showBlockingMessageDialog(
          title: '분석 불가',
          message: precheck.message,
        );
        return;
      }

      final success = await _runFullAnalysis(precheck);
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = null;
        _showOriginalReloadOnFailure = !success;
      });

      if (!success) {
        final provider = context.read<WardrobeProvider>();
        final message = _buildFriendlyFailureMessage(
          provider: provider,
          fallbackMessage: '사진에서 아이템을 다시 추출하지 못했습니다.',
        );
        await _showBlockingMessageDialog(title: '재시도 실패', message: message);
        return;
      }

      await _showFirstStageCompleteModal();
      _scrollToGeneratedPreview();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
        _showOriginalReloadOnFailure = true;
      });
      await _showBlockingMessageDialog(title: '오류', message: e.toString());
    }
  }

  Future<void> _retrySecondStage() async {
    if (_isProcessing) return;
    if (_selectedSecondStageCells.isEmpty) {
      await _showBlockingMessageDialog(
        title: '선택 필요',
        message: '최소 1개 블록을 선택한 뒤 선택한 블록 분석을 눌러주세요.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '선택한 블록 분석 중...';
      _isThumbnailDetailMode = false;
    });

    final provider = context.read<WardrobeProvider>();
    final editTargetRecordId = _isRecordEditMode
        ? (_selectedRecord?.id.trim() ?? '')
        : '';

    if (_isRecordEditMode && editTargetRecordId.isEmpty) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      await _showBlockingMessageDialog(
        title: '편집 실패',
        message: '교체할 분석 대상을 찾지 못했습니다. 다시 편집을 열어주세요.',
      );
      return;
    }

    if (_isRecordEditMode && !provider.canRetrySecondStage) {
      final targetRecord = _selectedRecord;
      if (targetRecord == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        await _showBlockingMessageDialog(
          title: '분석 불가',
          message: '편집할 분석 기록이 없습니다.',
        );
        return;
      }

      final prepared = provider.prepareSecondStageFromRecord(targetRecord);
      if (!mounted) return;
      if (!prepared) {
        final message = provider.error ?? '알 수 없는 오류';
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        await _showBlockingMessageDialog(title: '준비 실패', message: message);
        return;
      }
    }

    final regions = _currentGuideRegions();
    final selectedRegions = _selectedSecondStageCells.isEmpty
        ? null
        : _selectedSecondStageCells
              .where((index) => index >= 0 && index < regions.length)
              .map((index) => _customSelectedRegions[index] ?? regions[index])
              .map(
                (rect) => <String, double>{
                  'x': rect.left,
                  'y': rect.top,
                  'width': rect.width,
                  'height': rect.height,
                },
              )
              .toList(growable: false);

    final success = await provider
        .retrySecondStageFromLastGeneratedWithSelection(
          selectedCellIndexes: _selectedSecondStageCells.isEmpty
              ? null
              : _selectedSecondStageCells,
          selectedRegions: selectedRegions,
          replaceAnalysisId: editTargetRecordId.isEmpty
              ? null
              : editTargetRecordId,
        );

    if (!mounted) return;

    final generatedPath = (provider.generatedPreviewImagePath ?? '').trim();
    final generated =
        generatedPath.isNotEmpty && File(generatedPath).existsSync()
        ? File(generatedPath)
        : null;

    PhotoAnalysisRecord? latestRecord;
    if (editTargetRecordId.isNotEmpty) {
      try {
        latestRecord = provider.photoAnalyses.firstWhere(
          (record) => record.id == editTargetRecordId,
        );
      } catch (_) {
        latestRecord = provider.photoAnalyses.isNotEmpty
            ? provider.photoAnalyses.last
            : null;
      }
    } else {
      latestRecord = provider.photoAnalyses.isNotEmpty
          ? provider.photoAnalyses.last
          : null;
    }

    setState(() {
      _generatedPreviewFile = generated;
      if (success && latestRecord != null) {
        _selectedRecord = latestRecord;
      } else if (!success && !_isRecordEditMode) {
        _selectedRecord = null;
      }
      _isProcessing = false;
      _statusMessage = null;
    });

    if (success) {
      final expected = provider.lastSecondStageExpectedBlocks;
      final matched = provider.lastSecondStageMatchedBlocks;
      String message;
      String subtitle;
      if (expected > 0 && matched > 0 && matched < expected) {
        message = '선택한 $expected개 중 $matched개만 저장됐어요.';
        subtitle = '$matched / $expected 블록 저장';
      } else if (expected > 0 && matched >= expected) {
        message = '선택한 $expected개가 모두 저장됐어요.';
        subtitle = '$matched / $expected 블록 저장';
      } else {
        message = '선택 영역 저장이 완료됐어요.';
        subtitle = '저장 완료';
      }
      await _showAnalysisCompleteModal(
        title: '사진 분석 등록 완료',
        subtitle: subtitle,
        description: message,
      );
    }

    _scrollToGeneratedPreview();
  }

  Future<void> _regenerateFirstStageImage() async {
    if (_isProcessing) return;
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '사진에서 다시 추출 중...';
      _selectedRecord = null;
      _isRecordEditMode = false;
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeVerticalGuideIndex = null;
      _activeHorizontalGuideIndex = null;
    });

    final provider = context.read<WardrobeProvider>();
    final regenerated = await provider.regenerateFirstStagePreviewForPending();

    if (!mounted) return;

    if (regenerated == null) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      final message = _buildFriendlyFailureMessage(
        provider: provider,
        fallbackMessage: '사진 다시 추출에 실패했습니다.',
      );
      await _showBlockingMessageDialog(
        title: '재생성 실패',
        message: message,
      );
      return;
    }

    setState(() {
      _generatedPreviewFile = regenerated;
      _isProcessing = false;
      _statusMessage = null;
      _verticalGuides = <double>[0.5];
      _horizontalGuides = <double>[1 / 3, 2 / 3];
    });

    _scrollToGeneratedPreview();
  }

  void _openAnalysisRecordForEdit(PhotoAnalysisRecord record) {
    _applyAnalysisRecordSelection(
      record,
      thumbnailDetailMode: false,
      editMode: true,
    );
    _scrollToGeneratedPreview();
  }

  void _applyAnalysisRecordSelection(
    PhotoAnalysisRecord record, {
    required bool thumbnailDetailMode,
    required bool editMode,
  }) {
    final wardrobeProvider = context.read<WardrobeProvider>();

    final generatedPath = record.generatedImagePath.trim();
    final generatedFile =
        generatedPath.isNotEmpty && File(generatedPath).existsSync()
        ? File(generatedPath)
        : null;

    if (generatedFile != null) {
      wardrobeProvider.setLastReceivedImagePath(generatedPath);
    }

    if (editMode) {
      final prepared = wardrobeProvider.prepareSecondStageFromRecord(record);
      if (!prepared) {
        wardrobeProvider.clearTransientAnalysisState();
      }
    }

    final restoredCells = record.selectedCellIndexes
        .where((index) => index >= 0 && index < 6)
        .toSet();

    final restoredRegions = <int, Rect>{};
    if (record.selectedRegions.isNotEmpty && restoredCells.isNotEmpty) {
      final orderedCells = restoredCells.toList()..sort();
      final length = min(orderedCells.length, record.selectedRegions.length);
      for (var i = 0; i < length; i++) {
        final cellIndex = orderedCells[i];
        final raw = record.selectedRegions[i];
        final x = _clamp01((raw['x'] ?? 0).toDouble());
        final y = _clamp01((raw['y'] ?? 0).toDouble());
        final width = _clamp01((raw['width'] ?? 0).toDouble());
        final height = _clamp01((raw['height'] ?? 0).toDouble());
        final clampedW = _clamp01((x + width) > 1 ? (1 - x) : width);
        final clampedH = _clamp01((y + height) > 1 ? (1 - y) : height);
        if (clampedW <= 0 || clampedH <= 0) continue;
        restoredRegions[cellIndex] = Rect.fromLTWH(x, y, clampedW, clampedH);
      }
    }

    setState(() {
      _selectedRecord = record;
      _isThumbnailDetailMode = thumbnailDetailMode;
      _isRecordEditMode = editMode;
      _selectedImage = XFile(record.imagePath);
      _precheckResult = null;
      _selectedPersonId = null;
      _generatedPreviewFile = generatedFile;
      _selectedSecondStageCells = restoredCells;
      _verticalGuides = <double>[0.5];
      _horizontalGuides = <double>[1 / 3, 2 / 3];
      _customSelectedRegions = restoredRegions;
      _activeVerticalGuideIndex = null;
      _activeHorizontalGuideIndex = null;
    });
  }

  double _clamp01(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  void _toggleSecondStageCell(int index) {
    setState(() {
      if (_selectedSecondStageCells.contains(index)) {
        _selectedSecondStageCells = <int>{..._selectedSecondStageCells}
          ..remove(index);
        _customSelectedRegions = <int, Rect>{..._customSelectedRegions}
          ..remove(index);
      } else {
        _selectedSecondStageCells = <int>{..._selectedSecondStageCells, index};
      }
    });
  }

  void _moveSelectedRegionByDrag(int index, Offset delta, Size canvasSize) {
    if (!_selectedSecondStageCells.contains(index)) return;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final baseRegions = _currentGuideRegions();
    if (index < 0 || index >= baseRegions.length) return;

    final current = _customSelectedRegions[index] ?? baseRegions[index];
    final dx = delta.dx / canvasSize.width;
    final dy = delta.dy / canvasSize.height;

    final maxLeft = 1.0 - current.width;
    final maxTop = 1.0 - current.height;

    final nextLeft = (current.left + dx).clamp(0.0, maxLeft);
    final nextTop = (current.top + dy).clamp(0.0, maxTop);

    setState(() {
      _customSelectedRegions = <int, Rect>{
        ..._customSelectedRegions,
        index: Rect.fromLTWH(nextLeft, nextTop, current.width, current.height),
      };
    });
  }

  List<double> _sortedGuides(List<double> guides) {
    final sorted = [...guides]..sort();
    return sorted;
  }

  List<Rect> _currentGuideRegions() {
    final cols = [0.0, ..._sortedGuides(_verticalGuides), 1.0];
    final rows = [0.0, ..._sortedGuides(_horizontalGuides), 1.0];
    final regions = <Rect>[];
    for (var row = 0; row < rows.length - 1; row++) {
      for (var col = 0; col < cols.length - 1; col++) {
        final left = cols[col];
        final right = cols[col + 1];
        final top = rows[row];
        final bottom = rows[row + 1];
        if (right <= left || bottom <= top) continue;
        regions.add(Rect.fromLTWH(left, top, right - left, bottom - top));
      }
    }
    return regions;
  }

  void _addVerticalGuideAt(double positionNormalized) {
    if (_verticalGuides.length >= 4) return;
    final candidate = _clamp01(
      positionNormalized,
    ).clamp(_guideEdgeInset, 1 - _guideEdgeInset);
    final sorted = _sortedGuides(_verticalGuides);
    for (final point in sorted) {
      if ((point - candidate).abs() < _guideMinGap) {
        return;
      }
    }

    setState(() {
      _verticalGuides = _sortedGuides([..._verticalGuides, candidate]);
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeVerticalGuideIndex = _verticalGuides.length - 1;
      _activeHorizontalGuideIndex = null;
    });
  }

  void _addHorizontalGuideAt(double positionNormalized) {
    if (_horizontalGuides.length >= 5) return;
    final candidate = _clamp01(
      positionNormalized,
    ).clamp(_guideEdgeInset, 1 - _guideEdgeInset);
    final sorted = _sortedGuides(_horizontalGuides);
    for (final point in sorted) {
      if ((point - candidate).abs() < _guideMinGap) {
        return;
      }
    }

    setState(() {
      _horizontalGuides = _sortedGuides([..._horizontalGuides, candidate]);
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeHorizontalGuideIndex = _horizontalGuides.length - 1;
      _activeVerticalGuideIndex = null;
    });
  }

  void _removeVerticalGuideAt(int index) {
    if (_verticalGuides.length <= 1) return;
    final updated = [..._sortedGuides(_verticalGuides)];
    if (index < 0 || index >= updated.length) return;

    setState(() {
      updated.removeAt(index);
      _verticalGuides = updated;
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeVerticalGuideIndex = null;
    });
  }

  void _removeHorizontalGuideAt(int index) {
    if (_horizontalGuides.length <= 2) return;
    final updated = [..._sortedGuides(_horizontalGuides)];
    if (index < 0 || index >= updated.length) return;

    setState(() {
      updated.removeAt(index);
      _horizontalGuides = updated;
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeHorizontalGuideIndex = null;
    });
  }

  void _moveVerticalGuide(int index, double deltaNormalized) {
    final sorted = _sortedGuides(_verticalGuides);
    if (index < 0 || index >= sorted.length) return;
    final prev = index == 0 ? 0.0 : sorted[index - 1];
    final next = index == sorted.length - 1 ? 1.0 : sorted[index + 1];
    final current = sorted[index];
    final moved = (current + deltaNormalized).clamp(
      prev + _guideMinGap,
      next - _guideMinGap,
    );
    sorted[index] = moved;
    setState(() {
      _verticalGuides = sorted;
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeVerticalGuideIndex = index;
      _activeHorizontalGuideIndex = null;
    });
  }

  void _moveHorizontalGuide(int index, double deltaNormalized) {
    final sorted = _sortedGuides(_horizontalGuides);
    if (index < 0 || index >= sorted.length) return;
    final prev = index == 0 ? 0.0 : sorted[index - 1];
    final next = index == sorted.length - 1 ? 1.0 : sorted[index + 1];
    final current = sorted[index];
    final moved = (current + deltaNormalized).clamp(
      prev + _guideMinGap,
      next - _guideMinGap,
    );
    sorted[index] = moved;
    setState(() {
      _horizontalGuides = sorted;
      _selectedSecondStageCells = <int>{};
      _customSelectedRegions = <int, Rect>{};
      _activeHorizontalGuideIndex = index;
      _activeVerticalGuideIndex = null;
    });
  }

  void _selectVerticalGuide(int index) {
    setState(() {
      _activeVerticalGuideIndex = index;
      _activeHorizontalGuideIndex = null;
    });
  }

  void _selectHorizontalGuide(int index) {
    setState(() {
      _activeHorizontalGuideIndex = index;
      _activeVerticalGuideIndex = null;
    });
  }

  Future<void> _removeCropItemFromSelectedRecord(
    PhotoAnalysisRecord record,
    String cropPath,
  ) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('추출 이미지 삭제'),
        content: const Text('이 항목을 삭제할까요?\n장농 데이터에서도 함께 제거됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '항목 삭제 중...';
    });

    final provider = context.read<WardrobeProvider>();
    final success = await provider.removeAnalyzedCropItem(
      analysisId: record.id,
      cropPath: cropPath,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });

    if (!success) {
      await _showBlockingMessageDialog(
        title: '삭제 실패',
        message: provider.error ?? '항목 삭제에 실패했습니다.',
      );
      return;
    }

    final updatedRecord = provider.photoAnalyses.where(
      (r) => r.id == record.id,
    );
    setState(() {
      _selectedRecord = updatedRecord.isNotEmpty ? updatedRecord.first : null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('선택한 추출 이미지가 삭제되었습니다.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _precheckService.dispose();
    super.dispose();
  }

  void _scrollToGeneratedPreview() {
    void scrollOnce() {
      if (!mounted) return;

      final targetContext = _generatedPreviewKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
        return;
      }

      if (_mainScrollController.hasClients) {
        _mainScrollController.animateTo(
          _mainScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scrollOnce());
    Future<void>.delayed(const Duration(milliseconds: 220), scrollOnce);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wardrobeProvider = context.watch<WardrobeProvider>();
    final analyses = wardrobeProvider.photoAnalyses;

    return Scaffold(
      appBar: CodiStyledAppBar(
        title: '사진 분석 등록',
        actions: [
          CodiAppBarAction(
            tooltip: '드레스룸',
            icon: Icons.checkroom,
            onTap: () => Navigator.of(context).pushNamed('/wardrobe'),
          ),
          CodiAppBarAction(
            tooltip: '분석목록',
            icon: Icons.auto_awesome,
            onTap: () => Navigator.of(context).pushNamed('/analysis'),
          ),
          CodiAppBarAction(
            tooltip: '코디',
            icon: Icons.style,
            onTap: () => Navigator.of(context).pushNamed('/codi'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(16),
                            color: colors.surfaceContainerHighest,
                          ),
                          child: _selectedImage == null
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight - 16,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '사진을 선택하거나, 촬영해 주세요',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildFirstStageGuide(
                                                colors: colors,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(_selectedImage!.path),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    if (_precheckResult?.failReason ==
                                            PrecheckFailReason
                                                .multiPersonNeedSelect &&
                                        _precheckResult!.persons.isNotEmpty)
                                      _PersonSelectionOverlay(
                                        imagePath: _selectedImage!.path,
                                        imageWidth: _precheckResult!.imageWidth,
                                        imageHeight:
                                            _precheckResult!.imageHeight,
                                        persons: _precheckResult!.persons,
                                        selectedPersonId:
                                            _selectedPersonId ??
                                            _precheckResult!.selectedPersonId,
                                        onSelect: (id) {
                                          setState(() {
                                            _selectedPersonId = id;
                                          });
                                        },
                                      ),
                                    if (_showOriginalReloadOnFailure)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Material(
                                          color: colors.surface.withValues(
                                            alpha: 0.72,
                                          ),
                                          shape: const CircleBorder(),
                                          child: IconButton(
                                            tooltip: '실패 후 다시 추출',
                                            onPressed: _isProcessing
                                                ? null
                                                : _retryFromTopImageAfterFailure,
                                            icon: const Icon(Icons.refresh),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        if (_precheckResult?.failReason ==
                            PrecheckFailReason.multiPersonNeedSelect) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed:
                                _selectedPersonId == null || _isProcessing
                                ? null
                                : _applySelectedPerson,
                            icon: const Icon(Icons.person_search),
                            label: const Text('선택 인물로 분석 진행'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _pickAndAddClothing(
                                        ImageSource.gallery,
                                      ),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('갤러리'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _pickAndAddClothing(
                                        ImageSource.camera,
                                      ),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('촬영'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isThumbnailDetailMode && _selectedRecord != null)
                          _buildThumbnailDetailList(
                            colors: colors,
                            record: _selectedRecord!,
                          )
                        else ...[
                          _buildGeneratedPreviewBox(
                            colors: colors,
                            provider: wardrobeProvider,
                          ),
                          _buildSecondStageRetrySection(
                            colors: colors,
                            provider: wardrobeProvider,
                          ),
                          _buildSelectedCropStrip(
                            colors: colors,
                            provider: wardrobeProvider,
                            record: _selectedRecord,
                          ),
                          _buildInlineAnalysisSection(
                            colors: colors,
                            analyses: analyses,
                          ),
                        ],
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isProcessing) _buildProcessingOverlay(colors: colors),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay({required ColorScheme colors}) {
    return Container(
      color: const Color.fromARGB(120, 0, 0, 0),
      alignment: Alignment.center,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage?.trim().isNotEmpty == true
                      ? _statusMessage!
                      : '추출 중입니다...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAnalysisSection({
    required ColorScheme colors,
    required List<PhotoAnalysisRecord> analyses,
  }) {
    final record = _selectedRecord;
    if (record == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _buildThumbnailDetailList(colors: colors, record: record),
    );
  }

  Widget _buildThumbnailDetailList({
    required ColorScheme colors,
    required PhotoAnalysisRecord record,
  }) {
    if (record.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(record.items.length, (index) {
          final item = record.items[index];
          final imagePath = index < record.croppedImagePaths.length
              ? record.croppedImagePaths[index].trim()
              : '';
          final imageExists =
              imagePath.isNotEmpty && File(imagePath).existsSync();

          final title = _analysisItemLabelKoreanFirst(item);
          final descriptionKo = item.descriptionKo?.trim() ?? '';
          final descriptionEn = item.description.trim();
          final detail = descriptionKo.isNotEmpty
              ? descriptionKo
              : descriptionEn;

          final row = Padding(
            padding: EdgeInsets.only(
              bottom: index == record.items.length - 1 ? 0 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant),
                    color: colors.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageExists
                      ? Image.file(File(imagePath), fit: BoxFit.cover)
                      : Icon(
                          Icons.image_not_supported,
                          color: colors.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _categoryKorean(item.category),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (index == record.items.length - 1) return row;

          return Column(
            children: [
              row,
              Divider(color: colors.outlineVariant, height: 1),
              const SizedBox(height: 10),
            ],
          );
        }),
      ),
    );
  }

  String _categoryKorean(String category) {
    switch (category) {
      case 'top':
        return '상의';
      case 'outerwear':
        return '외투';
      case 'bottom':
        return '하의';
      case 'hat':
        return '모자';
      case 'shoes':
        return '신발';
      case 'accessory':
        return '악세사리';
      default:
        return '기타';
    }
  }

  String _analysisItemLabelKoreanFirst(AnalysisItemTag item) {
    final ko = item.labelKo.trim();
    if (ko.isNotEmpty) return ko;

    final en = item.labelEn.trim();
    if (en.isNotEmpty) return en;

    final base = item.label.trim();
    if (base.isNotEmpty) return base;

    return _categoryKorean(item.category);
  }

  PersonCandidate? _selectedPerson(CapturePrecheckResult? precheck) {
    if (precheck == null || precheck.persons.isEmpty) return null;
    final selectedId =
        _selectedPersonId ??
        precheck.selectedPersonId ??
        precheck.persons.first.id;
    for (final person in precheck.persons) {
      if (person.id == selectedId) {
        return person;
      }
    }
    return precheck.persons.first;
  }

  Widget _buildFirstStageGuide({required ColorScheme colors}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1차 추출 촬영 가이드',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          _buildFirstStageGuideRow(
            colors: colors,
            icon: Icons.person_2_outlined,
            text: '인물은 1명만 나오게 찍어주세요.',
          ),
          _buildFirstStageGuideRow(
            colors: colors,
            icon: Icons.accessibility_new,
            text: '머리부터 발끝까지 전신과 옷 전체가 보이게 해주세요.',
          ),
          _buildFirstStageGuideRow(
            colors: colors,
            icon: Icons.checkroom_outlined,
            text: '상의/하의가 겹치거나 가려지지 않게 해주세요.',
          ),
          _buildFirstStageGuideRow(
            colors: colors,
            icon: Icons.wb_sunny_outlined,
            text: '밝은 곳에서 흔들림 없이 선명하게 촬영해 주세요.',
          ),
        ],
      ),
    );
  }

  Widget _buildFirstStageGuideRow({
    required ColorScheme colors,
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedPreviewBox({
    required ColorScheme colors,
    required WardrobeProvider provider,
  }) {
    final displayPath =
        (provider.generatedPreviewImagePath ??
                _generatedPreviewFile?.path ??
                '')
            .trim();
    final hasImage = displayPath.isNotEmpty && File(displayPath).existsSync();
    final placeholderHeight = max(
      260.0,
      MediaQuery.of(context).size.height * 0.42,
    );
    final showSelectionOverlay =
        provider.canRetrySecondStage ||
        _isRecordEditMode ||
        _selectedSecondStageCells.isNotEmpty;
    final allowGuideEditing = provider.canRetrySecondStage || _isRecordEditMode;
    return Container(
      key: _generatedPreviewKey,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? _buildCanvasAwareImageWidthBased(
              imagePath: displayPath,
              colors: colors,
              enableSelectionOverlay: showSelectionOverlay,
              allowGuideEditing: allowGuideEditing,
              canRegenerateFirstStage:
                  provider.canRetrySecondStage || _isRecordEditMode,
              selectedCells: _selectedSecondStageCells,
              onCellTap: _toggleSecondStageCell,
            )
          : SizedBox(
              height: placeholderHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                child: Center(
                  child: Text(
                    '사진에서 추출된 이미지가 여기에 표시됩니다.\n'
                    '(AI가 생성한 이미지라서 원본과 다를 수 있습니다.)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCanvasAwareImageWidthBased({
    required String imagePath,
    required ColorScheme colors,
    required bool enableSelectionOverlay,
    required bool allowGuideEditing,
    required bool canRegenerateFirstStage,
    required Set<int> selectedCells,
    required ValueChanged<int> onCellTap,
  }) {
    final file = File(imagePath);
    const frameRadius = 0.0;
    const edgeStripSize = 10.0;

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.75),
              width: allowGuideEditing ? 2.6 : 1.6,
            ),
            borderRadius: BorderRadius.circular(frameRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(frameRadius),
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 220,
                child: Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
        if (enableSelectionOverlay)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final regions = _currentGuideRegions();
                final verticals = _sortedGuides(_verticalGuides);
                final horizontals = _sortedGuides(_horizontalGuides);
                final canvasSize = Size(width, height);

                return Stack(
                  children: [
                    ...List.generate(regions.length, (index) {
                      final region =
                          _customSelectedRegions[index] ?? regions[index];
                      final selected = selectedCells.contains(index);
                      return Positioned(
                        left: region.left * width,
                        top: region.top * height,
                        width: region.width * width,
                        height: region.height * height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: allowGuideEditing
                              ? () => onCellTap(index)
                              : null,
                          onPanUpdate: selected && allowGuideEditing
                              ? (details) => _moveSelectedRegionByDrag(
                                  index,
                                  details.delta,
                                  canvasSize,
                                )
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                            ),
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '${index + 1}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (allowGuideEditing)
                      Positioned(
                        left: 0,
                        top: 0,
                        width: width,
                        height: edgeStripSize,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPressStart: (details) {
                            _addVerticalGuideAt(
                              details.localPosition.dx / width,
                            );
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (allowGuideEditing)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: width,
                        height: edgeStripSize,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPressStart: (details) {
                            _addVerticalGuideAt(
                              details.localPosition.dx / width,
                            );
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (allowGuideEditing)
                      Positioned(
                        left: 0,
                        top: 0,
                        width: edgeStripSize,
                        height: height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPressStart: (details) {
                            _addHorizontalGuideAt(
                              details.localPosition.dy / height,
                            );
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (allowGuideEditing)
                      Positioned(
                        right: 0,
                        top: 0,
                        width: edgeStripSize,
                        height: height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPressStart: (details) {
                            _addHorizontalGuideAt(
                              details.localPosition.dy / height,
                            );
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (allowGuideEditing)
                      ...List.generate(verticals.length, (index) {
                        final x = verticals[index] * width;
                        final isActive = _activeVerticalGuideIndex == index;
                        return Positioned(
                          left: x - 12,
                          top: 0,
                          width: 24,
                          height: height,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _selectVerticalGuide(index),
                            onLongPress: () => _removeVerticalGuideAt(index),
                            onHorizontalDragUpdate: (details) {
                              _moveVerticalGuide(
                                index,
                                details.delta.dx / width,
                              );
                            },
                            child: Center(
                              child: Container(
                                width: isActive ? 1.4 : 1.0,
                                height: height,
                                color:
                                    (isActive ? colors.error : colors.primary)
                                        .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        );
                      }),
                    if (allowGuideEditing)
                      ...List.generate(horizontals.length, (index) {
                        final y = horizontals[index] * height;
                        final isActive = _activeHorizontalGuideIndex == index;
                        return Positioned(
                          left: 0,
                          top: y - 12,
                          width: width,
                          height: 24,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _selectHorizontalGuide(index),
                            onLongPress: () => _removeHorizontalGuideAt(index),
                            onVerticalDragUpdate: (details) {
                              _moveHorizontalGuide(
                                index,
                                details.delta.dy / height,
                              );
                            },
                            child: Center(
                              child: Container(
                                width: width,
                                height: isActive ? 1.4 : 1.0,
                                color:
                                    (isActive ? colors.error : colors.primary)
                                        .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        if (enableSelectionOverlay || canRegenerateFirstStage)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: colors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canRegenerateFirstStage)
                      IconButton(
                        tooltip: '사진 다시 추출',
                        onPressed: _isProcessing
                            ? null
                            : _regenerateFirstStageImage,
                        icon: const Icon(Icons.refresh),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondStageRetrySection({
    required ColorScheme colors,
    required WardrobeProvider provider,
  }) {
    if (!provider.canRetrySecondStage && !_isRecordEditMode) {
      return const SizedBox.shrink();
    }

    final attempted = provider.lastSecondStageAttempted;
    final showRetryRequired = attempted && provider.canRetrySecondStage;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              _selectedSecondStageCells.isEmpty
                  ? '선을 드래그해 칸을 조정하고 분석할 블록을 선택해 주세요.\n상단/하단 가장자리를 길게 누르면 세로선, 좌/우 가장자리를 길게 누르면 가로선이 추가됩니다.\n선을 길게 누르면 해당 선이 삭제됩니다.'
                  : '선을 드래그해 칸을 조정할 수 있습니다.\n현재 선택한 ${_selectedSecondStageCells.length}개 블록만 2차 분석됩니다.\n선을 길게 누르면 해당 선이 삭제됩니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _isProcessing || _selectedSecondStageCells.isEmpty
                    ? null
                    : _retrySecondStage,
                icon: Icon(showRetryRequired ? Icons.refresh : Icons.play_arrow),
                label: const Text('선택한 블록 분석'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCropStrip({
    required ColorScheme colors,
    required WardrobeProvider provider,
    required PhotoAnalysisRecord? record,
  }) {
    final sourcePaths = record?.croppedImagePaths.isNotEmpty == true
        ? record!.croppedImagePaths
        : provider.lastSecondStageSelectedCropPaths;

    final paths = sourcePaths
        .where((path) => path.trim().isNotEmpty && File(path).existsSync())
        .toList(growable: false);
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택한 블록 추출 이미지 (${paths.length})',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final path = paths[index];
                return Container(
                  width: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (record != null)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Material(
                            color: colors.surface.withValues(alpha: 0.86),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _removeCropItemFromSelectedRecord(
                                record,
                                path,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSelectionOverlay extends StatefulWidget {
  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final List<PersonCandidate> persons;
  final int? selectedPersonId;
  final ValueChanged<int> onSelect;

  const _PersonSelectionOverlay({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.persons,
    required this.selectedPersonId,
    required this.onSelect,
  });

  @override
  State<_PersonSelectionOverlay> createState() =>
      _PersonSelectionOverlayState();
}

class _PersonSelectionOverlayState extends State<_PersonSelectionOverlay> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = applyBoxFit(
          BoxFit.contain,
          Size(widget.imageWidth.toDouble(), widget.imageHeight.toDouble()),
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        final renderWidth = fitted.destination.width;
        final renderHeight = fitted.destination.height;
        final offsetX = (constraints.maxWidth - renderWidth) / 2;
        final offsetY = (constraints.maxHeight - renderHeight) / 2;

        return Stack(
          children: widget.persons.map((person) {
            final left =
                offsetX +
                (person.boundsPx.left / widget.imageWidth) * renderWidth;
            final top =
                offsetY +
                (person.boundsPx.top / widget.imageHeight) * renderHeight;
            final right =
                offsetX +
                (person.boundsPx.right / widget.imageWidth) * renderWidth;
            final bottom =
                offsetY +
                (person.boundsPx.bottom / widget.imageHeight) * renderHeight;

            final selected = widget.selectedPersonId == person.id;

            return Positioned(
              left: left,
              top: top,
              width: (right - left)
                  .clamp(1, constraints.maxWidth.toInt())
                  .toDouble(),
              height: (bottom - top)
                  .clamp(1, constraints.maxHeight.toInt())
                  .toDouble(),
              child: GestureDetector(
                onTap: () => widget.onSelect(person.id),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? Colors.green : Colors.orange,
                      width: selected ? 3 : 2,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: selected ? Colors.green : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'Person ${person.id + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
