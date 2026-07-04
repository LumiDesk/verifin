import 'dart:convert';

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

Future<String?> pickTextFile() async {
  const jsonGroup = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json'],
  );
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[jsonGroup],
  );
  return file?.readAsString();
}

Future<String?> pickCsvFile() async {
  const csvGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv', 'txt'],
    mimeTypes: <String>['text/csv', 'text/plain'],
  );
  final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[csvGroup]);
  return file?.readAsString();
}
