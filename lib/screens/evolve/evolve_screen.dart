import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/photo_analysis_record.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/ondevice_precheck_service.dart';

/// 옷 추가 화면 (v3.0 - 간소화)
/// 
/// 원칙:
/// - 갤러리/카메라에서 옷 사진 선택
/// - Gemini로 자동 분석
/// - 크롭/마스크 없이 원본 사진 그대로 저장
class EvolveScreen extends StatefulWidget {
  const EvolveScreen({super.key});

  @override
  State<EvolveScreen> createState() => _EvolveScreenState();
}

class _EvolveScreenState extends State<EvolveScreen> {
  final ImagePicker _picker = ImagePicker();
  final OnDevicePrecheckService _precheckService = OnDevicePrecheckService();

  XFile? _selectedImage;
  CapturePrecheckResult? _precheckResult;
  int? _selectedPersonId;
  PhotoAnalysisRecord? _selectedRecord;
  bool _isDetailPopupVisible = false;
  OverlayEntry? _detailOverlayEntry;
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _pickAndAddClothing(ImageSource source) async {
    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = '사진을 선택하는 중...';
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
        _selectedPersonId = null;
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
          });
          return;
        }

        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(precheck.message)));
        return;
      }

      final success = await _runFullAnalysis(precheck);

      if (!mounted) return;
      
      if (success) {
        final latest = context.read<WardrobeProvider>().photoAnalyses.isNotEmpty
            ? context.read<WardrobeProvider>().photoAnalyses.first
            : null;
        setState(() {
          _selectedRecord = latest;
        });
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('추가 완료!'),
            content: const Text('사진 분석이 저장되었습니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        final wardrobeProvider = context.read<WardrobeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: ${wardrobeProvider.error ?? "알 수 없는 오류"}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<bool> _runFullAnalysis(CapturePrecheckResult precheck) async {
    if (_selectedImage == null) return false;

    setState(() {
      _statusMessage = 'Gemini 전체 이미지 분석 중...';
    });

    final wardrobeProvider = context.read<WardrobeProvider>();
    final personCount = precheck.persons.isEmpty ? 1 : precheck.persons.length;
    final selectedPerson = _selectedPerson(precheck);

    final success = await wardrobeProvider.addPhotoAnalysisFromImage(
      _selectedImage!.path,
      personCount: personCount,
      selectedPersonId: precheck.selectedPersonId,
      brightnessScore: precheck.brightnessScore,
      sharpnessScore: precheck.sharpnessScore,
      topCoverageScore: selectedPerson?.topCoverageScore ?? 0,
      bottomCoverageScore: selectedPerson?.bottomCoverageScore ?? 0,
    );

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
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(precheck.message)));
      return;
    }

    final success = await _runFullAnalysis(precheck);
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });

    if (!success) {
      final message = context.read<WardrobeProvider>().error ?? '알 수 없는 오류';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('분석 실패: $message')));
      return;
    }

    final latest = context.read<WardrobeProvider>().photoAnalyses.isNotEmpty
        ? context.read<WardrobeProvider>().photoAnalyses.first
        : null;
    setState(() {
      _selectedRecord = latest;
    });
  }

  void _openOrUpdateDetailOverlay(PhotoAnalysisRecord record) {
    setState(() {
      _selectedRecord = record;
      _isDetailPopupVisible = true;
    });

    if (_detailOverlayEntry == null) {
      _detailOverlayEntry = OverlayEntry(
        builder: (overlayContext) {
          final currentRecord = _selectedRecord;
          if (!_isDetailPopupVisible || currentRecord == null) {
            return const SizedBox.shrink();
          }
          return _buildAnalysisOverlay(overlayContext, currentRecord);
        },
      );

      Overlay.of(context, rootOverlay: true).insert(_detailOverlayEntry!);
      return;
    }

    _detailOverlayEntry!.markNeedsBuild();
  }

  void _closeDetailOverlay() {
    if (_isDetailPopupVisible) {
      setState(() {
        _isDetailPopupVisible = false;
      });
    }
    _detailOverlayEntry?.remove();
    _detailOverlayEntry = null;
  }

  Future<void> _deleteAnalysisRecord(PhotoAnalysisRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 분석 기록과 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final wardrobeProvider = context.read<WardrobeProvider>();
    final success = await wardrobeProvider.deletePhotoAnalysis(record.id);

    if (!mounted) return;
    _closeDetailOverlay();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 실패')),
      );
    }
  }

  @override
  void dispose() {
    _detailOverlayEntry?.remove();
    _detailOverlayEntry = null;
    _precheckService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final analyses = context.watch<WardrobeProvider>().photoAnalyses;
    final selectedCoverage = _selectedCoverageScore();
    final selectedTopCoverage = _selectedTopCoverageScore();
    final selectedBottomCoverage = _selectedBottomCoverageScore();

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 분석 등록'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                                  child: Icon(Icons.photo_library, size: 28, color: colors.primary),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '사진을 선택해주세요',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
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
                                     if (_precheckResult?.failReason == PrecheckFailReason.multiPersonNeedSelect &&
                                         _precheckResult!.persons.isNotEmpty)
                                _PersonSelectionOverlay(
                                  imagePath: _selectedImage!.path,
                                  imageWidth: _precheckResult!.imageWidth,
                                  imageHeight: _precheckResult!.imageHeight,
                                  persons: _precheckResult!.persons,
                                  selectedPersonId: _selectedPersonId ?? _precheckResult!.selectedPersonId,
                                  onSelect: (id) {
                                    setState(() {
                                      _selectedPersonId = id;
                                    });
                                  },
                                ),
                            ],
                          ),
                  ),
                        if (_precheckResult?.failReason == PrecheckFailReason.multiPersonNeedSelect) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _selectedPersonId == null || _isProcessing ? null : _applySelectedPerson,
                            icon: const Icon(Icons.person_search),
                            label: const Text('선택 인물로 분석 진행'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                        if (_selectedImage != null && _precheckResult != null) ...[
                          const SizedBox(height: 8),
                          Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '감지 결과',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            child: Scrollbar(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  _InfoRow(label: '감지 인원', value: '${_precheckResult!.persons.length}명'),
                                  _InfoRow(label: '밝기 점수', value: _precheckResult!.brightnessScore.toStringAsFixed(1)),
                                  _InfoRow(label: '선명도 점수', value: _precheckResult!.sharpnessScore.toStringAsFixed(1)),
                                  _InfoRow(label: '옷 노출 추정', value: '${(selectedCoverage * 100).toStringAsFixed(0)}%'),
                                  _InfoRow(
                                    label: '상의 노출',
                                    value: '${(selectedTopCoverage * 100).toStringAsFixed(0)}% ${selectedTopCoverage >= 0.9 ? '통과' : '부족'}',
                                    highlight: selectedTopCoverage < 0.9,
                                  ),
                                  _InfoRow(
                                    label: '하의 노출',
                                    value: '${(selectedBottomCoverage * 100).toStringAsFixed(0)}% ${selectedBottomCoverage >= 0.9 ? '통과' : '부족'}',
                                    highlight: selectedBottomCoverage < 0.9,
                                  ),
                                  ..._precheckResult!.persons.map(
                                    (person) => _InfoRow(
                                      label: 'Person ${person.id + 1}',
                                      value: '노출 ${(person.coverageScore * 100).toStringAsFixed(0)}%',
                                      highlight: (_selectedPersonId ?? _precheckResult!.selectedPersonId) == person.id,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18, color: colors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(_statusMessage!)),
                                      if (_isProcessing)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isProcessing ? null : () => _pickAndAddClothing(ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('갤러리'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isProcessing ? null : () => _pickAndAddClothing(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('촬영'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
                    ],
                  ),
                ),
              ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(top: BorderSide(color: colors.outlineVariant)),
                  ),
                  child: analyses.isEmpty
                      ? const SizedBox(
                          height: 64,
                          child: Center(child: Text('아직 분석된 사진이 없습니다')),
                        )
                        : SizedBox(
                          height: 64,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: analyses.length,
                            itemBuilder: (context, index) {
                              final record = analyses[index];
                              final selected = _selectedRecord?.id == record.id;
                              return GestureDetector(
                                onTap: () {
                                  _openOrUpdateDetailOverlay(record);
                                },
                                child: Container(
                                  width: 62,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: selected ? colors.primary : colors.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.file(
                                    File(record.imagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: const Color.fromARGB(120, 0, 0, 0),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisOverlay(BuildContext overlayContext, PhotoAnalysisRecord record) {
    final colors = Theme.of(overlayContext).colorScheme;
    final bottomInteractiveHeight = 64.0 + 8.0 + 10.0 + MediaQuery.of(overlayContext).padding.bottom;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            bottom: bottomInteractiveHeight,
            child: GestureDetector(
              onTap: () {
                _closeDetailOverlay();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: bottomInteractiveHeight,
            child: Material(
              color: colors.surface,
              elevation: 18,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: MediaQuery.of(overlayContext).size.width * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '분석 상세',
                              style: Theme.of(overlayContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteAnalysisRecord(record),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '삭제',
                          ),
                          IconButton(
                            onPressed: _closeDetailOverlay,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.outlineVariant),
                                color: colors.surfaceContainerLowest,
                              ),
                              child: Image.file(
                                File(record.imagePath),
                                height: 300,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(
                                  height: 300,
                                  child: Center(child: Icon(Icons.broken_image)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (record.topCoverageScore < 0.9 || record.bottomCoverageScore < 0.9)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '안내: 상의/하의 노출이 90% 미만인 항목은 카테고리 목록(탭/검색)에서 자동 제외됩니다.',
                                  style: Theme.of(overlayContext).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
                                ),
                              ),
                            Expanded(
                              child: _buildCompactItemSummary(record, colors),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryKorean(String category) {
    switch (category) {
      case 'top':
        return '상의';
      case 'bottom':
        return '하의';
      case 'hat':
        return '모자';
      case 'shoes':
        return '신발';
      default:
        return '악세사리';
    }
  }

  Widget _buildCompactItemSummary(PhotoAnalysisRecord record, ColorScheme colors) {
    final grouped = <String, List<AnalysisItemTag>>{};
    for (final item in record.items) {
      grouped.putIfAbsent(item.category, () => <AnalysisItemTag>[]).add(item);
    }

    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    const coreCategoryOrder = ['top', 'bottom', 'shoes', 'accessory'];
    final hasHat = grouped.containsKey('hat');
    final categoryRows = [
      ...coreCategoryOrder,
      if (hasHat) 'hat',
    ];

    return SingleChildScrollView(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(categoryRows.length, (index) {
            final category = categoryRows[index];
            final items = grouped[category] ?? const <AnalysisItemTag>[];
            final labels = items.isEmpty
                ? '-'
                : items
                    .map((item) => item.eligibleForCategory ? item.label : '${item.label}(부족)')
                    .join(', ');
            final hasIneligible = items.any((item) => !item.eligibleForCategory);

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == categoryRows.length - 1 ? Colors.transparent : colors.outlineVariant,
                  ),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      color: colors.surfaceContainerHighest,
                      alignment: Alignment.topLeft,
                      child: Text(
                        _categoryKorean(category),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hasIneligible ? colors.error : colors.onSurface,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            labels,
                            style: Theme.of(context).textTheme.bodyMedium,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  double _selectedCoverageScore() {
    if (_precheckResult == null || _precheckResult!.persons.isEmpty) return 0;
    final selectedId = _selectedPersonId ?? _precheckResult!.selectedPersonId ?? _precheckResult!.persons.first.id;
    for (final person in _precheckResult!.persons) {
      if (person.id == selectedId) {
        return person.coverageScore;
      }
    }
    return _precheckResult!.persons.first.coverageScore;
  }

  double _selectedTopCoverageScore() {
    final selected = _selectedPerson(_precheckResult);
    return selected?.topCoverageScore ?? 0;
  }

  double _selectedBottomCoverageScore() {
    final selected = _selectedPerson(_precheckResult);
    return selected?.bottomCoverageScore ?? 0;
  }

  PersonCandidate? _selectedPerson(CapturePrecheckResult? precheck) {
    if (precheck == null || precheck.persons.isEmpty) return null;
    final selectedId = _selectedPersonId ?? precheck.selectedPersonId ?? precheck.persons.first.id;
    for (final person in precheck.persons) {
      if (person.id == selectedId) {
        return person;
      }
    }
    return precheck.persons.first;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueColor = highlight ? colors.error : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor,
              fontWeight: FontWeight.w700,
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
  State<_PersonSelectionOverlay> createState() => _PersonSelectionOverlayState();
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
            final left = offsetX + (person.boundsPx.left / widget.imageWidth) * renderWidth;
            final top = offsetY + (person.boundsPx.top / widget.imageHeight) * renderHeight;
            final right = offsetX + (person.boundsPx.right / widget.imageWidth) * renderWidth;
            final bottom = offsetY + (person.boundsPx.bottom / widget.imageHeight) * renderHeight;

            final selected = widget.selectedPersonId == person.id;

            return Positioned(
              left: left,
              top: top,
              width: (right - left).clamp(1, constraints.maxWidth.toInt()).toDouble(),
              height: (bottom - top).clamp(1, constraints.maxHeight.toInt()).toDouble(),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Person ${person.id + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
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
