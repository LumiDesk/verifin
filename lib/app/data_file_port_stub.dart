import 'dart:typed_data';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  throw UnsupportedError('当前平台暂不支持文件下载');
}

Future<bool> downloadBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/zip',
}) async {
  throw UnsupportedError('当前平台暂不支持文件下载');
}

Future<String?> pickTextFile() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}

/// 选择备份文件并返回其 URI/路径，交给原生流式复制。
Future<String?> pickBackupFileUri({String label = '备份文件'}) async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}

Future<Uint8List?> pickImportBytes({
  required List<String> extensions,
  String label = '账单文件',
}) async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}

Future<String?> pickCsvFile() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}
