import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const int _maxDimension = 1280;

  static Uint8List enhance(Uint8List rawBytes) {
    try {
      var image = img.decodeImage(rawBytes);
      if (image == null) return rawBytes;

      if (image.width > _maxDimension || image.height > _maxDimension) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: _maxDimension);
        } else {
          image = img.copyResize(image, height: _maxDimension);
        }
      }

      image = img.normalize(image, min: 0, max: 255);
      image = _applySharpen(image);

      return Uint8List.fromList(img.encodeJpg(image, quality: 90));
    } catch (_) {
      return rawBytes;
    }
  }

  static img.Image _applySharpen(img.Image src) {
    final kernel = [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0,
    ];
    return img.convolution(src, filter: kernel, div: 1, offset: 0);
  }
}