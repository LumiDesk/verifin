import 'dart:async';
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

/// 建立 TCP 连接的超时。服务器不可达 / 连接被黑洞挂起时快速失败，
/// 避免请求无限期挂起（自动备份协调器曾因此永久卡住 `_running`）。
const Duration _connectTimeout = Duration(seconds: 30);

/// 小请求（PROPFIND / MKCOL / DELETE 等，无大体积 body）等待响应的超时。
/// 上传 / 下载因 body 可能很大（含图片附件的大备份）不设总超时，仅靠
/// [_connectTimeout] 与协调器层的兜底超时防挂死。
const Duration _responseTimeout = Duration(seconds: 60);
const int _maxWebdavListingBytes = 4 * 1024 * 1024;
const int _maxWebdavDownloadBytes = 256 * 1024 * 1024;

HttpClient _newClient() => HttpClient()..connectionTimeout = _connectTimeout;

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
  if (error is TimeoutException) {
    throw const WebdavException('连接服务器超时，请检查地址与网络');
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
    final response = await request.close().timeout(_responseTimeout);
    await response.drain<void>();
    // 201 创建成功；405/301 通常表示已存在，忽略。
  } catch (_) {
    // 目录创建失败不阻断上传（多数服务器目录已存在）。
  }
}

Future<void> webdavTestConnection(WebdavConfig config) async {
  final client = _newClient();
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
    final response = await request.close().timeout(_responseTimeout);
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

Future<Uint8List> _readResponseLimited(
  HttpClientResponse response, {
  required int maxBytes,
  required String tooLargeMessage,
}) async {
  final builder = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in response) {
    total += chunk.length;
    if (total > maxBytes) {
      throw WebdavException(tooLargeMessage);
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<void> webdavUpload(
  WebdavConfig config,
  String filename,
  List<int> bytes,
) async {
  final client = _newClient();
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
  final client = _newClient();
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
    final response = await request.close().timeout(_responseTimeout);
    final body = utf8.decode(
      await _readResponseLimited(
        response,
        maxBytes: _maxWebdavListingBytes,
        tooLargeMessage: 'WebDAV 文件列表响应过大',
      ).timeout(_responseTimeout),
    );
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
    return parsePropfindResponse(body)
        .where(
          (file) =>
              file.name.endsWith('.json') ||
              file.name.endsWith('.zip') ||
              file.name.endsWith('.verifin'),
        )
        .toList();
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

Future<void> webdavDelete(WebdavConfig config, String href) async {
  final client = _newClient();
  try {
    final request = await _open(
      client,
      'DELETE',
      _resolveHref(config, href),
      config,
    );
    final response = await request.close().timeout(_responseTimeout);
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
  final client = _newClient();
  try {
    final request = await _open(
      client,
      'GET',
      _resolveHref(config, href),
      config,
    );
    // 只对响应头等待设超时；下载 body 可能很大，交给流自身与协调器兜底超时。
    final response = await request.close().timeout(_responseTimeout);
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
    return await _readResponseLimited(
      response,
      maxBytes: _maxWebdavDownloadBytes,
      tooLargeMessage: 'WebDAV 备份文件过大',
    ).timeout(_responseTimeout);
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}

/// 上传本地缓存文件（流式请求体）。备份可能上 GB，绝不能整份读进内存。
Future<void> webdavUploadFile(
  WebdavConfig config,
  String filename,
  String cachePath,
) async {
  final client = _newClient();
  try {
    await _ensureCollection(client, config);
    final target = Uri.parse(joinWebdavUrl(config.url, filename));
    final request = await _open(client, 'PUT', target, config);
    request.headers.contentType = ContentType('application', 'octet-stream');
    request.headers.contentLength = await File(cachePath).length();
    await request.addStream(File(cachePath).openRead());
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

/// 把远端备份流式下载到 [cachePath]。不做固定大小上限：落盘由文件系统限制，
/// 内存占用只与传输分块有关。
Future<void> webdavDownloadToFile(
  WebdavConfig config,
  String href,
  String cachePath,
) async {
  final client = _newClient();
  try {
    final request = await _open(
      client,
      'GET',
      _resolveHref(config, href),
      config,
    );
    final response = await request.close().timeout(_responseTimeout);
    if (response.statusCode >= 400) {
      throw WebdavException(_statusMessage(response.statusCode));
    }
    final sink = File(cachePath).openWrite();
    try {
      await response.pipe(sink);
    } finally {
      await sink.close();
    }
  } catch (error) {
    _fail(error);
  } finally {
    client.close(force: true);
  }
}
