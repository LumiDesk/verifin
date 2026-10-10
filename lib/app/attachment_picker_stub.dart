// 非移动平台（测试宿主）不支持图片附件拍摄/选择。
import 'dart:typed_data';

const bool attachmentPickingSupported = false;

/// 选择或拍摄一张图片，返回压缩后的 JPEG 字节。stub 一律返回 null。
Future<Uint8List?> pickAttachmentBytes({required bool fromCamera}) async =>
    null;
