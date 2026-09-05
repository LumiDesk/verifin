import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'platform_bridge.dart';

export 'data_file_picker.dart';

/// 返回是否真正保存了文件;用户在保存对话框中取消时返回 false。
Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  final savedToDownloads = await AppStorageBridge.saveTextToDownloads(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
  if (savedToDownloads) {
    return true;
  }

  final location = await getSaveLocation(suggestedName: filename);
  if (location == null) {
    return false;
  }
  final file = XFile.fromData(
    utf8.encode(content),
    mimeType: mimeType,
    name: filename,
  );
  await file.saveTo(location.path);
  return true;
}

/// 写字节文件到下载目录（zip 导出）。Android 优先走系统下载目录，失败/不支持时
/// 回退到系统「保存到」选择器；用户取消返回 false。
Future<bool> downloadBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/zip',
}) async {
  final savedToDownloads = await AppStorageBridge.saveBytesToDownloads(
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
  if (savedToDownloads) {
    return true;
  }
  final location = await getSaveLocation(suggestedName: filename);
  if (location == null) {
    return false;
  }
  final file = XFile.fromData(bytes, mimeType: mimeType, name: filename);
  await file.saveTo(location.path);
  return true;
}
