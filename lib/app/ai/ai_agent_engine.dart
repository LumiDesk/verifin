import 'ai_agent_event.dart';
import 'ai_agent_message.dart';
import 'ai_completion_event.dart';
import 'ai_error.dart';
import 'ai_native_tool_protocol.dart';
import 'ai_prompt_tool_protocol.dart';
import 'ai_query_tool.dart';
import 'ai_settings.dart';

typedef AiAgentStreamTransport =
    Stream<AiCompletionEvent> Function(
      List<AiAgentMessage> messages,
      List<Map<String, Object?>> tools,
    );

typedef AiAgentCompleteTransport =
    Future<AiCompletionResult> Function(
      List<AiAgentMessage> messages,
      List<Map<String, Object?>> tools,
    );

/// 只读财务 Agent。协议差异只负责编解码，工具执行、轮次、边界和 UI 事件共用此状态机。
class AiAgentEngine {
  const AiAgentEngine({
    required this.tools,
    this.maxToolRounds = 5,
    this.maxToolCalls = 10,
    this.maxPriorMessages = 12,
    this.maxPriorCharacters = 12000,
    this.maxToolSummaryCharacters = 4000,
  });

  final List<AiQueryTool> tools;
  final int maxToolRounds;
  final int maxToolCalls;
  final int maxPriorMessages;
  final int maxPriorCharacters;
  final int maxToolSummaryCharacters;

  Stream<AiAgentEvent> run({
    required AiToolCallMode mode,
    required AiAgentStreamTransport streamTransport,
    AiAgentCompleteTransport? completeTransport,
    required AiToolContext context,
    required List<AiTextMessage> priorMessages,
    required String userInput,
  }) async* {
    final initialProtocol = mode == AiToolCallMode.prompt
        ? _AgentProtocol.prompt
        : _AgentProtocol.native;
    try {
      await for (final event in _runProtocol(
        protocol: initialProtocol,
        streamTransport: streamTransport,
        completeTransport: completeTransport,
        context: context,
        priorMessages: priorMessages,
        userInput: userInput,
      )) {
        yield event;
      }
      return;
    } catch (error) {
      final canDowngrade =
          mode == AiToolCallMode.auto &&
          initialProtocol == _AgentProtocol.native &&
          error is AiException &&
          error.code == AiErrorCode.protocolUnsupported;
      if (!canDowngrade) {
        yield AiAgentFailed(error);
        return;
      }
    }

    yield const AiAgentRetrying(attempt: 1, reason: 'protocolFallback');
    try {
      await for (final event in _runProtocol(
        protocol: _AgentProtocol.prompt,
        streamTransport: streamTransport,
        completeTransport: completeTransport,
        context: context,
        priorMessages: priorMessages,
        userInput: userInput,
      )) {
        yield event;
      }
    } catch (error) {
      yield AiAgentFailed(error);
    }
  }

