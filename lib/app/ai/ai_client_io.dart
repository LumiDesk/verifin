import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'ai_agent_message.dart';
import 'ai_completion_event.dart';
import 'ai_error.dart';
import 'ai_settings.dart';

export 'ai_error.dart' show AiException, AiErrorCode, aiErrorMessage;

const Duration _defaultConnectTimeout = Duration(seconds: 20);
const Duration _defaultResponseTimeout = Duration(seconds: 60);
const Duration _defaultStreamIdleTimeout = Duration(seconds: 45);
const Duration _defaultTotalTimeout = Duration(seconds: 120);
const int _defaultMaxResponseBytes = 2 * 1024 * 1024;
const int _defaultMaxStreamEvents = 10000;
// 图片 data URL 会放大请求体；超过此上限直接拒绝，避免把大图发出去。
const int _defaultMaxRequestBytes = 8 * 1024 * 1024;

/// 发起一次非流式 OpenAI-compatible 补全，并保留文本、推理字段与 Tool Calls。
Future<AiCompletionResult> aiAgentComplete({
  required AiSettings settings,
  required List<AiAgentMessage> messages,
  List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
  double temperature = 0,
  Duration connectionTimeout = _defaultConnectTimeout,
  Duration responseTimeout = _defaultResponseTimeout,
  Duration totalTimeout = _defaultTotalTimeout,
  int maxResponseBytes = _defaultMaxResponseBytes,
}) async {
  _ensureConfigured(settings);
  final client = HttpClient()..connectionTimeout = connectionTimeout;
  var totalExpired = false;
  final totalTimer = Timer(totalTimeout, () {
    totalExpired = true;
    client.close(force: true);
  });
  try {
    final response = await _post(
      client: client,
      settings: settings,
      body: _requestBody(
        settings: settings,
        messages: messages,
        tools: tools,
        temperature: temperature,
        stream: false,
      ),
      responseTimeout: responseTimeout,
    );
    final responseText = await _readBoundedBody(
      response,
      maxBytes: maxResponseBytes,
      totalTimeout: totalTimeout,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw _statusException(
        response.statusCode,
        responseText,
        usedTools: tools.isNotEmpty,
      );
    }
    return _parseCompletion(responseText);
  } catch (error) {
    if (totalExpired) {
      throw AiException(AiErrorCode.timeout);
    }
    throw _mapTransportError(error);
  } finally {
    totalTimer.cancel();
    client.close(force: true);
  }
}

/// 发起流式 OpenAI-compatible 补全，产出结构化 SSE 事件。
///
/// 响应体连续 [idleTimeout] 没有任何字节会超时；流自然结束时必须已经收到
/// `[DONE]` 或合法 `finish_reason`，否则按不完整响应处理。
Stream<AiCompletionEvent> aiAgentStream({
  required AiSettings settings,
  required List<AiAgentMessage> messages,
  List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
  double temperature = 0,
  Duration connectionTimeout = _defaultConnectTimeout,
  Duration responseTimeout = _defaultResponseTimeout,
  Duration idleTimeout = _defaultStreamIdleTimeout,
  Duration totalTimeout = _defaultTotalTimeout,
  int maxResponseBytes = _defaultMaxResponseBytes,
  int maxStreamEvents = _defaultMaxStreamEvents,
}) async* {
  _ensureConfigured(settings);
  final client = HttpClient()..connectionTimeout = connectionTimeout;
  var sawDone = false;
  var sawFinish = false;
  var totalExpired = false;
  final totalTimer = Timer(totalTimeout, () {
    totalExpired = true;
    client.close(force: true);
  });
  try {
    final response = await _post(
      client: client,
      settings: settings,
      body: _requestBody(
        settings: settings,
        messages: messages,
        tools: tools,
        temperature: temperature,
        stream: true,
      ),
      responseTimeout: responseTimeout,
      acceptEventStream: true,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      final errorText = await _readBoundedBody(
        response,
        maxBytes: maxResponseBytes,
        totalTimeout: totalTimeout,
      );
      throw _statusException(
        response.statusCode,
        errorText,
        usedTools: tools.isNotEmpty,
      );
    }

    var responseBytes = 0;
    var eventCount = 0;
    final lines = response
        .map((chunk) {
          responseBytes += chunk.length;
          if (responseBytes > maxResponseBytes) {
            throw AiException(
              AiErrorCode.responseTooLarge,
              detail: 'stream response too large',
            );
          }
          return chunk;
        })
        .timeout(idleTimeout)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      eventCount += 1;
      if (eventCount > maxStreamEvents) {
        throw AiException(
          AiErrorCode.responseTooLarge,
          detail: 'too many stream events',
        );
      }
      if (data == '[DONE]') {
        sawDone = true;
        yield const AiStreamDone();
        break;
      }
      for (final event in _parseStreamPayload(data)) {
        if (event is AiCompletionFinished) {
          sawFinish = true;
        }
        yield event;
      }
    }
    if (!sawDone && !sawFinish) {
      throw AiException(AiErrorCode.incompleteStream);
    }
  } catch (error) {
    if (totalExpired) {
      throw AiException(AiErrorCode.timeout);
    }
    throw _mapTransportError(error);
  } finally {
    totalTimer.cancel();
    client.close(force: true);
  }
}

