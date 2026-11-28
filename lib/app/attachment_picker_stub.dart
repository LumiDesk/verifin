// 非移动平台（测试宿主）不支持图片附件拍摄/选择。
import 'dart:typed_data';

import 'attachment_picker_types.dart';

const bool attachmentPickingSupported = false;

/// 测试宿主没有系统相册/相机，一律视为取消。
Future<AttachmentPickOutcome> pickAttachmentImages({
  required bool fromCamera,
  required Future<bool> Function(Uint8List bytes) onImage,
  void Function(int done, int total)? onProgress,
}) async => const AttachmentPickOutcome.cancelled();
