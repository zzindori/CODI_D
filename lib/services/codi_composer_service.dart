import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 코디 합성 서비스
/// 
/// 기본 마네킹(또는 진화된 아바타) 위에 상의/하의를 합성한다.
class CodiComposerService {
  Future<File?> compose({
    required String basePath,
    required List<String> clothingImagePaths,
  }) async {
    try {
      final baseBytes = await _loadImageBytes(basePath);
      final baseImage = img.decodeImage(baseBytes);
      if (baseImage == null) return null;

      var composed = img.Image.from(baseImage);

      for (final path in clothingImagePaths) {
        final bytes = await _loadImageBytes(path);
        final clothing = img.decodeImage(bytes);
        if (clothing == null) continue;

        final resized = img.copyResize(
          clothing,
          width: baseImage.width,
          height: baseImage.height,
        );

        composed = img.compositeImage(composed, resized);
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/codi_$timestamp.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodePng(composed));
      return outputFile;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _loadImageBytes(String path) async {
    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    }
    return File(path).readAsBytes();
  }
}
