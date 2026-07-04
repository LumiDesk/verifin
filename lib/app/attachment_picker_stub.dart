// 非移动平台（测试宿主）不支持图片附件拍摄/选择。
const bool attachmentPickingSupported = false;

/// 选择或拍摄一张图片，返回压缩后的 JPEG data URL。stub 一律返回 null。
Future<String?> pickAttachmentDataUrl({required bool fromCamera}) async => null;
