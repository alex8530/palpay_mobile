import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'enroll_config.dart';

/// Shrinks a photo (resize + JPEG re-encode) like App\Services\ImageCompressor,
/// then Base64-encodes it for PreEnroll.
String compressToBase64(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw Exception('Unreadable image.');
  }
  var image = img.bakeOrientation(decoded); // apply EXIF rotation

  const max = EnrollConfig.imageMaxDimension;
  final w = image.width, h = image.height;
  if (w > max || h > max) {
    if (w >= h) {
      image = img.copyResize(image, width: max);
    } else {
      image = img.copyResize(image, height: max);
    }
  }

  // Flatten any transparency onto white, since JPEG has no alpha.
  if (image.hasAlpha) {
    final flat = img.Image(width: image.width, height: image.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, image);
    image = flat;
  }

  final jpeg = img.encodeJpg(image, quality: EnrollConfig.imageQuality);
  return base64.encode(jpeg);
}
