// AI 对话查询的多轮对话主循环（纯 Dart，不依赖 dart:io，便于单测）。
//
// 走「提示词工具协议」：系统提示词列出只读工具，模型需要数据时回一个
// `{"tool":..,"args":..}` JSON，本地执行 [AiQueryTool] 后把结果回喂，循环直到模型给出
// 最终 Markdown 答复或达到轮次上限。
//
// 网络传输经 [AiChatTransport] 注入——生产传 `aiChatStream`（SSE），测试传假实现，
// 引擎本身与平台无关。事件流 [AiChatEvent] 驱动聊天页 UI（工具卡片 + 流式答复）。
import 'ai_entry_parser.dart' show extractJsonObject;
import 'ai_query_tool.dart';

/// 注入的流式传输：给定模型消息列表，返回文本增量流。
typedef AiChatTransport =
    Stream<String> Function(List<Map<String, String>> messages);

/// 对话过程中产生的事件。
sealed class AiChatEvent {
  const AiChatEvent();
}

/// 模型决定调用某工具（用于展示「正在查询…」状态）。
class AiChatToolInvoked extends AiChatEvent {
  const AiChatToolInvoked(this.toolName);
  final String toolName;
}

/// 一次工具调用产出的可渲染结果（图表 / 列表 / 卡片）。
class AiChatToolDisplay extends AiChatEvent {
  const AiChatToolDisplay(this.display);
  final AiResultDisplay display;
}

/// 最终答复的文本增量（流式，逐段追加到气泡）。
class AiChatAnswerDelta extends AiChatEvent {
  const AiChatAnswerDelta(this.delta);
  final String delta;
}

/// 本轮回答完成，携带完整答复文本（供落库历史）。
class AiChatCompleted extends AiChatEvent {
  const AiChatCompleted(this.answer);
  final String answer;
}

/// 出错（[error] 通常为 AiException）。
class AiChatFailed extends AiChatEvent {
  const AiChatFailed(this.error);
  final Object error;
}

/// 解析出的一次工具调用。
class _ToolCall {
  const _ToolCall(this.name, this.args);
  final String name;
  final Map<String, Object?> args;
}

/// 对话引擎。无状态，可复用同一实例处理多轮对话。
class AiChatEngine {
  const AiChatEngine({required this.tools, this.maxToolRounds = 5});

  /// 可用的只读工具（见 [buildAiQueryTools]）。
  final List<AiQueryTool> tools;

  /// 一次用户提问内最多允许的工具调用轮次，防止模型打转烧 token。
  final int maxToolRounds;

