import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'attachment_picker_types.dart';
import 'image_picker_cleanup_io.dart';

/// Android/iOS 支持相机拍摄与相册选择图片附件。
const bool attachmentPickingSupported = true;

/// 附件图片最长边上限（像素）。票据类图片这个尺寸足够清晰，同时把体积压到
/// 可接受范围（存进应用私有附件文件，随备份带走）。
const int _maxDimension = 1600;

/// 打开系统选择器并返回选中的原文件。
///
/// 相册一次可选多张，拍照为单张；取消返回空列表。
typedef AttachmentFilePicker =
    Future<List<XFile>> Function({required bool fromCamera});

/// 选择图片并逐张压缩后交给 [onImage]。
///
/// 相册一次可选多张；每张图片按选择顺序读取、压缩并回调一次，处理完一张才
/// 读取下一张，峰值内存只与单张原图有关。[onImage] 返回 `false` 时停止处理
/// 后续图片（例如页面已经离开），[onProgress] 在处理完每一张后回调。
///
/// [pickFiles] 是测试注入点，生产调用不传。
Future<AttachmentPickOutcome> pickAttachmentImages({
  required bool fromCamera,
  required Future<bool> Function(Uint8List bytes) onImage,
  void Function(int done, int total)? onProgress,
  AttachmentFilePicker? pickFiles,
}) async {
  final files = await (pickFiles ?? _pickFromSystem)(fromCamera: fromCamera);
  if (files.isEmpty) {
    return const AttachmentPickOutcome.cancelled();
  }

  var added = 0;
  var failed = 0;
  var stoppedEarly = false;
  Object? firstError;
  StackTrace? firstStackTrace;
  for (var index = 0; index < files.length; index++) {
    final file = files[index];
    Uint8List? compressed;
    try {
      final bytes = await file.readAsBytes();
      // 解码/缩放/编码是纯 CPU 重活，放到后台 isolate 避免掉帧。
      compressed = await compute(compressAttachmentImage, bytes);
    } catch (error, stackTrace) {
      // 单张坏图（损坏、当前解码器不支持的格式）不应中断整批：跳过它并在
      // 结果里计数，由调用方给出用户可见提示并记录汇总日志。
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    } finally {
      // image_picker 会先把选择结果复制到应用缓存；读完立即删除应用副本，
      // 用户相册原文件不受影响。
      await discardImagePickerCopy(file);
    }

    var keepGoing = true;
    if (compressed == null || compressed.isEmpty) {
      firstError ??= const FormatException('图片无法解码');
      failed++;
    } else {
      keepGoing = await onImage(compressed);
      added++;
    }
    onProgress?.call(index + 1, files.length);
    if (!keepGoing) {
      stoppedEarly = true;
      break;
    }
  }

  return AttachmentPickOutcome(
    picked: files.length,
    added: added,
    failed: failed,
    stoppedEarly: stoppedEarly,
    error: firstError,
    stackTrace: firstStackTrace,
  );
}

Future<List<XFile>> _pickFromSystem({required bool fromCamera}) async {
  final picker = ImagePicker();
  if (fromCamera) {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    return <XFile>[?picked];
  }
  return picker.pickMultiImage(maxWidth: 2400, maxHeight: 2400);
}

/// 把任意图片字节解码、按 EXIF 摆正、缩到最长边 1600 并重新编码为 JPEG。
///
/// 返回 `null` 表示字节不是当前解码器支持的图片。纯 CPU 函数，生产调用方在
/// 后台 isolate 里执行它。
Uint8List? compressAttachmentImage(Uint8List bytes) {
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
