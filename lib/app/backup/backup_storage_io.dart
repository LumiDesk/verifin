import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../platform_bridge.dart';
import 'backup_settings.dart';

/// 用户选择的备份目录：Android 上 [uri] 为 SAF 树 URI，桌面上为文件系统路径。
class PickedBackupDirectory {
  const PickedBackupDirectory({required this.uri, required this.label});

  final String uri;
  final String label;
}

Future<PickedBackupDirectory?> pickBackupDirectory() async {
  if (Platform.isAndroid) {
    final result = await AppPlatformBridge.pickBackupDirectory();
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
    return AppPlatformBridge.writeBackupFile(
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
    return AppPlatformBridge.writeBackupBytes(
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
    return AppPlatformBridge.readBackupBytes(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return null;
  }
  return file.readAsBytes();
}

Future<List<BackupFileInfo>> listBackupFiles(String directoryUri) async {
  if (Platform.isAndroid) {
    final raw = await AppPlatformBridge.listBackupFiles(directoryUri);
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
    return AppPlatformBridge.readBackupFile(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return null;
  }
  return utf8.decode(await file.readAsBytes());
}

Future<bool> deleteBackupFile(String fileUri) async {
  if (Platform.isAndroid) {
    return AppPlatformBridge.deleteBackupFile(fileUri);
  }
  final file = File.fromUri(Uri.parse(fileUri));
  if (!file.existsSync()) {
    return false;
  }
  await file.delete();
  return true;
}
