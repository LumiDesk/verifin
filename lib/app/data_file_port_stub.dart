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

/// 选择备份文件并读原始字节（.json 旧版 / .zip 新版统一按字节返回）。
Future<Uint8List?> pickBackupBytes() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}

Future<String?> pickCsvFile() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}