/// 旧的文本补全入口仍供 AI 记账解析使用；内部统一走强类型传输。
Future<String> aiChatComplete({
  required AiSettings settings,
  String? systemPrompt,
  String? userPrompt,
  List<Map<String, String>>? messages,
  double temperature = 0,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final result = await aiAgentComplete(
    settings: settings,
    messages: messages == null
        ? <AiAgentMessage>[
            if (systemPrompt != null) AiTextMessage.system(systemPrompt),
            if (userPrompt != null) AiTextMessage.user(userPrompt),
          ]
        : _legacyMessages(messages),
    temperature: temperature,
    connectionTimeout: timeout,
    responseTimeout: timeout,
  );
  if (result.content.trim().isEmpty) {
    throw AiException(AiErrorCode.badResponse, detail: 'empty content');
  }
  return result.content;
}

void _ensureConfigured(AiSettings settings) {
  if (!settings.isConfigured) {
    throw AiException(AiErrorCode.notConfigured);
  }
}

List<AiAgentMessage> _legacyMessages(List<Map<String, String>> messages) {
  return messages
      .map((message) {
        final role = switch (message['role']) {
          'system' => AiMessageRole.system,
          'assistant' => AiMessageRole.assistant,
          _ => AiMessageRole.user,
        };
        return AiTextMessage(role: role, content: message['content'] ?? '');
      })
      .toList(growable: false);
}

Map<String, Object?> _requestBody({
  required AiSettings settings,
  required List<AiAgentMessage> messages,
  required List<Map<String, Object?>> tools,
  required double temperature,
  required bool stream,
}) {
  return <String, Object?>{
    'model': settings.model.trim(),
    'messages': messages
        .map((message) => message.toJson())
        .toList(growable: false),
    'temperature': temperature,
    'stream': stream,
    if (tools.isNotEmpty) ...<String, Object?>{
      'tools': tools,
      'tool_choice': 'auto',
    },
  };
}

Future<HttpClientResponse> _post({
  required HttpClient client,
  required AiSettings settings,
  required Map<String, Object?> body,
  required Duration responseTimeout,
  bool acceptEventStream = false,
}) async {
  final Uri uri;
  try {
    uri = Uri.parse(settings.chatCompletionsUrl);
  } on FormatException {
    throw AiException(AiErrorCode.badUrl);
  }
  final request = await client.openUrl('POST', uri).timeout(responseTimeout);
  final apiKey = settings.apiKey.trim();
  if (apiKey.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
  }
  request.headers.contentType = ContentType.json;
  if (acceptEventStream) {
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
  }
  request.followRedirects = true;
  final encodedBody = utf8.encode(jsonEncode(body));
  if (encodedBody.length > _defaultMaxRequestBytes) {
    throw AiException(
      AiErrorCode.requestTooLarge,
      detail: 'request body too large',
    );
  }
  request.add(encodedBody);
  return request.close().timeout(responseTimeout);
}

AiCompletionResult _parseCompletion(String responseText) {
  final root = _decodeRoot(responseText);
  _throwEmbeddedError(root);
  final choice = _firstChoice(root);
  final message = _stringMap(choice['message']);
  final content =
      _stringValue(message?['content']) ?? _stringValue(choice['text']) ?? '';
  final reasoning =
      _stringValue(message?['reasoning_content']) ??
      _stringValue(message?['reasoning']) ??
      '';
  final toolCalls = _parseToolCalls(message?['tool_calls']);
  if (content.trim().isEmpty && toolCalls.isEmpty) {
    throw AiException(AiErrorCode.badResponse, detail: 'empty completion');
  }
  return AiCompletionResult(
    content: content,
    reasoningContent: reasoning,
    toolCalls: toolCalls,
    finishReason: _finishReason(_stringValue(choice['finish_reason'])),
  );
}

List<AiCompletionEvent> _parseStreamPayload(String data) {
  final root = _decodeRoot(data);
  _throwEmbeddedError(root);
  final choices = root['choices'];
  if (choices is! List || choices.isEmpty) return const <AiCompletionEvent>[];
  final choice = _stringMap(choices.first);
  if (choice == null) {
    throw AiException(AiErrorCode.badResponse, detail: 'invalid choice');
  }
  final events = <AiCompletionEvent>[];
  final delta = _stringMap(choice['delta']);
  final content =
      _stringValue(delta?['content']) ?? _stringValue(choice['text']);
  if (content != null && content.isNotEmpty) {
    events.add(AiContentDelta(content));
  }
  final reasoning =
      _stringValue(delta?['reasoning_content']) ??
      _stringValue(delta?['reasoning']);
  if (reasoning != null && reasoning.isNotEmpty) {
    events.add(AiReasoningDelta(reasoning));
  }
  final rawToolCalls = delta?['tool_calls'];
  if (rawToolCalls is List) {
    for (final rawCall in rawToolCalls) {
      final call = _stringMap(rawCall);
      if (call == null) continue;
      final index = call['index'];
      if (index is! int) continue;
      final function = _stringMap(call['function']);
      events.add(
        AiToolCallDelta(
          index: index,
          id: _stringValue(call['id']),
          name: _stringValue(function?['name']),
          arguments: _stringValue(function?['arguments']),
        ),
      );
    }
  }
  final finish = _stringValue(choice['finish_reason']);
  if (finish != null && finish.isNotEmpty) {
    events.add(AiCompletionFinished(_finishReason(finish), rawReason: finish));
  }
  return events;
}

Map<String, Object?> _decodeRoot(String source) {
  try {
    final decoded = jsonDecode(source);
    final root = _stringMap(decoded);
    if (root != null) return root;
  } on FormatException {
    // 在下方统一映射为 badResponse。
  }
  throw AiException(AiErrorCode.badResponse, detail: 'non-JSON response');
}

Map<String, Object?> _firstChoice(Map<String, Object?> root) {
  final choices = root['choices'];
  if (choices is List && choices.isNotEmpty) {
    final choice = _stringMap(choices.first);
    if (choice != null) return choice;
  }
  throw AiException(AiErrorCode.badResponse, detail: 'missing choice');
}

List<AiNativeToolCall> _parseToolCalls(Object? value) {
  if (value is! List) return const <AiNativeToolCall>[];
  final calls = <AiNativeToolCall>[];
  for (final rawCall in value) {
    final call = _stringMap(rawCall);
    final function = _stringMap(call?['function']);
    final id = _stringValue(call?['id']);
    final name = _stringValue(function?['name']);
    final rawArguments = function?['arguments'];
    final arguments = rawArguments is String
        ? rawArguments
        : rawArguments is Map
        ? jsonEncode(rawArguments)
        : null;
    if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
    calls.add(
      AiNativeToolCall(id: id, name: name, arguments: arguments ?? '{}'),
    );
  }
  return calls;
}

Map<String, Object?>? _stringMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : null;

String? _stringValue(Object? value) => value is String ? value : null;

AiFinishReason _finishReason(String? value) => switch (value) {
  'stop' => AiFinishReason.stop,
  'tool_calls' || 'function_call' => AiFinishReason.toolCalls,
  'length' => AiFinishReason.length,
  'content_filter' => AiFinishReason.contentFilter,
  'insufficient_system_resource' => AiFinishReason.insufficientSystemResource,
  _ => AiFinishReason.other,
};

void _throwEmbeddedError(Map<String, Object?> root) {
  final error = _stringMap(root['error']);
  final message = _stringValue(error?['message']);
  if (message != null) {
    throw AiException(AiErrorCode.upstream, detail: message);
  }
}

AiException _statusException(
  int statusCode,
  String responseText, {
  required bool usedTools,
}) {
  String? detail;
  try {
    final root = _decodeRoot(responseText);
    final error = _stringMap(root['error']);
    detail = _stringValue(error?['message']) ?? _stringValue(root['message']);
  } on AiException {
    // 非 JSON 错误页仅按状态码分类。
  }
  if (usedTools && _indicatesUnsupportedTools(detail ?? responseText)) {
    return AiException(AiErrorCode.protocolUnsupported, detail: detail);
  }
  final code = switch (statusCode) {
    HttpStatus.unauthorized || HttpStatus.forbidden => AiErrorCode.authFailed,
    HttpStatus.notFound => AiErrorCode.notFound,
    HttpStatus.tooManyRequests => AiErrorCode.rateLimited,
    _ => AiErrorCode.serverError,
  };
  return AiException(code, detail: detail ?? '$statusCode');
}

bool _indicatesUnsupportedTools(String value) {
  final lower = value.toLowerCase();
  return (lower.contains('tool') || lower.contains('function')) &&
      (lower.contains('unsupported') ||
          lower.contains('not support') ||
          lower.contains('unknown') ||
          lower.contains('unrecognized'));
}

AiException _mapTransportError(Object error) {
  if (error is AiException) return error;
  if (error is TimeoutException) return AiException(AiErrorCode.timeout);
  if (error is HandshakeException) return AiException(AiErrorCode.tls);
  if (error is SocketException) {
    return AiException(AiErrorCode.network, detail: error.message);
  }
  if (error is HttpException) {
    return AiException(AiErrorCode.network, detail: error.message);
  }
  if (error is FormatException) {
    return AiException(AiErrorCode.badResponse);
  }
  if (error is ArgumentError) {
    return AiException(AiErrorCode.badUrl);
  }
  return AiException(AiErrorCode.unknown, detail: '$error');
}

Future<String> _readBoundedBody(
  HttpClientResponse response, {
  required int maxBytes,
  required Duration totalTimeout,
}) async {
  final bytes = BytesBuilder(copy: false);
  var received = 0;
  final read = () async {
    await for (final chunk in response) {
      received += chunk.length;
      if (received > maxBytes) {
        throw AiException(
          AiErrorCode.responseTooLarge,
          detail: 'response body too large',
        );
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }();
  return read.timeout(totalTimeout);
}
