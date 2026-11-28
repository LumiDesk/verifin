import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:verifin/app/ai/ai_vision_image.dart';

void main() {
  test('prepares a large PNG as a bounded JPEG', () async {
    final source = img.Image(width: 2400, height: 1200, numChannels: 3);
    img.fill(source, color: img.ColorRgb8(180, 200, 220));
    final bytes = Uint8List.fromList(img.encodePng(source));

    final prepared = await prepareVisionImage(bytes);

    expect(prepared, isNotEmpty);
    expect(prepared.length, lessThanOrEqualTo(visionImageMaxBytes));
    expect(prepared[0], 0xFF);
    expect(prepared[1], 0xD8);
    final decoded = img.decodeJpg(prepared);
    expect(decoded, isNotNull);
    expect(decoded!.width, visionImageMaxDimension);
    expect(decoded.height, visionImageMaxDimension ~/ 2);
  });

  test('flattens transparent PNG onto white before JPEG encoding', () async {
    final source = img.Image(width: 80, height: 80, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(0, 0, 0, 0));
    final prepared = await prepareVisionImage(
      Uint8List.fromList(img.encodePng(source)),
    );

    final decoded = img.decodeJpg(prepared)!;
    final pixel = decoded.getPixel(40, 40);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('rejects invalid bytes and oversized input', () async {
    await expectLater(
      prepareVisionImage(Uint8List.fromList(<int>[1, 2, 3, 4])),
      throwsA(
        isA<VisionImageException>().having(
          (error) => error.error,
          'error',
          VisionImageError.invalid,
        ),
      ),
    );

    await expectLater(
      prepareVisionImage(Uint8List(visionImageMaxInputBytes + 1)),
      throwsA(
        isA<VisionImageException>().having(
          (error) => error.error,
          'error',
          VisionImageError.tooLarge,
        ),
      ),
    );
  });

  test('builds a JPEG data URL', () {
    final dataUrl = visionImageDataUrl(Uint8List.fromList(<int>[1, 2, 3]));
    expect(dataUrl, startsWith('data:image/jpeg;base64,'));
    expect(base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1)), <int>[
      1,
      2,
      3,
    ]);
  });
}
