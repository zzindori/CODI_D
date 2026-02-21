import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

enum PrecheckFailReason {
  noPerson,
  multiPersonNeedSelect,
  lowResolution,
  lowLight,
  blurry,
  lowCoverage,
}

class PersonCandidate {
  final int id;
  final ui.Rect boundsPx;
  final double coverageScore;
  final double topCoverageScore;
  final double bottomCoverageScore;

  const PersonCandidate({
    required this.id,
    required this.boundsPx,
    required this.coverageScore,
    required this.topCoverageScore,
    required this.bottomCoverageScore,
  });
}

class CapturePrecheckResult {
  final bool canAnalyze;
  final String message;
  final PrecheckFailReason? failReason;
  final List<PersonCandidate> persons;
  final int? selectedPersonId;
  final int imageWidth;
  final int imageHeight;
  final double brightnessScore;
  final double sharpnessScore;

  const CapturePrecheckResult({
    required this.canAnalyze,
    required this.message,
    this.failReason,
    this.persons = const [],
    this.selectedPersonId,
    required this.imageWidth,
    required this.imageHeight,
    required this.brightnessScore,
    required this.sharpnessScore,
  });
}

class OnDevicePrecheckService {
  OnDevicePrecheckService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: false,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.fast,
          ),
        ),
        _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            model: PoseDetectionModel.base,
            mode: PoseDetectionMode.single,
          ),
        );

  final FaceDetector _faceDetector;
  final PoseDetector _poseDetector;

  static const int _minWidth = 320;
  static const int _minHeight = 320;
  static const double _minBrightness = 18.0;
  static const double _minSharpness = 6.0;
  static const double _minCoverageHardFail = 0.45;
  static const double _recommendedCoverage = 0.90;

  Future<CapturePrecheckResult> analyze(
    String imagePath, {
    int? selectedPersonId,
  }) async {
    final imageData = await _decodeImage(imagePath);
    if (imageData == null) {
      return const CapturePrecheckResult(
        canAnalyze: false,
        message: '이미지를 읽을 수 없습니다.',
        failReason: PrecheckFailReason.lowResolution,
        imageWidth: 0,
        imageHeight: 0,
        brightnessScore: 0,
        sharpnessScore: 0,
      );
    }

    final resolutionFail = _checkResolution(imageData.width, imageData.height);
    final brightness = _calculateBrightness(imageData.image);
    final sharpness = _calculateSharpness(imageData.image);

    if (resolutionFail != null) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: resolutionFail,
        failReason: PrecheckFailReason.lowResolution,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    if (brightness < _minBrightness && sharpness < (_minSharpness * 0.8)) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: '사진이 너무 어둡고 흐려 식별이 어렵습니다. 조금 더 밝고 선명하게 촬영해 주세요.',
        failReason: PrecheckFailReason.lowLight,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    if (sharpness < _minSharpness && brightness < (_minBrightness * 1.4)) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: '사진이 너무 흐려 식별이 어렵습니다. 흔들림 없이 다시 촬영해 주세요.',
        failReason: PrecheckFailReason.blurry,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    final persons = await _detectPersons(imagePath, imageData.width, imageData.height);
    if (persons.isEmpty) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: '사람이 감지되지 않았습니다. 사람이 포함된 사진을 선택해 주세요.',
        failReason: PrecheckFailReason.noPerson,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    if (persons.length > 1 && selectedPersonId == null) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: '2인 이상 감지되었습니다. 분석할 인물을 선택해 주세요.',
        failReason: PrecheckFailReason.multiPersonNeedSelect,
        persons: persons,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    final selected = selectedPersonId ?? persons.first.id;
    final selectedPerson = persons.firstWhere(
      (person) => person.id == selected,
      orElse: () => persons.first,
    );

    if (selectedPerson.coverageScore < _minCoverageHardFail) {
      return CapturePrecheckResult(
        canAnalyze: false,
        message: '선택 인물의 옷 노출이 너무 적어 분석이 어렵습니다. 전신/반신이 더 잘 보이게 촬영해 주세요.',
        failReason: PrecheckFailReason.lowCoverage,
        persons: persons,
        selectedPersonId: selected,
        imageWidth: imageData.width,
        imageHeight: imageData.height,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
      );
    }

    final coverageMessage = selectedPerson.coverageScore >= _recommendedCoverage
        ? '온디바이스 필터를 통과했습니다. AI 분석을 시작합니다.'
        : '통과: 분석 가능하지만 옷 노출이 90% 미만입니다. (정확도 낮아질 수 있음)';

    return CapturePrecheckResult(
      canAnalyze: true,
      message: coverageMessage,
      persons: persons,
      selectedPersonId: selected,
      imageWidth: imageData.width,
      imageHeight: imageData.height,
      brightnessScore: brightness,
      sharpnessScore: sharpness,
    );
  }

  Future<List<PersonCandidate>> _detectPersons(
    String imagePath,
    int width,
    int height,
  ) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isNotEmpty) {
      return List.generate(poses.length, (index) {
        final pose = poses[index];
        final xs = <double>[];
        final ys = <double>[];

        for (final landmark in pose.landmarks.values) {
          xs.add(landmark.x);
          ys.add(landmark.y);
        }

        if (xs.isEmpty || ys.isEmpty) {
          return PersonCandidate(
            id: index,
            boundsPx: ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            coverageScore: 0.5,
            topCoverageScore: 0.5,
            bottomCoverageScore: 0.5,
          );
        }

        final left = math.max(0, xs.reduce(math.min) - 60).toDouble();
        final right = math.min(width.toDouble(), xs.reduce(math.max) + 60).toDouble();
        final top = math.max(0, ys.reduce(math.min) - 80).toDouble();
        final bottom = math.min(height.toDouble(), ys.reduce(math.max) + 120).toDouble();

        final topCoverage = _estimateTopCoverageFromPose(pose);
        final bottomCoverage = _estimateBottomCoverageFromPose(pose);

        return PersonCandidate(
          id: index,
          boundsPx: ui.Rect.fromLTRB(left, top, right, bottom),
          coverageScore: (topCoverage + bottomCoverage) / 2,
          topCoverageScore: topCoverage,
          bottomCoverageScore: bottomCoverage,
        );
      });
    }

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      return List.generate(faces.length, (index) {
        final face = faces[index];
        final faceBox = face.boundingBox;
        final expanded = ui.Rect.fromLTRB(
          math.max(0, faceBox.left - faceBox.width * 0.8).toDouble(),
          math.max(0, faceBox.top - faceBox.height * 0.7).toDouble(),
          math.min(width.toDouble(), faceBox.right + faceBox.width * 0.8).toDouble(),
          math.min(height.toDouble(), faceBox.bottom + faceBox.height * 3.5).toDouble(),
        );
        return PersonCandidate(
          id: index,
          boundsPx: expanded,
          coverageScore: 0.35,
          topCoverageScore: 0.35,
          bottomCoverageScore: 0.20,
        );
      });
    }

    return const [];
  }

  double _estimateTopCoverageFromPose(Pose pose) {
    final leftShoulder = pose.landmarks.containsKey(PoseLandmarkType.leftShoulder);
    final rightShoulder = pose.landmarks.containsKey(PoseLandmarkType.rightShoulder);
    final leftHip = pose.landmarks.containsKey(PoseLandmarkType.leftHip);
    final rightHip = pose.landmarks.containsKey(PoseLandmarkType.rightHip);

    var score = 0.0;
    if (leftShoulder && rightShoulder) {
      score += 0.5;
    } else if (leftShoulder || rightShoulder) {
      score += 0.3;
    }

    if (leftHip && rightHip) {
      score += 0.5;
    } else if (leftHip || rightHip) {
      score += 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  double _estimateBottomCoverageFromPose(Pose pose) {
    final leftHip = pose.landmarks.containsKey(PoseLandmarkType.leftHip);
    final rightHip = pose.landmarks.containsKey(PoseLandmarkType.rightHip);
    final leftKnee = pose.landmarks.containsKey(PoseLandmarkType.leftKnee);
    final rightKnee = pose.landmarks.containsKey(PoseLandmarkType.rightKnee);
    final leftAnkle = pose.landmarks.containsKey(PoseLandmarkType.leftAnkle);
    final rightAnkle = pose.landmarks.containsKey(PoseLandmarkType.rightAnkle);

    var score = 0.0;
    if (leftHip && rightHip) {
      score += 0.34;
    } else if (leftHip || rightHip) {
      score += 0.2;
    }

    if (leftKnee && rightKnee) {
      score += 0.33;
    } else if (leftKnee || rightKnee) {
      score += 0.2;
    }

    if (leftAnkle && rightAnkle) {
      score += 0.33;
    } else if (leftAnkle || rightAnkle) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  String? _checkResolution(int width, int height) {
    if (width < _minWidth || height < _minHeight) {
      return '해상도가 너무 낮아 식별이 어렵습니다 (${width}x$height). 최소 ${_minWidth}x$_minHeight 이상으로 촬영해 주세요.';
    }
    return null;
  }

  double _calculateBrightness(img.Image image) {
    var sum = 0.0;
    var count = 0;

    final stepY = math.max(1, image.height ~/ 120);
    final stepX = math.max(1, image.width ~/ 120);

    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        sum += (0.299 * r) + (0.587 * g) + (0.114 * b);
        count++;
      }
    }

    return count == 0 ? 0 : sum / count;
  }

  double _calculateSharpness(img.Image image) {
    final stepY = math.max(1, image.height ~/ 200);
    final stepX = math.max(1, image.width ~/ 200);

    final values = <double>[];
    for (var y = stepY; y < image.height - stepY; y += stepY) {
      for (var x = stepX; x < image.width - stepX; x += stepX) {
        final p = image.getPixel(x, y);
        final px1 = image.getPixel(x + stepX, y);
        final py1 = image.getPixel(x, y + stepY);

        final l = _luma(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        final lx = _luma(px1.r.toDouble(), px1.g.toDouble(), px1.b.toDouble());
        final ly = _luma(py1.r.toDouble(), py1.g.toDouble(), py1.b.toDouble());

        final gradient = ((lx - l).abs() + (ly - l).abs()) / 2.0;
        values.add(gradient);
      }
    }

    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        values.length;
    return variance.sqrt();
  }

  double _luma(double r, double g, double b) => (0.299 * r) + (0.587 * g) + (0.114 * b);

  Future<_ImageData?> _decodeImage(String imagePath) async {
    try {
      final bytes = await ui.ImmutableBuffer.fromFilePath(imagePath);
      final descriptor = await ui.ImageDescriptor.encoded(bytes);

      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      frame.image.dispose();

      final raw = await img.decodeImageFile(imagePath);
      if (raw == null) return null;

      return _ImageData(
        width: descriptor.width,
        height: descriptor.height,
        image: raw,
      );
    } catch (e) {
      debugPrint('[Precheck] 이미지 디코드 실패: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _faceDetector.close();
    await _poseDetector.close();
  }
}

class _ImageData {
  final int width;
  final int height;
  final img.Image image;

  const _ImageData({
    required this.width,
    required this.height,
    required this.image,
  });
}

extension on double {
  double sqrt() => math.sqrt(this);
}
