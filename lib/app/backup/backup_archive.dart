import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 备份压缩包（zip）打包/解包纯函数。
///
/// 背景：导出 JSON 里图片附件以 base64 data URL 内嵌，附件一多备份文件会急剧膨胀
/// （base64 约放大 33%，且每次整份重写）。这里把附件字节从 JSON 里剥离，与
/// `backup.json` 一起打进 zip：`backup.json` 中附件的 `dataUrl` 置空、图片原始字节
/// 写入 `attachments/<id>`。解包时再把字节拼回各附件的 `dataUrl`，还原成内嵌式
/// JSON 交给 `importDataJson`，因此导入逻辑与旧的纯 JSON 备份完全一致。

/// zip 内 JSON 条目名。
const String backupJsonEntryName = 'backup.json';
const String _attachmentsDir = 'attachments';
const String _archiveMimeKey = '_archiveMime';

/// 防止用户选择异常大的备份或压缩炸弹，把解包工作限制在可控范围内。
const int maxBackupArchiveBytes = 256 * 1024 * 1024;
const int maxBackupArchiveUncompressedBytes = 512 * 1024 * 1024;
const int maxBackupAttachmentCount = 2000;

/// 是否为 zip 字节流（魔数 `PK\x03\x04`）。用于导入时区分新版 zip 备份与旧版
/// 纯 JSON / 加密信封文本。
bool looksLikeZipBytes(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

/// 把导出 JSON（附件内嵌 base64）打成 zip 字节。
Uint8List packBackupArchive(String exportJson) {
  final root = jsonDecode(exportJson);
  final archive = Archive();
  for (final attachment in _attachmentsOf(root)) {
    final id = attachment['id'];
    final dataUrl = attachment['dataUrl'];
    if (id is String && dataUrl is String && dataUrl.startsWith('data:')) {
      final bytes = _decodeDataUrl(dataUrl);
      if (bytes != null) {
        // 附件是已压缩的 JPEG，再做 DEFLATE 几乎无收益却耗 CPU，改用 store（不压缩）。
        final file = ArchiveFile('$_attachmentsDir/$id', bytes.length, bytes)
          ..compression = CompressionType.none;
        archive.addFile(file);
        // 从 JSON 剥离 base64，只留结构和 MIME；解包时按 id 拼回。
        attachment['dataUrl'] = '';
        attachment[_archiveMimeKey] = _dataUrlMime(dataUrl);
      }
    }
  }
  final jsonBytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert(root),
  );
  archive.addFile(
    ArchiveFile(backupJsonEntryName, jsonBytes.length, jsonBytes),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// 解包 zip：把 `attachments/<id>` 字节拼回各附件 `dataUrl`，返回内嵌式 JSON 字符串。
String unpackBackupArchive(List<int> zipBytes) {
  if (zipBytes.length > maxBackupArchiveBytes) {
    throw const FormatException('备份文件过大');
  }
  final archive = ZipDecoder().decodeBytes(zipBytes);
  List<int>? jsonBytes;
  final attachmentFiles = <String, List<int>>{};
  var uncompressedBytes = 0;
  var attachmentCount = 0;
  for (final file in archive) {
    if (!file.isFile) {
      continue;
    }
    final content = file.content as List<int>;
    uncompressedBytes += content.length;
    if (uncompressedBytes > maxBackupArchiveUncompressedBytes) {
      throw const FormatException('备份解压后过大');
    }
    if (file.name == backupJsonEntryName) {
      jsonBytes = content;
    } else if (file.name.startsWith('$_attachmentsDir/')) {
      attachmentCount++;
      if (attachmentCount > maxBackupAttachmentCount) {
        throw const FormatException('备份附件数量过多');
      }
      attachmentFiles[file.name.substring('$_attachmentsDir/'.length)] =
          content;
    }
  }
  if (jsonBytes == null) {
    throw const FormatException('备份压缩包缺少 backup.json');
  }
  final root = jsonDecode(utf8.decode(jsonBytes));
  for (final attachment in _attachmentsOf(root)) {
    final id = attachment['id'];
    if (id is String) {
      final bytes = attachmentFiles[id];
      if (bytes != null) {
        final mime = attachment[_archiveMimeKey];
        final safeMime =
            mime is String &&
                RegExp(r'^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+$').hasMatch(mime)
            ? mime
            : 'image/jpeg';
        attachment['dataUrl'] = 'data:$safeMime;base64,${base64Encode(bytes)}';
      }
      attachment.remove(_archiveMimeKey);
    }
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
