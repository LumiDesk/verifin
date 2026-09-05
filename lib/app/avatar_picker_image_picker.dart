import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

Future<String?> pickRawImageDataUrl() async {
  // 限制取图尺寸,避免原图(可达几十 MP)解码时内存峰值过高;
  // 裁剪目标最大只有 1200x760。
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
  );
  if (picked == null) {
    return null;
  }
  final bytes = await picked.readAsBytes();
  final mimeType = picked.mimeType ?? _mimeTypeForPath(picked.path);
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

Future<String?> cropImageDataUrl({
  required String sourceDataUrl,
  required int targetWidth,
  required int targetHeight,
  required double zoom,
  required double offsetX,
  required double offsetY,
}) {
  // 解码/裁剪/缩放/编码是纯 CPU 重活,放到后台 isolate,避免阻塞 UI 线程掉帧。
  return compute(
    _cropImageDataUrlSync,
    _CropRequest(
      sourceDataUrl: sourceDataUrl,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      zoom: zoom,
      offsetX: offsetX,
      offsetY: offsetY,
    ),
  );
}

class _CropRequest {
  const _CropRequest({
    required this.sourceDataUrl,
    required this.targetWidth,
    required this.targetHeight,
    required this.zoom,
    required this.offsetX,
    required this.offsetY,
  });

  final String sourceDataUrl;
  final int targetWidth;
  final int targetHeight;
  final double zoom;
  final double offsetX;
  final double offsetY;
}

String? _cropImageDataUrlSync(_CropRequest request) {
  final targetWidth = request.targetWidth;
  final targetHeight = request.targetHeight;
  final zoom = request.zoom;
  final offsetX = request.offsetX;
  final offsetY = request.offsetY;
  final bytes = _bytesFromDataUrl(request.sourceDataUrl);
  if (bytes == null) {
    return null;
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    // 无法解码的格式(如 HEIC)不能当作裁剪结果原样返回,否则会把
    // 渲染不出来的大体积原图写进本地存储。
    return null;
  }
  // Flutter 预览会应用 EXIF 方向,image 包解码不会;先烘焙方向,
  // 保证竖拍照片的裁剪结果与预览一致。
  final source = img.bakeOrientation(decoded);

  final targetRatio = targetWidth / targetHeight;
  final sourceRatio = source.width / source.height;
  late final double baseCropWidth;
  late final double baseCropHeight;

  if (sourceRatio > targetRatio) {
    baseCropHeight = source.height.toDouble();
    baseCropWidth = baseCropHeight * targetRatio;
  } else {
    baseCropWidth = source.width.toDouble();
    baseCropHeight = baseCropWidth / targetRatio;
  }

  final effectiveZoom = zoom.clamp(1.0, 3.0);
  final cropWidth = baseCropWidth / effectiveZoom;
  final cropHeight = baseCropHeight / effectiveZoom;
  final maxOffsetX = math.max(0, source.width - cropWidth) / 2;
  final maxOffsetY = math.max(0, source.height - cropHeight) / 2;
  // 预览把图片向 offset 方向平移,取景框内露出的是相反一侧,
  // 因此裁剪中心要向 offset 的反方向移动。
  final centerX = source.width / 2 - offsetX.clamp(-1.0, 1.0) * maxOffsetX;
  final centerY = source.height / 2 - offsetY.clamp(-1.0, 1.0) * maxOffsetY;
  final cropX = (centerX - cropWidth / 2)
      .clamp(0, source.width - cropWidth)
      .round();
  final cropY = (centerY - cropHeight / 2)
      .clamp(0, source.height - cropHeight)
      .round();

  final cropped = img.copyCrop(
    source,
    x: cropX,
    y: cropY,
    width: cropWidth.round().clamp(1, source.width),
    height: cropHeight.round().clamp(1, source.height),
  );
  final resized = img.copyResize(
    cropped,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );
  final encoded = img.encodeJpg(resized, quality: 86);
  return 'data:image/jpeg;base64,${base64Encode(encoded)}';
}

Uint8List? _bytesFromDataUrl(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex == -1) {
    return null;
  }
  try {
    return base64Decode(dataUrl.substring(commaIndex + 1));
  } on FormatException {
    return null;
  }
}

String _mimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
