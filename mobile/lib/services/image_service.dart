import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressParams {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  ImageCompressParams(this.bytes, this.maxDimension, this.quality);
}

/// Top-level helper function for Flutter compute/isolate.
Uint8List? _syncCompressImage(ImageCompressParams params) {
  try {
    final image = img.decodeImage(params.bytes);
    if (image == null) return null;

    img.Image resized;
    if (image.width > image.height) {
      if (image.width > params.maxDimension) {
        resized = img.copyResize(image, width: params.maxDimension);
      } else {
        resized = image;
      }
    } else {
      if (image.height > params.maxDimension) {
        resized = img.copyResize(image, height: params.maxDimension);
      } else {
        resized = image;
      }
    }

    final jpegBytes = img.encodeJpg(resized, quality: params.quality);
    return Uint8List.fromList(jpegBytes);
  } catch (e) {
    debugPrint("[ImageService] Sync compression failed: $e");
    return null;
  }
}

class ImageService {
  /// Compresses image [bytes] in a background isolate using Flutter's [compute].
  /// Scales down keeping aspect ratio if any dimension exceeds [maxDimension].
  /// Outputs encoded JPEG bytes with the given [quality] (1-100).
  static Future<Uint8List?> compressImage(
    Uint8List bytes, {
    int maxDimension = 1024,
    int quality = 80,
  }) async {
    try {
      return await compute(
        _syncCompressImage,
        ImageCompressParams(bytes, maxDimension, quality),
      );
    } catch (e) {
      debugPrint("[ImageService] Error running compute isolate for compression, falling back: $e");
      return _syncCompressImage(ImageCompressParams(bytes, maxDimension, quality));
    }
  }

  /// Compresses image [bytes] and formats it into a Base64 URI string `data:image/jpeg;base64,...`.
  static Future<String?> compressToBase64(
    Uint8List bytes, {
    int maxDimension = 1024,
    int quality = 80,
  }) async {
    final compressedBytes = await compressImage(
      bytes,
      maxDimension: maxDimension,
      quality: quality,
    );
    if (compressedBytes == null) return null;
    return 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
  }
}
