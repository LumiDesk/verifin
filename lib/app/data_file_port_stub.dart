Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  throw UnsupportedError('当前平台暂不支持文件下载');
}

Future<String?> pickTextFile() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}

Future<String?> pickCsvFile() async {
  throw UnsupportedError('当前平台暂不支持文件选择');
}
