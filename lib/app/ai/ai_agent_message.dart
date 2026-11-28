import 'dart:convert';

enum AiMessageRole { system, user, assistant, tool }

/// 原生 Tool Calls 中的一次函数调用。
class AiNativeToolCall {
  const AiNativeToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;

  /// OpenAI-compatible 协议要求 arguments 保持 JSON 字符串形态。
  final String arguments;

  Map<String, Object?>? decodeArguments() {
    try {
      final decoded = jsonDecode(arguments);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': 'function',
    'function': <String, Object?>{'name': name, 'arguments': arguments},
  };
}

/// Agent 发送给模型的强类型消息。
sealed class AiAgentMessage {
  const AiAgentMessage(this.role);

  final AiMessageRole role;

  Map<String, Object?> toJson();
}

class AiTextMessage extends AiAgentMessage {
  const AiTextMessage({required AiMessageRole role, required this.content})
    : assert(role != AiMessageRole.tool),
      super(role);

  const AiTextMessage.system(String content)
    : this(role: AiMessageRole.system, content: content);

  const AiTextMessage.user(String content)
    : this(role: AiMessageRole.user, content: content);

  const AiTextMessage.assistant(String content)
    : this(role: AiMessageRole.assistant, content: content);

  final String content;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'content': content,
  };
}

/// 带图片的用户消息。只用于用户自配视觉模型的单轮图片识账/能力探测，
/// 不参与 Agent 的 priorMessages 循环；data URL 体积大，不能按字符预算塞进 Agent。
class AiVisionMessage extends AiAgentMessage {
  const AiVisionMessage({required this.text, required this.imageDataUrl})
    : super(AiMessageRole.user);

  final String text;
  final String imageDataUrl;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'content': <Object?>[
      <String, Object?>{'type': 'text', 'text': text},
      <String, Object?>{
        'type': 'image_url',
        'image_url': <String, Object?>{'url': imageDataUrl},
      },
    ],
  };
}

/// 模型请求本地工具时需要原样回传的 assistant 消息。
class AiAssistantToolMessage extends AiAgentMessage {
  const AiAssistantToolMessage({
    required this.toolCalls,
    this.content,
    this.reasoningContent,
  }) : super(AiMessageRole.assistant);

  final String? content;

  /// 仅供同一个 Agent turn 内兼容推理模型回传；不得显示、记录或持久化。
  final String? reasoningContent;
  final List<AiNativeToolCall> toolCalls;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'content': content,
    if (reasoningContent != null && reasoningContent!.isNotEmpty)
      'reasoning_content': reasoningContent,
    'tool_calls': toolCalls
        .map((call) => call.toJson())
        .toList(growable: false),
  };
}

/// 本地只读工具执行完成后回传给模型的结果。
class AiToolResultMessage extends AiAgentMessage {
  const AiToolResultMessage({required this.toolCallId, required this.content})
    : super(AiMessageRole.tool);

  final String toolCallId;
  final String content;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'tool_call_id': toolCallId,
    'content': content,
  };
}
