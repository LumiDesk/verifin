import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'webdav_config.dart';

/// WebDAV 操作异常，面向用户可读。
class WebdavException implements Exception {
  const WebdavException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _propfindBody =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:"><d:prop>'
    '<d:getlastmodified/><d:getcontentlength/><d:resourcetype/>'
    '</d:prop></d:propfind>';

String _authHeader(WebdavConfig config) {
  final raw = '${config.username}:${config.password}';
  return 'Basic ${base64Encode(utf8.encode(raw))}';
}

Future<HttpClientRequest> _open(
  HttpClient client,
  String method,
  Uri uri,
  WebdavConfig config,
) async {
  final request = await client.openUrl(method, uri);
  request.headers.set(HttpHeaders.authorizationHeader, _authHeader(config));
  request.followRedirects = true;
  return request;
}

Never _fail(Object error) {
  if (error is WebdavException) {
    throw error;
  }
  if (error is SocketException) {
    throw const WebdavException('无法连接服务器，请检查地址与网络');
  }
  if (error is HandshakeException) {
    throw const WebdavException('HTTPS 握手失败，请检查服务器证书');
  }
  throw WebdavException('WebDAV 请求失败：$error');
}

String _statusMessage(int status) {
  switch (status) {
    case 401:
    case 403:
      return '认证失败，请检查账号或密码';
    case 404:
      return '路径不存在，请检查服务器地址';
    case 405:
      return '服务器不支持该操作';
    default:
      return '服务器返回错误（$status）';
  }
}

Uri _collectionUri(WebdavConfig config) {
  final uri = Uri.tryParse(normalizeCollectionUrl(config.url));
  if (uri == null || !uri.hasScheme) {
    throw const WebdavException('WebDAV 地址无效');
  }
  return uri;
}

/// 把 PROPFIND 返回的 href（可能是服务器绝对路径）解析为完整 URL。
Uri _resolveHref(WebdavConfig config, String href) {
  final base = _collectionUri(config);
  return base.resolve(href);
}

Future<void> _ensureCollection(HttpClient client, WebdavConfig config) async {
  try {
    final request = await _open(
      client,
      'MKCOL',
      _collectionUri(config),
      config,
    );
    final response = await request.close();
    await response.drain<void>();
    // 201 创建成功；405/301 通常表示已存在，忽略。
  } catch (_) {
    // 目录创建失败不阻断上传（多数服务器目录已存在）。
  }
}

Future<void> webdavTestConnection(WebdavConfig config) async {
  final client = HttpClient();
  try {
    final request = await _open(
      client,
      'PROPFIND',
      _collectionUri(config),
      config,
    );
    request.headers.set('Depth', '0');
    request.headers.contentType = ContentType(
      'application',
      'xml',
      charset: 'utf-8',
    );
    request.write(_propfindBody);
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

Future<void> webdavUpload(
  WebdavConfig config,
  String filename,
  List<int> bytes,
) async {
  final client = HttpClient();
  try {
    await _ensureCollection(client, config);
    final target = Uri.parse(joinWebdavUrl(config.url, filename));
    final request = await _open(client, 'PUT', target, config);
    request.headers.contentType = ContentType('application', 'octet-stream');
    request.headers.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

Future<List<WebdavRemoteFile>> webdavList(WebdavConfig config) async {
  final client = HttpClient();
  try {
    final request = await _open(
      client,
      'PROPFIND',
      _collectionUri(config),
      config,
    );
    request.headers.set('Depth', '1');
    request.headers.contentType = ContentType(
      'application',
      'xml',
      charset: 'utf-8',
    );
    request.write(_propfindBody);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
    return parsePropfindResponse(body)
        .where(
          (file) => file.name.endsWith('.json') || file.name.endsWith('.zip'),
        )
        .toList();
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

Future<void> webdavDelete(WebdavConfig config, String href) async {
  final client = HttpClient();
  try {
    final request = await _open(
      client,
      'DELETE',
      _resolveHref(config, href),
      config,
    );
    final response = await request.close();
    await response.drain<void>();
    // 404 视为已删除，其余 4xx/5xx 报错。
    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> webdavDownload(WebdavConfig config, String href) async {
  final client = HttpClient();
  try {
    final request = await _open(
      client,
      'GET',
      _resolveHref(config, href),
      config,
    );
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.toBytes();
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}
