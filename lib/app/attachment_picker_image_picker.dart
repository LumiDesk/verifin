import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Android/iOS 支持相机拍摄与相册选择图片附件。
const bool attachmentPickingSupported = true;

/// 附件图片最长边上限（像素）。票据类图片这个尺寸足够清晰，同时把体积压到
/// 可接受范围（存进应用私有附件文件，随备份带走）。
const int _maxDimension = 1600;

/// 选择或拍摄一张图片，压缩为 JPEG 字节返回（取消或解码失败返回 null）。
Future<Uint8List?> pickAttachmentBytes({required bool fromCamera}) async {
  final picked = await ImagePicker().pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
  );
  if (picked == null) {
    return null;
  }
  final bytes = await picked.readAsBytes();
  // 解码/缩放/编码是纯 CPU 重活，放到后台 isolate 避免掉帧。
  return compute(_compressToJpeg, bytes);
}

Uint8List? _compressToJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return null;
  }
  // Flutter 预览会应用 EXIF 方向，image 包解码不会，先烘焙保证方向一致。
  final baked = img.bakeOrientation(decoded);
  final longest = baked.width > baked.height ? baked.width : baked.height;
  final out = longest > _maxDimension
      ? img.copyResize(
          baked,
          width: longest == baked.width
              ? _maxDimension
              : (baked.width * _maxDimension / longest).round(),
          height: longest == baked.height
              ? _maxDimension
              : (baked.height * _maxDimension / longest).round(),
          interpolation: img.Interpolation.average,
        )
      : baked;
  return Uint8List.fromList(img.encodeJpg(out, quality: 80));
}
