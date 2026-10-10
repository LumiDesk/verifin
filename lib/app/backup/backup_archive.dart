import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../attachments/attachment_store.dart';
import 'backup_progress.dart';

/// 备份压缩包（zip）打包/解包。
///
/// 背景：附件字节不再内嵌 base64，而是与应用私有目录里的附件文件一一对应。备份时
/// 把附件从 `AttachmentStore` 读进 zip 的 `attachments/<id>` 条目（store 模式，不重复
/// 压缩已压缩的 JPEG），解包时再写回暂存 `AttachmentStore`，由导入流程并入主存储。
///
/// 容器形状与 v3 完全一致（`backup.json` + `attachments/<id>`），并且 `backup.json` 里
/// 仍写入 `dataUrl: ''` 与 `_archiveMime`——这样旧版本 App 导入本版本导出的备份时，
/// 仍能把附件字节拼回内嵌形态，不会丢附件。新增的 `byteSize` 字段旧版本会忽略。

/// zip 内 JSON 条目名。
const String backupJsonEntryName = 'backup.json';
const String _attachmentsDir = 'attachments';
const String _archiveMimeKey = '_archiveMime';

/// 备份条目数量上限。只为挡住异常/恶意包无限生成条目，不限制合法备份的体积；
/// 内存有界由「逐条处理」保证，与备份总大小无关。
const int maxBackupArchiveFileCount = 200000;
const int maxBackupAttachmentCount = 200000;

/// 附件元数据存在但字节取不到（文件缺失且无旧版 base64）时抛出。
///
/// 宁可让整次备份失败并明确告知，也不产出静默缺附件的备份文件。
class BackupAttachmentUnavailableException implements Exception {
  const BackupAttachmentUnavailableException(this.attachmentId);

  final String attachmentId;

  @override
  String toString() => 'Attachment unavailable: $attachmentId';
}

