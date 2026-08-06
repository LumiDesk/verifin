import 'dart:convert';

import 'ai_agent_message.dart';
import 'ai_client.dart';
import 'ai_completion_event.dart';
import 'ai_settings.dart';

const int aiCapabilityProtocolVersion = 1;

enum AiNativeToolCapability {
  unknown,
  supported,
  unsupported;

  static AiNativeToolCapability fromJson(Object? value) => switch (value) {
    'supported' => AiNativeToolCapability.supported,
    'unsupported' => AiNativeToolCapability.unsupported,
    _ => AiNativeToolCapability.unknown,
  };
}

/// 与端点和模型绑定的设备本地能力缓存，不含 API Key 或账目数据。
class AiCapabilityProfile {
  const AiCapabilityProfile({
    required this.endpoint,
    required this.model,
    required this.nativeToolCalls,
    required this.checkedAt,
    this.protocolVersion = aiCapabilityProtocolVersion,
  });

  final String endpoint;
  final String model;
  final AiNativeToolCapability nativeToolCalls;
  final DateTime checkedAt;
  final int protocolVersion;

  factory AiCapabilityProfile.forSettings({
    required AiSettings settings,
    required AiNativeToolCapability nativeToolCalls,
    DateTime? checkedAt,
  }) {
    return AiCapabilityProfile(
      endpoint: normalizeAiEndpoint(settings.chatCompletionsUrl),
      model: settings.model.trim(),
      nativeToolCalls: nativeToolCalls,
      checkedAt: checkedAt ?? DateTime.now(),
    );
  }

  bool matches(AiSettings settings) {
    return protocolVersion == aiCapabilityProtocolVersion &&
        endpoint == normalizeAiEndpoint(settings.chatCompletionsUrl) &&
        model == settings.model.trim();
  }

  AiToolCallMode effectiveMode(AiSettings settings) {
    if (settings.toolCallMode != AiToolCallMode.auto) {
      return settings.toolCallMode;
    }
    if (!matches(settings)) return AiToolCallMode.auto;
    return switch (nativeToolCalls) {
      AiNativeToolCapability.supported => AiToolCallMode.native,
      AiNativeToolCapability.unsupported => AiToolCallMode.prompt,
      AiNativeToolCapability.unknown => AiToolCallMode.auto,
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'endpoint': endpoint,
    'model': model,
    'nativeToolCalls': nativeToolCalls.name,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    'protocolVersion': protocolVersion,
  };

  String encode() => jsonEncode(toJson());

  static AiCapabilityProfile? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, Object?>.from(decoded);
      final endpoint = json['endpoint'];
      final model = json['model'];
      final checkedAt = DateTime.tryParse(json['checkedAt']?.toString() ?? '');
      final protocolVersion = json['protocolVersion'];
      if (endpoint is! String ||
          endpoint.isEmpty ||
          model is! String ||
          model.isEmpty ||
          checkedAt == null ||
          protocolVersion is! int) {
        return null;
      }
      return AiCapabilityProfile(
        endpoint: endpoint,
        model: model,
        nativeToolCalls: AiNativeToolCapability.fromJson(
          json['nativeToolCalls'],
        ),
        checkedAt: checkedAt,
        protocolVersion: protocolVersion,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is AiCapabilityProfile &&
        other.endpoint == endpoint &&
        other.model == model &&
        other.nativeToolCalls == nativeToolCalls &&
        other.checkedAt == checkedAt &&
        other.protocolVersion == protocolVersion;
  }

  @override
  int get hashCode =>
      Object.hash(endpoint, model, nativeToolCalls, checkedAt, protocolVersion);
}

/// 解析本次 Agent 请求应交给引擎的协议模式。
///
/// 已确认不支持原生工具的端点可直接使用兼容协议；其余自动模式必须继续交给
/// 引擎，以便端点能力变化时仍能在本次请求内从原生协议安全降级。
AiToolCallMode resolveAiAgentMode({
  required AiSettings settings,
  required AiCapabilityProfile? capability,
}) {
  if (settings.toolCallMode != AiToolCallMode.auto) {
    return settings.toolCallMode;
  }
  if (capability?.matches(settings) == true &&
      capability?.nativeToolCalls == AiNativeToolCapability.unsupported) {
    return AiToolCallMode.prompt;
  }
  return AiToolCallMode.auto;
}

typedef AiCapabilityCompleteTransport =
    Future<AiCompletionResult> Function(
      List<AiAgentMessage> messages,
      List<Map<String, Object?>> tools,
    );

typedef AiCapabilityStreamTransport =
    Stream<AiCompletionEvent> Function(
      List<AiAgentMessage> messages,
      List<Map<String, Object?>> tools,
    );

/// 依次验证普通补全、SSE 与原生 Tool Calls。探测请求不含任何账目数据。
Future<AiCapabilityProfile> detectAiCapabilities({
  required AiSettings settings,
  AiCapabilityCompleteTransport? completeTransport,
  AiCapabilityStreamTransport? streamTransport,
  DateTime? checkedAt,
}) async {
  final complete =
      completeTransport ??
      (messages, tools) =>
          aiAgentComplete(settings: settings, messages: messages, tools: tools);
  final stream =
      streamTransport ??
      (messages, tools) =>
          aiAgentStream(settings: settings, messages: messages, tools: tools);

  final ping = await complete(const <AiAgentMessage>[
    AiTextMessage.system('Reply with the single word OK.'),
    AiTextMessage.user('ping'),
  ], const <Map<String, Object?>>[]);
  if (ping.content.trim().isEmpty) {
    throw AiException(AiErrorCode.badResponse, detail: 'empty health check');
  }

  final streamEvents = await stream(const <AiAgentMessage>[
    AiTextMessage.system('Reply with the single word OK.'),
    AiTextMessage.user('stream ping'),
  ], const <Map<String, Object?>>[]).toList();
  if (streamEvents.whereType<AiContentDelta>().every(
    (event) => event.text.isEmpty,
  )) {
    throw AiException(AiErrorCode.badResponse, detail: 'empty stream check');
  }

  var capability = AiNativeToolCapability.unsupported;
  try {
    final probe = await complete(
      const <AiAgentMessage>[
        AiTextMessage.system(
          'Call verifinCapabilityProbe exactly once. Do not answer in text.',
        ),
        AiTextMessage.user('probe tool calling support'),
      ],
      const <Map<String, Object?>>[
        <String, Object?>{
          'type': 'function',
          'function': <String, Object?>{
            'name': 'verifinCapabilityProbe',
            'description': 'Capability probe with no user data.',
            'parameters': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{},
              'additionalProperties': false,
            },
          },
        },
      ],
    );
    if (probe.toolCalls.any((call) => call.name == 'verifinCapabilityProbe')) {
      capability = AiNativeToolCapability.supported;
    }
  } on AiException catch (error) {
    if (error.code != AiErrorCode.protocolUnsupported) rethrow;
  }

  return AiCapabilityProfile.forSettings(
    settings: settings,
    nativeToolCalls: capability,
    checkedAt: checkedAt,
  );
}

String normalizeAiEndpoint(String value) {
  final trimmed = value.trim();
  try {
    final uri = Uri.parse(trimmed);
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: path,
          fragment: '',
        )
        .toString();
  } on FormatException {
    return trimmed;
  }
}
