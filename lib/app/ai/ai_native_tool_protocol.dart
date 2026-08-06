import 'ai_agent_message.dart';
import 'ai_completion_event.dart';
import 'ai_error.dart';

/// 把一个完整 SSE round 的结构化增量归并为补全结果。
AiCompletionResult collectNativeCompletion(Iterable<AiCompletionEvent> events) {
  final content = StringBuffer();
  final reasoning = StringBuffer();
  final calls = <int, _ToolCallBuilder>{};
  var finishReason = AiFinishReason.other;

  for (final event in events) {
    switch (event) {
      case AiContentDelta():
        content.write(event.text);
      case AiReasoningDelta():
        reasoning.write(event.text);
      case AiToolCallDelta():
        calls.putIfAbsent(event.index, _ToolCallBuilder.new).append(event);
      case AiCompletionFinished():
        finishReason = event.reason;
      case AiStreamDone():
        break;
    }
  }

  final toolCalls = <AiNativeToolCall>[];
  for (final index in calls.keys.toList()..sort()) {
    final call = calls[index]!.build();
    if (call == null) {
      throw AiException(
        AiErrorCode.badResponse,
        detail: 'incomplete tool call',
      );
    }
    toolCalls.add(call);
  }
  if (finishReason == AiFinishReason.toolCalls && toolCalls.isEmpty) {
    throw AiException(AiErrorCode.badResponse, detail: 'missing tool call');
  }
  return AiCompletionResult(
    content: content.toString(),
    reasoningContent: reasoning.toString(),
    toolCalls: toolCalls,
    finishReason: finishReason,
  );
}

class _ToolCallBuilder {
  final StringBuffer _name = StringBuffer();
  final StringBuffer _arguments = StringBuffer();
  String? _id;

  void append(AiToolCallDelta delta) {
    final id = delta.id;
    if (id != null && id.isNotEmpty) _id ??= id;
    final name = delta.name;
    if (name != null) _name.write(name);
    final arguments = delta.arguments;
    if (arguments != null) _arguments.write(arguments);
  }

  AiNativeToolCall? build() {
    final id = _id;
    final name = _name.toString().trim();
    if (id == null || id.isEmpty || name.isEmpty) return null;
    return AiNativeToolCall(
      id: id,
      name: name,
      arguments: _arguments.isEmpty ? '{}' : _arguments.toString(),
    );
  }
}
