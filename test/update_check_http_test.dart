import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/update/update_check.dart';

/// 这些用例需要真实 `dart:io` HTTP，因此**不能**与 widget 测试放在同一文件：
/// `TestWidgetsFlutterBinding` 会把所有 HTTP 请求拦成 400。与
/// `test/ai_client_io_test.dart` 一样，本文件只用普通 `test`。

Future<Uri> _serve(Future<void> Function(HttpRequest request) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen(handler);
  return Uri.parse('http://127.0.0.1:${server.port}/releases/latest');
}

void main() {
  test('200 且版本更新时返回目标 tag，并带上固定请求头', () async {
    late HttpHeaders received;
    final endpoint = await _serve((request) async {
      received = request.headers;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{'tag_name': 'v1.21.0'}),
      );
      await request.response.close();
    });

    final result = await checkForUpdate(
      endpoint: endpoint,
      currentVersion: '1.20.15',
    );
    expect(result, isA<UpdateAvailable>());
    expect((result as UpdateAvailable).release.tag, 'v1.21.0');
    expect(received.value(HttpHeaders.userAgentHeader), 'VeriFin/1.20.15');
    expect(
      received.value(HttpHeaders.acceptHeader),
      'application/vnd.github+json',
    );
  });

  test('200 且版本相同时提示已是最新', () async {
    final endpoint = await _serve((request) async {
      request.response.write(
        jsonEncode(<String, Object?>{'tag_name': 'v1.20.15'}),
      );
      await request.response.close();
    });
    final result = await checkForUpdate(
      endpoint: endpoint,
      currentVersion: '1.20.15',
    );
    expect(result, isA<UpdateUpToDate>());
  });

  test('非 200 归为失败并带上状态码原因', () async {
    final endpoint = await _serve((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });
    final result = await checkForUpdate(
      endpoint: endpoint,
      currentVersion: '1.0.0',
    );
    expect(result, isA<UpdateCheckFailed>());
    expect((result as UpdateCheckFailed).reason, 'http 503');
  });

  test('非 JSON 归为失败', () async {
    final endpoint = await _serve((request) async {
      request.response.write('not json');
      await request.response.close();
    });
    final result = await checkForUpdate(
      endpoint: endpoint,
      currentVersion: '1.0.0',
    );
    expect(result, isA<UpdateCheckFailed>());
    expect((result as UpdateCheckFailed).reason, 'invalid json');
  });

  test('连接失败归为失败而不是抛错', () async {
    // 绑定后立即关闭端口，确保连接被拒绝。
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final result = await checkForUpdate(
      endpoint: Uri.parse('http://127.0.0.1:$port/releases/latest'),
      currentVersion: '1.0.0',
    );
    expect(result, isA<UpdateCheckFailed>());
  });
}
