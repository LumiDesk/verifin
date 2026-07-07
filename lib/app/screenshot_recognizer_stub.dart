import 'dart:typed_data';

/// 测试宿主 / 非 io 平台不支持图片文字识别。
const bool screenshotRecognitionSupported = false;

/// 从相册选择一张待识别的截图，返回本地文件路径（取消返回 null）。
Future<String?> pickScreenshotPath() async => null;

/// 识别本地图片文件中的文字。
Future<String> recognizeTextFromPath(String path) {
  throw UnsupportedError('当前平台不支持图片文字识别。');
}

/// 识别内存图片字节中的文字（系统分享进来的截图）。
Future<String> recognizeTextFromBytes(Uint8List bytes) {
  throw UnsupportedError('当前平台不支持图片文字识别。');
}
