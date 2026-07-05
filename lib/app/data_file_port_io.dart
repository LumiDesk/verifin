import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'platform_bridge.dart';

/// 返回是否真正保存了文件;用户在保存对话框中取消时返回 false。
Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  final savedToDownloads = await AppPlatformBridge.saveTextToDownloads(
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
  final savedToDownloads = await AppPlatformBridge.saveBytesToDownloads(
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

Future<String?> pickTextFile() async {
  const jsonGroup = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json'],
  );
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[jsonGroup],
  );
  return _readAsUtf8(file);
}

/// 选择备份文件（.json 旧版 / .zip 新版）并读原始字节，格式由调用方判别。
Future<Uint8List?> pickBackupBytes({String label = '备份文件'}) async {
  final group = XTypeGroup(
    label: label,
    extensions: <String>['json', 'zip'],
    mimeTypes: <String>['application/json', 'application/zip'],
  );
  final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
  if (file == null) {
    return null;
  }
  return file.readAsBytes();
}

Future<String?> pickCsvFile() async {
  const csvGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv', 'txt'],
    mimeTypes: <String>['text/csv', 'text/plain'],
  );
  final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[csvGroup]);
  return _readAsUtf8(file);
}

/// 显式按 UTF-8 解码，不用 `XFile.readAsString()`：后者在 Android 上对
/// `content://` 选中的文件可能按平台默认编码解码，导致中文变乱码。与备份恢复
/// 路径（`backup_storage_io.dart`）保持一致。
Future<String?> _readAsUtf8(XFile? file) async {
  if (file == null) {
    return null;
  }
  return utf8.decode(await file.readAsBytes());
}
