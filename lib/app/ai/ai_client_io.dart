import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_settings.dart';

/// AI 请求失败时抛出，`message` 为已本地化/可读的错误说明。
class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 向 OpenAI 兼容的聊天补全接口发一次请求，返回助手消息的文本内容。
///
/// [messages] 未指定时用 [systemPrompt]/[userPrompt] 组两条消息。请求体不带
/// `response_format`（不少自建/第三方端点不支持），靠提示词约束输出，由调用方
/// 从文本中提取 JSON，兼容性最好。[temperature] 默认 0 让解析结果稳定。
Future<String> aiChatComplete({
  required AiSettings settings,
  String? systemPrompt,
  String? userPrompt,
  List<Map<String, String>>? messages,
  double temperature = 0,
  Duration timeout = const Duration(seconds: 45),
}) async {
  if (!settings.isConfigured) {
    throw AiException('AI 未配置：请先填写请求地址、API Key 与模型。');
  }
  final resolvedMessages =
      messages ??
      <Map<String, String>>[
        if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
        if (userPrompt != null) {'role': 'user', 'content': userPrompt},
      ];
  final body = jsonEncode(<String, Object?>{
    'model': settings.model.trim(),
    'messages': resolvedMessages,
    'temperature': temperature,
    'stream': false,
  });

  final client = HttpClient();
  client.connectionTimeout = timeout;
  try {
    final uri = Uri.parse(settings.chatCompletionsUrl);
    final request = await client.openUrl('POST', uri).timeout(timeout);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${settings.apiKey.trim()}',
    );
    request.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    request.followRedirects = true;
    request.add(utf8.encode(body));

    final response = await request.close().timeout(timeout);
    final responseText = await response
        .transform(utf8.decoder)
        .join()
        .timeout(timeout);
    if (response.statusCode >= 400) {
      throw AiException(_statusMessage(response.statusCode, responseText));
    }
    return _extractContent(responseText);
  } on AiException {
    rethrow;
  } on TimeoutException {
    throw AiException('请求超时，请检查网络或稍后重试。');
  } on SocketException catch (error) {
    throw AiException('无法连接到服务器：${error.message}');
  } on HandshakeException {
    throw AiException('TLS 握手失败，请检查请求地址是否为 https。');
  } on FormatException {
    throw AiException('请求地址无效，请检查基础地址格式。');
  } catch (error) {
    throw AiException('请求失败：$error');
  } finally {
    client.close(force: true);
  }
}

String _extractContent(String responseText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseText);
  } catch (_) {
    throw AiException('无法解析服务器响应（非 JSON）。');
  }
  if (decoded is! Map) {
    throw AiException('服务器响应格式异常。');
  }
  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map) {
      final message = first['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content;
        }
      }
      // 兼容部分端点把文本放在 text 字段。
      final text = first['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text;
      }
    }
  }
  // 上游透传的错误对象。
  final error = decoded['error'];
  if (error is Map && error['message'] is String) {
    throw AiException('服务器返回错误：${error['message']}');
  }
  throw AiException('服务器未返回有效内容。');
}

String _statusMessage(int statusCode, String responseText) {
  // 优先透出上游的错误描述。
  try {
    final decoded = jsonDecode(responseText);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        return '（$statusCode）${error['message']}';
      }
      if (decoded['message'] is String) {
        return '（$statusCode）${decoded['message']}';
      }
    }
  } catch (_) {
    // 忽略，回落到状态码文案。
  }
  switch (statusCode) {
    case 401:
      return 'API Key 无效或未授权（401）。';
    case 403:
      return '无权访问（403），请检查 API Key 权限。';
    case 404:
      return '接口不存在（404），请检查请求地址与模型名。';
    case 429:
      return '请求过于频繁或额度不足（429）。';
    default:
      return '服务器返回错误（$statusCode）。';
  }
}
