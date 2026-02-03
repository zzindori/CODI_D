import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/wardrobe_provider.dart';

/// 옷 자동 추출 및 등록 화면
///
/// **원칙:**
/// - 사용자의 1회 행동(사진 선택) → 즉시 결과 반영
/// - 전신 사진에서 상의/하의 자동 감지 및 추출
class EvolveScreen extends StatefulWidget {
  const EvolveScreen({super.key});

  @override
  State<EvolveScreen> createState() => _EvolveScreenState();
}

class _EvolveScreenState extends State<EvolveScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;
  String? _statusMessage;
  List<dynamic>? _detectedPeople;
  int? _selectedPersonId;

  /// 사진 선택 및 옷 추출
  Future<void> _pickAndExtract(ImageSource source) async {
    if (_isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = '사진을 선택하는 중...';
      });

      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedImage = picked;
        _statusMessage = '사진을 분석하는 중...';
      });

      final wardrobeProvider = context.read<WardrobeProvider>();
      final analysis = await wardrobeProvider.analyzeClothingFromImage(
        picked.path,
      );

      if (!mounted) return;
      if (analysis == null) {
        throw Exception('사진 분석에 실패했습니다.');
      }

      // 여러 명 감지
      final people = analysis['people'] as List<dynamic>?;
      if (people == null || people.isEmpty) {
        throw Exception('사진에서 옷을 감지하지 못했습니다.');
      }

      // UI 업데이트: 사진 표시 + 사람 선택 기다리기
      setState(() {
        _selectedImage = picked;
        _detectedPeople = people;
        _selectedPersonId = null;
        _statusMessage = null;
        _isProcessing = false;
      });

      // 여러 명이면 선택 대기, 한 명이면 자동 선택
      if (people.length == 1) {
        if (mounted) {
          setState(() => _selectedPersonId = 0);
          await _processSelectedPerson();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 선택된 사람의 옷 추출 및 저장
  Future<void> _processSelectedPerson() async {
    if (_selectedPersonId == null || _detectedPeople == null) return;

    setState(() => _isProcessing = true);

    try {
      final selectedPerson =
          _detectedPeople![_selectedPersonId!] as Map<String, dynamic>;
      final hasTop = selectedPerson['hasTop'] == true;
      final hasBottom = selectedPerson['hasBottom'] == true;

      if (!hasTop && !hasBottom) {
        throw Exception('선택한 사람에게서 옷을 감지하지 못했습니다.');
      }

      final wardrobeProvider = context.read<WardrobeProvider>();
      int extractedCount = 0;

      if (hasTop) {
        setState(() => _statusMessage = '상의를 추출하는 중...');
        final topBounds = selectedPerson['topBounds'] as Map<String, dynamic>?;
        final ok = await wardrobeProvider.addClothing(
          name: (selectedPerson['topDescription'] ?? '상의').toString(),
          typeId: 'top',
          imagePath: _selectedImage!.path,
          bounds: topBounds != null
              ? {
                  'left': (topBounds['left'] as num?)?.toDouble() ?? 0.0,
                  'top': (topBounds['top'] as num?)?.toDouble() ?? 0.0,
                  'right': (topBounds['right'] as num?)?.toDouble() ?? 1.0,
                  'bottom': (topBounds['bottom'] as num?)?.toDouble() ?? 1.0,
                }
              : null,
        );
        if (ok) extractedCount++;
      }

      if (hasBottom) {
        setState(() => _statusMessage = '하의를 추출하는 중...');
        final bottomBounds = selectedPerson['bottomBounds'] as Map<String, dynamic>?;
        final ok = await wardrobeProvider.addClothing(
          name: (selectedPerson['bottomDescription'] ?? '하의').toString(),
          typeId: 'bottom',
          imagePath: _selectedImage!.path,
          bounds: bottomBounds != null
              ? {
                  'left': (bottomBounds['left'] as num?)?.toDouble() ?? 0.0,
                  'top': (bottomBounds['top'] as num?)?.toDouble() ?? 0.0,
                  'right': (bottomBounds['right'] as num?)?.toDouble() ?? 1.0,
                  'bottom':
                      (bottomBounds['bottom'] as num?)?.toDouble() ?? 1.0,
                }
              : null,
        );
        if (ok) extractedCount++;
      }

      if (!mounted) return;
      if (extractedCount > 0) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('추출 완료!'),
            content: Text('$extractedCount개의 옷이 옷장에 추가되었습니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('옷 추출에 실패했습니다. 다시 시도해주세요.')),
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
          _selectedImage = null;
          _detectedPeople = null;
          _selectedPersonId = null;
        });
      }
    }
  }

  /// 정규화된 좌표(0.0-1.0)에서 어느 사람이 있는지 확인
  int? _getPersonAtPoint(Offset point, Size normalizedSize) {
    if (_detectedPeople == null) return null;

    for (int i = 0; i < _detectedPeople!.length; i++) {
      final person = _detectedPeople![i] as Map<String, dynamic>;
      
      // 이 사람의 모든 박스 (상의/하의) 확인
      final bounds = <Map<String, dynamic>>[];
      
      final topBounds = person['topBounds'] as Map<String, dynamic>?;
      if (topBounds != null) bounds.add(topBounds);
      
      final bottomBounds = person['bottomBounds'] as Map<String, dynamic>?;
      if (bottomBounds != null) bounds.add(bottomBounds);

      for (final bound in bounds) {
        final left = (bound['left'] as num?)?.toDouble() ?? 0.0;
        final top = (bound['top'] as num?)?.toDouble() ?? 0.0;
        final right = (bound['right'] as num?)?.toDouble() ?? 1.0;
        final bottom = (bound['bottom'] as num?)?.toDouble() ?? 1.0;

        // 정규화된 좌표로 직접 비교
        if (point.dx >= left && point.dx <= right &&
            point.dy >= top && point.dy <= bottom) {
          debugPrint('Person $i detected at normalized point: ${point.dx}, ${point.dy}');
          return i;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const title = '옷 자동 등록';
    const description = 'AI가 사진에서 착용한 옷을 자동으로 분석하여 옷장에 추가합니다';
    const galleryLabel = '갤러리에서 선택';
    const cameraLabel = '사진 촬영';

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: _selectedImage == null
                        ? const Center(
                            child: Icon(Icons.photo, size: 64, color: Colors.grey),
                          )
                        : _selectedPersonId == null && _detectedPeople != null && _detectedPeople!.isNotEmpty
                            ? GestureDetector(
                                onTapDown: (TapDownDetails details) {
                                  // 컨테이너 내 이미지의 실제 크기 계산
                                  final file = File(_selectedImage!.path);
                                  final imageProvider = FileImage(file);
                                  imageProvider.resolve(ImageConfiguration.empty).addListener(
                                    ImageStreamListener((image, synchronousCall) {
                                      final imageSize = Size(
                                        image.image.width.toDouble(),
                                        image.image.height.toDouble(),
                                      );
                                      // 컨테이너 크기 (높이 300)에 맞춘 스케일링된 이미지 크기
                                      final aspectRatio = imageSize.width / imageSize.height;
                                      final displayHeight = 300.0;
                                      final displayWidth = displayHeight * aspectRatio;
                                      
                                      // 이미지가 컨테이너 내에서 중앙 정렬되므로
                                      final containerWidth = MediaQuery.of(context).size.width - 32; // 양쪽 padding 16씩
                                      final offsetX = (containerWidth - displayWidth) / 2;
                                      
                                      // 상대 좌표를 이미지 크기 기준으로 변환
                                      final tapX = (details.localPosition.dx - offsetX) / displayWidth;
                                      final tapY = details.localPosition.dy / displayHeight;
                                      
                                      final personId = _getPersonAtPoint(
                                        Offset(tapX, tapY),
                                        Size(1.0, 1.0), // 정규화된 좌표
                                      );
                                      
                                      if (personId != null && mounted) {
                                        setState(() {
                                          _selectedPersonId = personId;
                                        });
                                        _processSelectedPerson();
                                      }
                                    }),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(_selectedImage!.path),
                                        fit: BoxFit.contain,
                                      ),
                                      CustomPaint(
                                        painter: _BoundingBoxPainter(_detectedPeople ?? []),
                                        size: Size.infinite,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndExtract(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text(galleryLabel),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndExtract(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(cameraLabel),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: const Color.fromARGB(128, 0, 0, 0),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 인물 선택 UI를 위한 경계 상자 그리기
class _BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detectedPeople;

  _BoundingBoxPainter(this.detectedPeople);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const ui.Color.fromARGB(128, 255, 0, 0),    // 빨강 (상의)
      const ui.Color.fromARGB(128, 0, 0, 255),    // 파랑 (하의)
      const ui.Color.fromARGB(128, 0, 255, 0),    // 초록 (다음 인물)
      const ui.Color.fromARGB(128, 255, 165, 0),  // 주황색
      const ui.Color.fromARGB(128, 128, 0, 128),  // 보라색
    ];

    for (int i = 0; i < detectedPeople.length; i++) {
      final person = detectedPeople[i] as Map<String, dynamic>;
      final color = colors[i % colors.length];
      final paint = ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3;

      // 상의 경계 상자 그리기
      if (person['hasTop'] == true && person['topBounds'] != null) {
        final topBounds = person['topBounds'] as Map<String, dynamic>;
        final rect = _getNormalizedRect(topBounds, size);
        canvas.drawRect(rect, paint);

        // 상의 라벨
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'Person ${i + 1} - Top',
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
      }

      // 하의 경계 상자 그리기
      if (person['hasBottom'] == true && person['bottomBounds'] != null) {
        final bottomBounds = person['bottomBounds'] as Map<String, dynamic>;
        final rect = _getNormalizedRect(bottomBounds, size);
        final paint2 = ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRect(rect, paint2);

        // 하의 라벨
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'Person ${i + 1} - Bottom',
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
      }
    }
  }

  /// 정규화된 좌표(0.0-1.0)를 화면 픽셀 기준 Rect로 변환
  ui.Rect _getNormalizedRect(Map<String, dynamic> bounds, Size size) {
    final left = (bounds['left'] as num?)?.toDouble() ?? 0.0;
    final top = (bounds['top'] as num?)?.toDouble() ?? 0.0;
    final right = (bounds['right'] as num?)?.toDouble() ?? 1.0;
    final bottom = (bounds['bottom'] as num?)?.toDouble() ?? 1.0;

    return ui.Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