/// 是否为 zip 字节流（魔数 `PK\x03\x04`）。用于导入时区分新版 zip 备份与旧版
/// 纯 JSON / 加密信封文本。
bool looksLikeZipBytes(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

/// 把导出 JSON 流式打包到 [outputPath] 指向的缓存文件。
///
/// 用增量编码器逐条写盘，而不是先攒一个 [Archive]：附件字节只在「正在写的那一张」
/// 期间驻留内存，峰值与附件总量、备份总体积无关。附件用 store 模式（不重复压缩已
/// 压缩的 JPEG），`backup.json` 很小、走 deflate。
Future<void> packBackupArchiveToFile({
  required String exportJson,
  required AttachmentStore store,
  required String outputPath,
  void Function(int done, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final root = jsonDecode(exportJson);
  final attachments = _attachmentsOf(root).toList(growable: false);
  final output = OutputFileStream(outputPath);
  final encoder = ZipEncoder();
  onProgress?.call(0, attachments.length);
  try {
    encoder.startEncode(output);
    var done = 0;
    for (final attachment in attachments) {
      if (isCancelled?.call() ?? false) {
        throw const BackupCancelledException();
      }
      final id = attachment['id'];
      if (id is! String || id.isEmpty) {
        continue;
      }
      final mime = attachment['mimeType'] as String? ?? 'image/jpeg';
      final Uint8List bytes;
      try {
        bytes = await store.readBytes(id);
      } catch (_) {
        throw BackupAttachmentUnavailableException(id);
      }
      if (bytes.isEmpty) {
        throw BackupAttachmentUnavailableException(id);
      }
      encoder.add(
        ArchiveFile.stream('$_attachmentsDir/$id', InputMemoryStream(bytes))
          ..compression = CompressionType.none,
      );
      // 保持 v3 形状，让旧版本仍能内嵌还原；正文里不再出现 base64。
      attachment['dataUrl'] = '';
      attachment[_archiveMimeKey] = mime;
      attachment['byteSize'] = bytes.length;
      done++;
      onProgress?.call(done, attachments.length);
    }
    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(root),
    );
    encoder.add(ArchiveFile(backupJsonEntryName, jsonBytes.length, jsonBytes));
    encoder.endEncode();
  } finally {
    output.closeSync();
  }
}

/// 从 [archivePath] 流式解包：附件字节逐条写入 [sink]（导入时传暂存存储），返回去掉
/// 内嵌 base64 的导出 JSON。逐条处理，内存只与单张附件有关，与备份总体积无关。
Future<String> unpackBackupArchiveFile({
  required String archivePath,
  required AttachmentStore sink,
  void Function(int done, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final input = InputFileStream(archivePath);
  final Archive archive;
  try {
    archive = ZipDecoder().decodeStream(input);
  } catch (error) {
    input.closeSync();
    throw const FormatException('备份压缩包已损坏');
  }
  List<int>? jsonBytes;
  final sizes = <String, int>{};
  var fileCount = 0;
  var attachmentCount = 0;
  onProgress?.call(0, 0);
  try {
    for (final file in archive) {
      if (isCancelled?.call() ?? false) {
        throw const BackupCancelledException();
      }
      if (!file.isFile) {
        continue;
      }
      fileCount++;
      if (fileCount > maxBackupArchiveFileCount) {
        throw const FormatException('备份条目数量过多');
      }
      if (file.name == backupJsonEntryName) {
        jsonBytes = file.content;
        continue;
      }
      if (!file.name.startsWith('$_attachmentsDir/')) {
        continue;
      }
      attachmentCount++;
      if (attachmentCount > maxBackupAttachmentCount) {
        throw const FormatException('备份附件数量过多');
      }
      final id = file.name.substring('$_attachmentsDir/'.length);
      if (id.isEmpty) {
        continue;
      }
      final content = file.content;
      if (content.isEmpty) {
        continue;
      }
      await sink.writeBytes(id, content);
      sizes[id] = content.length;
      onProgress?.call(attachmentCount, archive.length);
    }
  } finally {
    input.closeSync();
  }
  if (jsonBytes == null) {
    throw const FormatException('备份压缩包缺少 backup.json');
  }
  final root = jsonDecode(utf8.decode(jsonBytes));
  // 用实际解出的字节数校正元数据（旧包没有 byteSize），顺带反映真实体积。
  for (final attachment in _attachmentsOf(root)) {
    final id = attachment['id'];
    if (id is! String) {
      continue;
    }
    final size = sizes[id];
    if (size != null) {
      attachment['byteSize'] = size;
    }
  }
  return jsonEncode(root);
}

/// 旧版明文 JSON（v1/v2，附件内嵌 base64）→ 暂存附件 + 元数据 JSON。
///
/// 与新版备份归一到同一形态：`dataUrl` 抽取成附件文件、正文只留元数据，后续导入
/// 只有一条路径。解码失败的附件跳过（保留其原始 dataUrl 交由导入层报错）。
Future<String> extractLegacyAttachments(
  String json,
  AttachmentStore sink,
) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const FormatException('备份文件格式不正确');
  }
  if (decoded is! Map) {
    throw const FormatException('备份文件格式不正确');
  }
  for (final attachment in _attachmentsOf(decoded)) {
    final id = attachment['id'];
    final dataUrl = attachment['dataUrl'];
    if (id is! String || id.isEmpty) {
      continue;
    }
    if (dataUrl is! String || !dataUrl.startsWith('data:')) {
      continue;
    }
    final bytes = _decodeDataUrl(dataUrl);
    if (bytes == null || bytes.isEmpty) {
      continue;
    }
    await sink.writeBytes(id, bytes);
    attachment['dataUrl'] = '';
    attachment['mimeType'] = _dataUrlMime(dataUrl);
    attachment['byteSize'] = bytes.length;
  }
  return jsonEncode(decoded);
}

/// 把附件字节重新内嵌成 base64 data URL，用于**既有加密信封**格式的写入路径。
///
/// 既有加密备份是「整份明文 JSON 的加密封装」，附件必须内嵌才不丢数据。为保持与旧
/// 版本完全一致的加密格式（旧版本仍可解密导入），这条过渡实现暂时保留整份进内存，
/// 待流式加密容器落地后由 `packBackupArchive` + 流式加密替换。
Future<String> embedAttachmentsAsDataUrls(
  String exportJson,
  AttachmentStore store,
) async {
  final root = jsonDecode(exportJson);
  for (final attachment in _attachmentsOf(root)) {
    final id = attachment['id'];
    if (id is! String || id.isEmpty) {
      continue;
    }
    final mime = attachment['mimeType'] as String? ?? 'image/jpeg';
    final Uint8List bytes;
    try {
      bytes = await store.readBytes(id);
    } catch (_) {
      throw BackupAttachmentUnavailableException(id);
    }
    attachment['dataUrl'] = 'data:$mime;base64,${base64Encode(bytes)}';
    attachment['byteSize'] = bytes.length;
  }
  return jsonEncode(root);
}

/// 从导出 JSON 根（可能带 `data` 包裹）里取出附件列表（可原地改写元素）。
Iterable<Map<Object?, Object?>> _attachmentsOf(Object? root) {
  if (root is! Map) {
    return const <Map<Object?, Object?>>[];
  }
  final data = root['data'];
  final attachments = data is Map ? data['attachments'] : root['attachments'];
  if (attachments is! List) {
    return const <Map<Object?, Object?>>[];
  }
  return attachments.whereType<Map<Object?, Object?>>();
}

Uint8List? _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) {
    return null;
  }
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

String _dataUrlMime(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma <= 5) return 'image/jpeg';
  final header = dataUrl.substring(5, comma);
  final semicolon = header.indexOf(';');
  final mime = (semicolon < 0 ? header : header.substring(0, semicolon)).trim();
  return RegExp(r'^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+$').hasMatch(mime)
      ? mime
      : 'image/jpeg';
}
