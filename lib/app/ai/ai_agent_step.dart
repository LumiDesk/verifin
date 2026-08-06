enum AiAgentStepStatus { running, succeeded, failed, retrying }

/// 用户可见、可持久化的 Agent 操作轨迹。不包含协议原文、思维链或底层异常。
class AiAgentStep {
  const AiAgentStep({
    required this.id,
    required this.toolName,
    required this.status,
    this.arguments = const <String, Object?>{},
    this.summary = '',
  });

  final String id;
  final String toolName;
  final AiAgentStepStatus status;
  final Map<String, Object?> arguments;
  final String summary;

  AiAgentStep copyWith({AiAgentStepStatus? status, String? summary}) {
    return AiAgentStep(
      id: id,
      toolName: toolName,
      status: status ?? this.status,
      arguments: arguments,
      summary: summary ?? this.summary,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tool': toolName,
    'status': status.name,
    if (arguments.isNotEmpty) 'args': _safeArguments(arguments),
    if (summary.isNotEmpty) 'summary': summary,
  };

  static AiAgentStep? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final id = json['id'];
    final tool = json['tool'];
    final status = switch (json['status']) {
      'succeeded' => AiAgentStepStatus.succeeded,
      'failed' => AiAgentStepStatus.failed,
      _ => null,
    };
    if (id is! String ||
        id.isEmpty ||
        tool is! String ||
        tool.isEmpty ||
        status == null) {
      return null;
    }
    final rawArguments = json['args'];
    return AiAgentStep(
      id: id,
      toolName: tool,
      status: status,
      arguments: rawArguments is Map
          ? _safeArguments(Map<String, Object?>.from(rawArguments))
          : const <String, Object?>{},
      summary: json['summary']?.toString() ?? '',
    );
  }
}

Map<String, Object?> _safeArguments(Map<String, Object?> arguments) {
  return <String, Object?>{
    for (final entry in arguments.entries)
      if (entry.value is String || entry.value is num || entry.value is bool)
        entry.key:
            entry.value is String && (entry.value! as String).length > 100
            ? (entry.value! as String).substring(0, 100)
            : entry.value,
  };
}