  Stream<AiAgentEvent> _runProtocol({
    required _AgentProtocol protocol,
    required AiAgentStreamTransport streamTransport,
    required AiAgentCompleteTransport? completeTransport,
    required AiToolContext context,
    required List<AiTextMessage> priorMessages,
    required String userInput,
  }) async* {
    final nativeDefinitions = protocol == _AgentProtocol.native
        ? tools.map((tool) => tool.toNativeDefinition()).toList(growable: false)
        : const <Map<String, Object?>>[];
    final systemPrompt = protocol == _AgentProtocol.native
        ? buildAgentSystemPrompt(context)
        : buildPromptAgentSystemPrompt(context, tools);
    final messages = <AiAgentMessage>[
      AiTextMessage.system(systemPrompt),
      ..._boundedPrior(priorMessages),
      AiTextMessage.user(userInput),
    ];
    var toolCallCount = 0;
    var retryUsed = false;

    for (var round = 0; round <= maxToolRounds; round += 1) {
      AiCompletionResult response;
      try {
        final events = await streamTransport(
          messages,
          nativeDefinitions,
        ).toList();
        response = collectNativeCompletion(events);
      } catch (error) {
        if (completeTransport == null || retryUsed || !_isTransient(error)) {
          rethrow;
        }
        retryUsed = true;
        yield const AiAgentRetrying(attempt: 1, reason: 'network');
        response = await completeTransport(messages, nativeDefinitions);
      }

      if (response.finishReason == AiFinishReason.insufficientSystemResource &&
          completeTransport != null &&
          !retryUsed) {
        retryUsed = true;
        yield const AiAgentRetrying(attempt: 1, reason: 'upstreamResource');
        response = await completeTransport(messages, nativeDefinitions);
      }

      if (protocol == _AgentProtocol.native && response.toolCalls.isNotEmpty) {
        if (round >= maxToolRounds) {
          throw AiException(
            AiErrorCode.badResponse,
            detail: 'tool round limit exceeded',
          );
        }
        messages.add(
          AiAssistantToolMessage(
            content: response.content.isEmpty ? null : response.content,
            reasoningContent: response.reasoningContent.isEmpty
                ? null
                : response.reasoningContent,
            toolCalls: response.toolCalls,
          ),
        );
        for (final call in response.toolCalls) {
          toolCallCount += 1;
          if (toolCallCount > maxToolCalls) {
            throw AiException(
              AiErrorCode.badResponse,
              detail: 'tool call limit exceeded',
            );
          }
          final decodedArguments = call.decodeArguments();
          final arguments = decodedArguments ?? <String, Object?>{};
          yield AiAgentToolStarted(
            stepId: call.id,
            toolName: call.name,
            arguments: arguments,
          );
          final execution = decodedArguments == null
              ? const _ToolExecution.failed(
                  reason: 'invalidArguments',
                  modelMessage: '工具参数不是有效的 JSON 对象，请修正参数后重试。',
                )
              : _execute(call.name, arguments, context);
          if (execution.result == null) {
            yield AiAgentToolFailed(
              stepId: call.id,
              toolName: call.name,
              arguments: arguments,
              reason: execution.failureReason!,
            );
            messages.add(
              AiToolResultMessage(
                toolCallId: call.id,
                content: execution.modelMessage,
              ),
            );
          } else {
            yield AiAgentToolCompleted(
              stepId: call.id,
              toolName: call.name,
              arguments: arguments,
              result: execution.result!,
              duration: execution.duration,
            );
            messages.add(
              AiToolResultMessage(
                toolCallId: call.id,
                content: _truncateSummary(execution.result!.summary),
              ),
            );
          }
        }
        continue;
      }

      if (protocol == _AgentProtocol.prompt) {
        final parsed = parsePromptResponse(
          response.content,
          knownTools: tools.map((tool) => tool.name).toSet(),
        );
        if (parsed is AiPromptToolCall) {
          if (round >= maxToolRounds || ++toolCallCount > maxToolCalls) {
            throw AiException(
              AiErrorCode.badResponse,
              detail: 'tool limit exceeded',
            );
          }
          final stepId = 'prompt-$round-$toolCallCount';
          yield AiAgentToolStarted(
            stepId: stepId,
            toolName: parsed.name,
            arguments: parsed.arguments,
          );
          final execution = _execute(parsed.name, parsed.arguments, context);
          messages.add(AiTextMessage.assistant(response.content));
          if (execution.result == null) {
            yield AiAgentToolFailed(
              stepId: stepId,
              toolName: parsed.name,
              arguments: parsed.arguments,
              reason: execution.failureReason!,
            );
            messages.add(
              AiTextMessage.user(
                'VERIFIN_TOOL_RESULT\n${execution.modelMessage}',
              ),
            );
          } else {
            yield AiAgentToolCompleted(
              stepId: stepId,
              toolName: parsed.name,
              arguments: parsed.arguments,
              result: execution.result!,
              duration: execution.duration,
            );
            messages.add(
              AiTextMessage.user(
                'VERIFIN_TOOL_RESULT\n'
                '${_truncateSummary(execution.result!.summary)}',
              ),
            );
          }
          continue;
        }
        if (parsed is AiPromptAnswer) {
          yield* _answerEvents(parsed.text, response.finishReason);
          return;
        }
      } else {
        yield* _answerEvents(response.content, response.finishReason);
        return;
      }
    }
  }

