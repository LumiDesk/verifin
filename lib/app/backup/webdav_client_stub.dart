import 'webdav_config.dart';

/// WebDAV 操作异常，面向用户可读。
class WebdavException implements Exception {
  const WebdavException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> webdavTestConnection(WebdavConfig config) async {
  throw const WebdavException('当前平台不支持 WebDAV');
}

Future<void> webdavUpload(
  WebdavConfig config,
  String filename,
  String content,
) async {
  throw const WebdavException('当前平台不支持 WebDAV');
}

Future<List<WebdavRemoteFile>> webdavList(WebdavConfig config) async {
  throw const WebdavException('当前平台不支持 WebDAV');
}

Future<String> webdavDownload(WebdavConfig config, String href) async {
  throw const WebdavException('当前平台不支持 WebDAV');
}
