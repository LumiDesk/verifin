import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Android/iOS 支持端上离线 OCR（ML Kit 中文模型，兼识别拉丁字符）。
/// 图片不出设备：识别只在本地进行，后续只把识别出的文本交给用户自配的 AI 端点。
const bool screenshotRecognitionSupported = true;

/// 从相册选择一张待识别的截图，返回本地文件路径（取消返回 null）。
/// 不压缩不裁剪——OCR 要原始分辨率才认得清小字。
Future<String?> pickScreenshotPath() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  return picked?.path;
}

/// 识别本地图片文件中的文字，按识别顺序拼接为多行文本。
Future<String> recognizeTextFromPath(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.text;
  } finally {
    await recognizer.close();
  }
}

/// 识别内存图片字节中的文字（系统分享进来的截图）。
/// ML Kit 按字节识别需要逐平面的元数据，落成临时文件走文件路径入口最稳妥；
/// 识别完即删，不留存分享进来的图片。
Future<String> recognizeTextFromBytes(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('verifin_ocr');
  final file = File('${dir.path}${Platform.pathSeparator}shared_image');
  await file.writeAsBytes(bytes, flush: true);
  try {
    return await recognizeTextFromPath(file.path);
  } finally {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // 临时目录清理失败不影响识别结果。
    }
  }
}
