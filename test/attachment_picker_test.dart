import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:verifin/app/attachment_picker_image_picker.dart';

Uint8List _png({int width = 40, int height = 20}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('压缩按最长边 1600 等比缩小并输出 JPEG', () {
    final jpeg = compressAttachmentImage(_png(width: 2000, height: 1000));
    expect(jpeg, isNotNull);
    final decoded = img.decodeJpg(jpeg!);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 800);
  });

  test('小图不放大，保持原始尺寸', () {
    final jpeg = compressAttachmentImage(_png(width: 100, height: 50));
    expect(jpeg, isNotNull);
    final decoded = img.decodeJpg(jpeg!)!;
    expect(decoded.width, 100);
    expect(decoded.height, 50);
  });

  test('不可解码的字节返回 null', () {
    expect(
      compressAttachmentImage(Uint8List.fromList(<int>[1, 2, 3, 4])),
      isNull,
    );
    expect(compressAttachmentImage(Uint8List(0)), isNull);
  });

  test('相册文件按选择顺序逐张回调并报告进度', () async {
    final files = <XFile>[
      XFile.fromData(_png(), name: 'a.png'),
      XFile.fromData(_png(), name: 'b.png'),
      XFile.fromData(_png(), name: 'c.png'),
    ];
    final added = <Uint8List>[];
    final progress = <(int, int)>[];

    final outcome = await pickAttachmentImages(
      fromCamera: false,
      pickFiles: ({required fromCamera}) async {
        expect(fromCamera, isFalse);
        return files;
      },
      onImage: (bytes) async {
        // 每张交给调用方的都是重新编码后的 JPEG。
        expect(img.decodeJpg(bytes), isNotNull);
        added.add(bytes);
        return true;
      },
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(outcome.picked, 3);
    expect(outcome.added, 3);
    expect(outcome.failed, 0);
    expect(outcome.stoppedEarly, isFalse);
    expect(outcome.error, isNull);
    expect(added, hasLength(3));
    expect(progress, <(int, int)>[(1, 3), (2, 3), (3, 3)]);
  });

  test('坏图跳过并继续处理后续图片', () async {
    final files = <XFile>[
      XFile.fromData(_png(), name: 'a.png'),
      XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'bad.png'),
      XFile.fromData(_png(), name: 'c.png'),
    ];
    final added = <Uint8List>[];
    final progress = <int>[];

    final outcome = await pickAttachmentImages(
      fromCamera: false,
      pickFiles: ({required fromCamera}) async => files,
      onImage: (bytes) async {
        added.add(bytes);
        return true;
      },
      onProgress: (done, total) => progress.add(done),
    );

    expect(outcome.picked, 3);
    expect(outcome.added, 2);
    expect(outcome.failed, 1);
    expect(outcome.error, isNotNull);
    expect(outcome.stoppedEarly, isFalse);
    expect(added, hasLength(2));
    expect(progress, <int>[1, 2, 3]);
  });

  test('onImage 返回 false 时停止处理后续图片', () async {
    final files = <XFile>[
      XFile.fromData(_png(), name: 'a.png'),
      XFile.fromData(_png(), name: 'b.png'),
      XFile.fromData(_png(), name: 'c.png'),
    ];
    final added = <Uint8List>[];

    final outcome = await pickAttachmentImages(
      fromCamera: false,
      pickFiles: ({required fromCamera}) async => files,
      onImage: (bytes) async {
        added.add(bytes);
        return added.length < 2;
      },
    );

    expect(outcome.picked, 3);
    expect(outcome.added, 2);
    expect(outcome.failed, 0);
    expect(outcome.stoppedEarly, isTrue);
    expect(added, hasLength(2));
  });

  test('拍照走单张路径', () async {
    final outcome = await pickAttachmentImages(
      fromCamera: true,
      pickFiles: ({required fromCamera}) async {
        expect(fromCamera, isTrue);
        return <XFile>[XFile.fromData(_png(), name: 'camera.png')];
      },
      onImage: (_) async => true,
    );

    expect(outcome.picked, 1);
    expect(outcome.added, 1);
    expect(outcome.failed, 0);
  });

  test('取消选择返回空结果且不回调', () async {
    final outcome = await pickAttachmentImages(
      fromCamera: false,
      pickFiles: ({required fromCamera}) async => <XFile>[],
      onImage: (_) async => throw StateError('取消选择时不应回调'),
    );

    expect(outcome.picked, 0);
    expect(outcome.added, 0);
    expect(outcome.failed, 0);
  });
}