  Stream<AiAgentEvent> _answerEvents(
    String rawAnswer,
    AiFinishReason finishReason,
  ) async* {
    final answer = rawAnswer.trim();
    if (answer.isEmpty) {
      throw AiException(AiErrorCode.badResponse, detail: 'empty answer');
    }
    if (_containsToolProtocol(answer)) {
      throw AiException(AiErrorCode.badResponse, detail: 'tool protocol leak');
    }
    yield AiAgentAnswerDelta(answer);
    if (finishReason == AiFinishReason.length) {
      yield AiAgentFailed(
        AiException(AiErrorCode.badResponse, detail: 'response truncated'),
        partialAnswer: answer,
      );
      return;
    }
    if (finishReason == AiFinishReason.contentFilter) {
      yield AiAgentFailed(
        AiException(AiErrorCode.upstream, detail: 'content filtered'),
        partialAnswer: answer,
      );
      return;
    }
    yield AiAgentCompleted(answer);
  }

  List<AiTextMessage> _boundedPrior(List<AiTextMessage> priorMessages) {
    final selected = <AiTextMessage>[];
    var characters = 0;
    for (final message in priorMessages.reversed) {
      if (selected.length >= maxPriorMessages) break;
      if (characters + message.content.length > maxPriorCharacters) break;
      selected.insert(0, message);
      characters += message.content.length;
    }
    while (selected.isNotEmpty &&
        selected.first.role == AiMessageRole.assistant) {
      selected.removeAt(0);
    }
    return selected;
  }

  _ToolExecution _execute(
    String toolName,
    Map<String, Object?> arguments,
    AiToolContext context,
  ) {
    final tool = _toolNamed(toolName);
    if (tool == null) {
      return const _ToolExecution.failed(
        reason: 'unknownTool',
        modelMessage: '工具不存在，请选择已提供的工具。',
      );
    }
    if (tool.schema.validate(arguments).isNotEmpty) {
      return const _ToolExecution.failed(
        reason: 'invalidArguments',
        modelMessage: '工具参数无效，请修正参数后重试。',
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final result = tool.run(context, arguments);
      stopwatch.stop();
      return _ToolExecution.succeeded(result, stopwatch.elapsed);
    } catch (_) {
      stopwatch.stop();
      return _ToolExecution.failed(
        reason: 'executionFailed',
        modelMessage: '工具执行失败，请换一种查询方式。',
        duration: stopwatch.elapsed,
      );
    }
  }

  AiQueryTool? _toolNamed(String name) {
    for (final tool in tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }

  String _truncateSummary(String summary) {
    if (summary.length <= maxToolSummaryCharacters) return summary;
    return '${summary.substring(0, maxToolSummaryCharacters)}\n[结果已截断]';
  }
}

enum _AgentProtocol { native, prompt }

class _ToolExecution {
  const _ToolExecution.succeeded(this.result, this.duration)
    : failureReason = null,
      modelMessage = '';

  const _ToolExecution.failed({
    required String reason,
    required this.modelMessage,
    this.duration = Duration.zero,
  }) : result = null,
       failureReason = reason;

  final AiToolResult? result;
  final String? failureReason;
  final String modelMessage;
  final Duration duration;
}

bool _isTransient(Object error) {
  if (error is! AiException) return false;
  return switch (error.code) {
    AiErrorCode.timeout ||
    AiErrorCode.network ||
    AiErrorCode.serverError ||
    AiErrorCode.incompleteStream => true,
    _ => false,
  };
}

bool _containsToolProtocol(String answer) {
  return answer.contains(aiPromptToolMarker) ||
      answer.contains('"tool"') ||
      answer.contains('tool_calls') ||
      answer.contains('reasoning_content');
}
