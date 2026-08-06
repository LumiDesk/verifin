import 'ai_query_tool.dart';

sealed class AiAgentEvent {
  const AiAgentEvent();
}

class AiAgentToolStarted extends AiAgentEvent {
  const AiAgentToolStarted({
    required this.stepId,
    required this.toolName,
    required this.arguments,
  });

  final String stepId;
  final String toolName;
  final Map<String, Object?> arguments;
}

class AiAgentToolCompleted extends AiAgentEvent {
  const AiAgentToolCompleted({
    required this.stepId,
    required this.toolName,
    required this.arguments,
    required this.result,
    required this.duration,
  });

  final String stepId;
  final String toolName;
  final Map<String, Object?> arguments;
  final AiToolResult result;
  final Duration duration;
}

class AiAgentToolFailed extends AiAgentEvent {
  const AiAgentToolFailed({
    required this.stepId,
    required this.toolName,
    required this.arguments,
    required this.reason,
  });

  final String stepId;
  final String toolName;
  final Map<String, Object?> arguments;

  /// 稳定的内部原因码；不得放入上游原始错误或堆栈。
  final String reason;
}

class AiAgentAnswerDelta extends AiAgentEvent {
  const AiAgentAnswerDelta(this.text);
  final String text;
}

class AiAgentRetrying extends AiAgentEvent {
  const AiAgentRetrying({required this.attempt, required this.reason});
  final int attempt;
  final String reason;
}

class AiAgentCompleted extends AiAgentEvent {
  const AiAgentCompleted(this.answer);
  final String answer;
}

class AiAgentFailed extends AiAgentEvent {
  const AiAgentFailed(this.error, {this.partialAnswer = ''});
  final Object error;
  final String partialAnswer;
}
