// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html;

Future<String?> pickRawImageDataUrl() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  input.onChange.first.then((_) {
    final file = input.files?.isEmpty ?? true ? null : input.files!.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoad.first.then(
      (_) => completer.complete(reader.result as String?),
    );
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsDataUrl(file);
  });

  return completer.future;
}

Future<String?> cropImageDataUrl({
  required String sourceDataUrl,
  required int targetWidth,
  required int targetHeight,
  required double zoom,
  required double offsetX,
  required double offsetY,
}) async {
  final image = html.ImageElement(src: sourceDataUrl);
  try {
    await image.onLoad.first;
  } on Object {
    return sourceDataUrl;
  }

  final sourceWidth = image.naturalWidth;
  final sourceHeight = image.naturalHeight;
  if (sourceWidth == 0 || sourceHeight == 0) {
    return sourceDataUrl;
  }

  final targetRatio = targetWidth / targetHeight;
  final sourceRatio = sourceWidth / sourceHeight;
  late final double baseCropWidth;
  late final double baseCropHeight;

  if (sourceRatio > targetRatio) {
    baseCropHeight = sourceHeight.toDouble();
    baseCropWidth = baseCropHeight * targetRatio;
  } else {
    baseCropWidth = sourceWidth.toDouble();
    baseCropHeight = baseCropWidth / targetRatio;
  }

  final effectiveZoom = zoom.clamp(1.0, 3.0);
  final cropWidth = baseCropWidth / effectiveZoom;
  final cropHeight = baseCropHeight / effectiveZoom;
  final maxOffsetX = math.max(0, sourceWidth - cropWidth) / 2;
  final maxOffsetY = math.max(0, sourceHeight - cropHeight) / 2;
  final centerX = sourceWidth / 2 + offsetX.clamp(-1.0, 1.0) * maxOffsetX;
  final centerY = sourceHeight / 2 + offsetY.clamp(-1.0, 1.0) * maxOffsetY;
  final cropX = (centerX - cropWidth / 2).clamp(0, sourceWidth - cropWidth);
  final cropY = (centerY - cropHeight / 2).clamp(0, sourceHeight - cropHeight);

  final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
  final context = canvas.context2D;
  context.drawImageScaledFromSource(
    image,
    cropX,
    cropY,
    cropWidth,
    cropHeight,
    0,
    0,
    targetWidth,
    targetHeight,
  );
  return canvas.toDataUrl('image/jpeg', 0.86);
}
