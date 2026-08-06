/// OpenAI-compatible 聊天补全的标准化结束原因。
enum AiFinishReason {
  stop,
  toolCalls,
  length,
  contentFilter,
  insufficientSystemResource,
  other,
}

sealed class AiCompletionEvent {
  const AiCompletionEvent();
}

class AiContentDelta extends AiCompletionEvent {
  const AiContentDelta(this.text);
  final String text;
}

class AiReasoningDelta extends AiCompletionEvent {
  const AiReasoningDelta(this.text);
  final String text;
}

class AiToolCallDelta extends AiCompletionEvent {
  const AiToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });

  final int index;
  final String? id;
  final String? name;
  final String? arguments;
}

class AiCompletionFinished extends AiCompletionEvent {
  const AiCompletionFinished(this.reason, {this.rawReason});
  final AiFinishReason reason;
  final String? rawReason;
}

class AiStreamDone extends AiCompletionEvent {
  const AiStreamDone();
}
