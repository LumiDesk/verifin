import 'dart:typed_data';

import 'backup_settings.dart';

/// 用户选择的备份目录（SAF 树 URI 或桌面路径）。
class PickedBackupDirectory {
  const PickedBackupDirectory({required this.uri, required this.label});

  final String uri;
  final String label;
}

Future<PickedBackupDirectory?> pickBackupDirectory() async {
  throw UnsupportedError('当前平台暂不支持选择备份目录');
}

Future<String?> writeBackupFile({
  required String directoryUri,
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  throw UnsupportedError('当前平台暂不支持写入备份目录');
}

Future<List<BackupFileInfo>> listBackupFiles(String directoryUri) async {
  return const <BackupFileInfo>[];
}

Future<String?> readBackupFile(String fileUri) async {
  throw UnsupportedError('当前平台暂不支持读取备份文件');
}

Future<String?> writeBackupBytesFile({
  required String directoryUri,
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/zip',
}) async {
  throw UnsupportedError('当前平台暂不支持写入备份目录');
}

Future<Uint8List?> readBackupBytesFile(String fileUri) async {
  throw UnsupportedError('当前平台暂不支持读取备份文件');
}

Future<bool> deleteBackupFile(String fileUri) async {
  return false;
}

// ---- 大文件流式路径（非 io 平台不支持）----

/// 流式复制到缓存后的结果（stub 版本，与 io 实现同名同形）。
class StagedCacheFile {
  const StagedCacheFile({required this.path, required this.byteSize});

  final String path;
  final int byteSize;
}

/// 流式写出的回执（stub 版本，与 io 实现同名同形）。
class StreamedWriteReceipt {
  const StreamedWriteReceipt({required this.sha256, required this.byteSize});

  final String sha256;
  final int byteSize;
}

Future<StagedCacheFile?> stageBackupFileToCache(String fileUri) async {
  throw UnsupportedError('当前平台暂不支持读取备份文件');
}

Future<({String uri, StreamedWriteReceipt receipt})?> writeBackupFromCacheFile({
  required String directoryUri,
  required String filename,
  required String cachePath,
  String mimeType = 'application/zip',
}) async {
  throw UnsupportedError('当前平台暂不支持写入备份目录');
}

Future<StreamedWriteReceipt?> saveCacheFileToDownloadsFromCache({
  required String filename,
  required String cachePath,
  String mimeType = 'application/zip',
}) async {
  return null;
}

Future<void> deleteCacheFile(String path) async {}

Future<String> hashFileSha256(String path) async {
  throw UnsupportedError('当前平台暂不支持文件哈希');
}
