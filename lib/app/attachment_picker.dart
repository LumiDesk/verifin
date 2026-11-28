import 'package:flutter/foundation.dart';

import 'attachment_picker_stub.dart'
    if (dart.library.io) 'attachment_picker_image_picker.dart'
    as impl;
import 'attachment_picker_types.dart';

export 'attachment_picker_types.dart';

/// 当前平台是否支持拍照/相册选择图片附件。
bool get attachmentPickingSupported => impl.attachmentPickingSupported;

/// 测试注入点：替换真实系统选图。
@visibleForTesting
AttachmentPickImages? debugAttachmentPickImagesOverride;

/// 选择图片并逐张压缩后交给 [onImage]。
///
/// 相册一次可选多张，拍照仍为单张；[onImage] 返回 `false` 表示调用方不再接收
/// 后续图片（例如页面已经离开）。进度通过 [onProgress] 按处理完成的张数回调。
Future<AttachmentPickOutcome> pickAttachmentImages({
  required bool fromCamera,
  required Future<bool> Function(Uint8List bytes) onImage,
  void Function(int done, int total)? onProgress,
}) {
  final override = debugAttachmentPickImagesOverride;
  if (override != null) {
    return override(
      fromCamera: fromCamera,
      onImage: onImage,
      onProgress: onProgress,
    );
  }
  return impl.pickAttachmentImages(
    fromCamera: fromCamera,
    onImage: onImage,
    onProgress: onProgress,
  );
}
