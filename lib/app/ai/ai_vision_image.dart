import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../image_picker_cleanup_io.dart';

/// 发送给视觉模型前的图片上限。票据/账单截图 1600px 足够，同时控制请求体。
const int visionImageMaxDimension = 1600;
const int visionImageMaxBytes = 1536 * 1024;
const int visionImageMaxInputBytes = 25 * 1024 * 1024;
const int visionImageMaxPixels = 30 * 1000 * 1000;

enum VisionImageError { invalid, tooLarge }

class VisionImageException implements Exception {
  const VisionImageException(this.error);

  final VisionImageError error;

  @override
  String toString() => 'VisionImageException(${error.name})';
}

/// 从相册选择一张图片并读成字节；取消或选择器不可用返回 null。
/// 读完后删除 image_picker 留下的应用缓存副本，用户相册原文件不动。
Future<Uint8List?> pickVisionImage() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null) {
      return null;
    }
    try {
      return await picked.readAsBytes();
    } finally {
      await discardImagePickerCopy(picked);
    }
  } catch (_) {
    return null;
  }
}

/// 解码、摆正、缩到最长边 1600，并重新编码成 JPEG；失败抛 [VisionImageException]。
Future<Uint8List> prepareVisionImage(Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw const VisionImageException(VisionImageError.invalid);
  }
  if (bytes.length > visionImageMaxInputBytes) {
    throw const VisionImageException(VisionImageError.tooLarge);
  }
  try {
    return await compute(_prepareVisionImageSync, bytes);
  } on VisionImageException {
    rethrow;
  } catch (_) {
    throw const VisionImageException(VisionImageError.invalid);
  }
}

String visionImageDataUrl(Uint8List jpegBytes) =>
    'data:image/jpeg;base64,${base64Encode(jpegBytes)}';

Uint8List _prepareVisionImageSync(Uint8List bytes) {
  final found = img.findDecoderForData(bytes);
  if (found == null) {
    throw const VisionImageException(VisionImageError.invalid);
  }

  // 只接受常见照片/截图格式，并给解码器一个明确的像素上限，避免小文件解压成
  // 超大位图。其它格式（如 HEIC）由 UI 提示换一张。
  final img.Decoder decoder;
  if (found is img.JpegDecoder) {
    decoder = img.JpegDecoder(maxPixels: visionImageMaxPixels);
  } else if (found is img.PngDecoder) {
    decoder = img.PngDecoder(maxPixels: visionImageMaxPixels);
  } else if (found is img.GifDecoder) {
    decoder = img.GifDecoder()..maxPixels = visionImageMaxPixels;
  } else if (found is img.WebPDecoder) {
    decoder = img.WebPDecoder()..maxPixels = visionImageMaxPixels;
  } else {
    throw const VisionImageException(VisionImageError.invalid);
  }

  final img.Image? decoded;
  try {
    decoded = decoder.decode(bytes, frame: 0);
  } catch (_) {
    throw const VisionImageException(VisionImageError.tooLarge);
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const VisionImageException(VisionImageError.invalid);
  }

  var image = _flattenOnWhite(img.bakeOrientation(decoded));
  image = _resizeToLongest(image, visionImageMaxDimension);
  final jpeg = _encodeWithinLimit(image);
  if (jpeg == null) {
    throw const VisionImageException(VisionImageError.tooLarge);
  }
  return jpeg;
}

img.Image _flattenOnWhite(img.Image source) {
  if (!source.hasAlpha) {
    return source;
  }
  final canvas = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, source);
  return canvas;
}

img.Image _resizeToLongest(img.Image source, int maxDimension) {
  final longest = math.max(source.width, source.height);
  if (longest <= maxDimension) {
    return source;
  }
  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: maxDimension,
      interpolation: img.Interpolation.average,
    );
  }
  return img.copyResize(
    source,
    height: maxDimension,
    interpolation: img.Interpolation.average,
  );
}

Uint8List? _encodeWithinLimit(img.Image image) {
  var current = image;
  for (final dimension in <int>[visionImageMaxDimension, 1280, 1024]) {
    if (dimension != visionImageMaxDimension) {
      current = _resizeToLongest(current, dimension);
    }
    for (final quality in <int>[82, 75, 68, 60]) {
      final bytes = Uint8List.fromList(
        img.encodeJpg(current, quality: quality),
      );
      if (bytes.length <= visionImageMaxBytes) {
        return bytes;
      }
    }
  }
  return null;
}