  /// 处理一次用户提问，产出事件流。
  ///
  /// [priorMessages] 为此前的用户/助手可见对话（不含工具内部消息），用于多轮上下文；
  /// [userInput] 为本次用户输入。工具调用的 assistant/tool 内部消息只在本方法内临时拼接，
  /// 不回传给调用方，保持历史干净。
  Stream<AiChatEvent> run({
    required AiChatTransport transport,
    required AiToolContext context,
    required List<Map<String, String>> priorMessages,
    required String userInput,
  }) async* {
    final messages = <Map<String, String>>[
      <String, String>{'role': 'system', 'content': buildSystemPrompt(context)},
      ...priorMessages,
      <String, String>{'role': 'user', 'content': userInput},
    ];

    for (var round = 0; ; round += 1) {
      final lastRound = round >= maxToolRounds;
      if (lastRound) {
        messages.add(<String, String>{
          'role': 'user',
          'content': '请直接用中文给出最终答复，不要再调用工具。',
        });
      }

      // 逐段读取本轮响应；用首个非空白字符判定这轮是「工具调用」还是「最终答复」：
      // 工具调用被要求只输出 JSON（以 `{` 或 ``` 开头），其余按最终答复流式呈现。
      final buffer = StringBuffer();
      final answer = StringBuffer();
      var mode = _RoundMode.undecided;
      try {
        await for (final delta in transport(messages)) {
          if (mode == _RoundMode.answer) {
            answer.write(delta);
            yield AiChatAnswerDelta(delta);
            continue;
          }
          buffer.write(delta);
          if (mode == _RoundMode.undecided) {
            final trimmed = buffer.toString().trimLeft();
            if (trimmed.isEmpty) {
              continue;
            }
            final first = trimmed[0];
            if (first == '{' || first == '`') {
              mode = _RoundMode.tool;
            } else {
              mode = _RoundMode.answer;
              answer.write(trimmed);
              yield AiChatAnswerDelta(trimmed);
            }
          }
        }
      } catch (error) {
        yield AiChatFailed(error);
        return;
      }

      if (mode != _RoundMode.tool) {
        yield AiChatCompleted(answer.toString().trim());
        return;
      }

      // 工具调用分支：解析并执行；解析失败则把内容当作答复兜底。
      final raw = buffer.toString();
      final call = _parseToolCall(raw);
      if (call == null || lastRound) {
        yield AiChatAnswerDelta(raw);
        yield AiChatCompleted(raw.trim());
        return;
      }
      final tool = _toolNamed(call.name);
      if (tool == null) {
        messages.add(<String, String>{'role': 'assistant', 'content': raw});
        messages.add(<String, String>{
          'role': 'user',
          'content': '不存在名为 ${call.name} 的工具，请从可用工具中选择。',
        });
        continue;
      }

      yield AiChatToolInvoked(tool.name);
      final AiToolResult result;
      try {
        result = tool.run(context, call.args);
      } catch (error) {
        messages.add(<String, String>{'role': 'assistant', 'content': raw});
        messages.add(<String, String>{
          'role': 'user',
          'content': '工具 ${tool.name} 执行出错：$error。请换个方式或直接回答。',
        });
        continue;
      }
      if (result.display != null) {
        yield AiChatToolDisplay(result.display!);
      }
      messages.add(<String, String>{'role': 'assistant', 'content': raw});
      messages.add(<String, String>{
        'role': 'user',
        'content': '工具 ${tool.name} 返回：${result.summary}',
      });
    }
  }

  AiQueryTool? _toolNamed(String name) {
    for (final tool in tools) {
      if (tool.name == name) {
        return tool;
      }
    }
    return null;
  }

  _ToolCall? _parseToolCall(String raw) {
    final json = extractJsonObject(raw);
    if (json == null) {
      return null;
    }
    final name = json['tool'];
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    final args = json['args'];
    return _ToolCall(
      name.trim(),
      args is Map ? Map<String, Object?>.from(args) : <String, Object?>{},
    );
  }

  /// 组装系统提示词：角色、工具协议、可用工具清单与参数。
  String buildSystemPrompt(AiToolContext context) {
    final now = context.now;
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final toolLines = tools
        .map((t) {
          final args = t.schema.promptDescription;
          return '- ${t.name}：${t.description}${args.isEmpty ? '' : ' 参数：$args'}';
        })
        .join('\n');
    return '''
你是记账 App「Veri Fin」的账目分析助手。用户会用自然语言询问自己的账目，你必须通过调用工具查询真实数据后作答，不得编造任何数字。

工作方式：
- 需要数据时，只输出一个 JSON，形如 {"tool":"工具名","args":{参数}}，可放在 ```json 代码块里，且这一轮不要输出任何其它文字。
- 你会收到「工具 X 返回：…」的结果，可据此再调用其它工具，或给出最终答复。
- 最终答复用简洁中文 Markdown（可用表格、列表、加粗）。图表与明细列表已由 App 自动展示在你的消息里，你只需做解读与结论，不必逐条罗列大量数字。
- 数据范围仅限用户当前账本；金额单位为元；今天是 $today。

可用工具：
$toolLines''';
  }
}

enum _RoundMode { undecided, tool, answer }
