import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../platform_bridge.dart';
import 'backup_settings.dart';

export '../platform_bridge.dart' show StagedCacheFile, StreamedWriteReceipt;

/// 用户选择的备份目录：Android 上 [uri] 为 SAF 树 URI，桌面上为文件系统路径。
class PickedBackupDirectory {
  const PickedBackupDirectory({required this.uri, required this.label});

  final String uri;
  final String label;
}

Future<PickedBackupDirectory?> pickBackupDirectory() async {
  if (Platform.isAndroid) {
    final result = await AppStorageBridge.pickBackupDirectory();
    if (result == null || (result['uri'] ?? '').isEmpty) {
      return null;
    }
    return PickedBackupDirectory(
      uri: result['uri']!,
      label: result['label']!.isEmpty ? result['uri']! : result['label']!,
    );
  }
  final path = await getDirectoryPath();
  if (path == null) {
    return null;
  }
  return PickedBackupDirectory(uri: path, label: p.basename(path));
}

Future<String?> writeBackupFile({
  required String directoryUri,
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.writeBackupFile(
      directoryUri: directoryUri,
      filename: filename,
      content: content,
      mimeType: mimeType,
    );
  }
  final file = File(p.join(directoryUri, filename));
  await file.writeAsString(content, flush: true);
  return file.uri.toString();
}

/// 向备份目录写入字节文件（zip 备份）。Android 走 SAF、桌面走 dart:io。
Future<String?> writeBackupBytesFile({
  required String directoryUri,
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/zip',
}) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.writeBackupBytes(
      directoryUri: directoryUri,
      filename: filename,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
  final file = File(p.join(directoryUri, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.uri.toString();
}

/// 读取备份文件原始字节（zip 与旧版 JSON 统一按字节读入，调用方再判别格式）。
Future<Uint8List?> readBackupBytesFile(String fileUri) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.readBackupBytes(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return null;
  }
  // 不再做固定大小上限：内存有界由逐条流式处理保证，桌面端读取走 dart:io 分块。
  return file.readAsBytes();
}

Future<List<BackupFileInfo>> listBackupFiles(String directoryUri) async {
  if (Platform.isAndroid) {
    final raw = await AppStorageBridge.listBackupFiles(directoryUri);
    return raw.map(BackupFileInfo.fromMap).toList();
  }
  final dir = Directory(directoryUri);
  if (!dir.existsSync()) {
    return const <BackupFileInfo>[];
  }
  final result = <BackupFileInfo>[];
  for (final entity in dir.listSync()) {
    if (entity is! File) {
      continue;
    }
    final name = p.basename(entity.path);
    if (!name.endsWith('.json') && !name.endsWith('.zip')) {
      continue;
    }
    final stat = entity.statSync();
    result.add(
      BackupFileInfo(
        uri: entity.uri.toString(),
        name: name,
        modifiedAt: stat.modified,
        sizeBytes: stat.size,
      ),
    );
  }
  return result;
}

Future<String?> readBackupFile(String fileUri) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.readBackupFile(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return null;
  }
  return utf8.decode(await file.readAsBytes());
}

Future<bool> deleteBackupFile(String fileUri) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.deleteBackupFile(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return false;
  }
  await file.delete();
  return true;
}

// ---- 大文件流式路径（不把整包放进内存）----

/// 把用户选择的备份文件流式落到应用缓存目录，返回本地路径（桌面直接用原路径）。
Future<StagedCacheFile?> stageBackupFileToCache(String fileUri) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.stageBackupFile(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return null;
  }
  return StagedCacheFile(path: file.path, byteSize: file.lengthSync());
}

/// 把缓存文件流式写入备份目录（同名覆盖），返回目标 URI 与写盘校验信息。
///
/// 写盘与 SHA-256 计算同一次读取完成，不再回读整份文件逐字节比对。
Future<({String uri, StreamedWriteReceipt receipt})?> writeBackupFromCacheFile({
  required String directoryUri,
  required String filename,
  required String cachePath,
  String mimeType = 'application/zip',
}) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.writeBackupFromCache(
      directoryUri: directoryUri,
      filename: filename,
      cachePath: cachePath,
      mimeType: mimeType,
    );
  }
  final target = File(p.join(directoryUri, filename));
  await File(cachePath).copy(target.path);
  final length = await target.length();
  return (
    uri: target.uri.toString(),
    receipt: StreamedWriteReceipt(
      sha256: await hashFileSha256(target.path),
      byteSize: length,
    ),
  );
}

/// 把缓存文件流式写入系统下载目录；Android 10 以下与桌面返回 null，由调用方回退。
Future<StreamedWriteReceipt?> saveCacheFileToDownloadsFromCache({
  required String filename,
  required String cachePath,
  String mimeType = 'application/zip',
}) async {
  if (Platform.isAndroid) {
    return AppStorageBridge.saveCacheFileToDownloads(
      filename: filename,
      cachePath: cachePath,
      mimeType: mimeType,
    );
  }
  return null;
}

/// 删除业务缓存文件。缓存目录由应用私有目录承载，失败不阻断主流程。
Future<void> deleteCacheFile(String path) async {
  if (Platform.isAndroid) {
    await AppStorageBridge.deleteCacheFile(path);
    return;
  }
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// 分块计算文件 SHA-256（写入校验与损坏检测用），内存与文件体积无关。
Future<String> hashFileSha256(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
