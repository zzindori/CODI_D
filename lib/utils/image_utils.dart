import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// 이미지 유틸리티: 특정 색상을 투명하게 변환
class ImageUtils {
  /// PNG 이미지 로드 후 흰색 배경을 투명하게 변환
  static Future<img.Image?> loadPngWithTransparentBackground(
    String assetPath, {
    int tolerance = 30,
  }) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final img.Image? image = img.decodePng(data.buffer.asUint8List());
      
      if (image == null) return null;

      // 흰색(255,255,255)에 가까운 픽셀을 투명하게 변환
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixelSafe(x, y);
          
          // RGBA 형식에서 색상 값 추출
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          // 흰색에 가까운지 확인 (tolerance 범위 내)
          if (r > 255 - tolerance && g > 255 - tolerance && b > 255 - tolerance) {
            // 투명하게 설정 (알파값 0)
            image.setPixel(x, y, img.ColorRgba8(r, g, b, 0));
          }
        }
      }
      
      return image;
    } catch (e) {
      return null;
    }
  }

  /// 처리된 이미지를 PNG로 인코딩
  static Uint8List? encodePng(img.Image image) {
    try {
      return img.encodePng(image);
    } catch (e) {
      return null;
    }
  }
}
