import 'webdav_config.dart';

/// WebDAV 操作异常，面向用户可读。
class WebdavException implements Exception {
  const WebdavException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> webdavTestConnection(WebdavConfig config) async {
  throw const WebdavException('Web 端受浏览器跨域限制，暂不支持 WebDAV，请在移动端使用');
}

Future<void> webdavUpload(
  WebdavConfig config,
  String filename,
  String content,
) async {
  throw const WebdavException('Web 端受浏览器跨域限制，暂不支持 WebDAV，请在移动端使用');
}

Future<List<WebdavRemoteFile>> webdavList(WebdavConfig config) async {
  throw const WebdavException('Web 端受浏览器跨域限制，暂不支持 WebDAV，请在移动端使用');
}

Future<String> webdavDownload(WebdavConfig config, String href) async {
  throw const WebdavException('Web 端受浏览器跨域限制，暂不支持 WebDAV，请在移动端使用');
}
