import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_chat_engine.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_query_tool.dart';
import 'package:verifin/app/models.dart';

/// 把每条脚本响应切成小片模拟流式；按调用顺序依次返回。
AiChatTransport _scripted(List<String> responses) {
  var index = 0;
  return (messages) async* {
    final text = index < responses.length ? responses[index] : '';
    index += 1;
    for (var i = 0; i < text.length; i += 4) {
      yield text.substring(i, (i + 4).clamp(0, text.length));
    }
  };
}

AiChatTransport _throwing(Object error) {
  return (messages) async* {
    throw error;
  };
}

AiToolContext _ctx() {
  final entries = <LedgerEntry>[
    LedgerEntry(
      id: 'e1',
      bookId: 'b',
      type: EntryType.expense,
      amount: 300,
      categoryId: 'food',
      accountId: 'acc',
      note: '',
      occurredAt: DateTime(2026, 6, 10),
    ),
  ];
  return AiToolContext(
    entries: entries,
    accounts: const <Account>[],
    categories: const <Category>[],
    tags: const <Tag>[],
    balanceOf: (_) => 0,
    now: DateTime(2026, 6, 20),
  );
}

Future<List<AiChatEvent>> _collect(Stream<AiChatEvent> stream) =>
    stream.toList();

void main() {
  final engine = AiChatEngine(tools: buildAiQueryTools(), maxToolRounds: 3);

  test('无工具的直接答复：流式增量 + 完成，无工具事件', () async {
    final events = await _collect(
      engine.run(
        transport: _scripted(<String>['你好，有什么可以帮你的？']),
        context: _ctx(),
        priorMessages: const <Map<String, String>>[],
        userInput: '在吗',
      ),
    );
    expect(events.whereType<AiChatToolInvoked>(), isEmpty);
    expect(events.whereType<AiChatAnswerDelta>(), isNotEmpty);
    final completed = events.whereType<AiChatCompleted>().single;
    expect(completed.answer, '你好，有什么可以帮你的？');
  });

  test('一次工具调用后作答：工具卡片 + 答复', () async {
    final events = await _collect(
      engine.run(
        transport: _scripted(<String>[
          '```json\n{"tool":"summary","args":{"range":"thisMonth"}}\n```',
          '本月支出 300 元。',
        ]),
        context: _ctx(),
        priorMessages: const <Map<String, String>>[],
        userInput: '本月花了多少',
      ),
    );
    final invoked = events.whereType<AiChatToolInvoked>().single;
    expect(invoked.toolName, 'summary');
    final display = events.whereType<AiChatToolDisplay>().single.display;
    expect(display, isA<AiStatDisplay>());
    final stat = display as AiStatDisplay;
    expect(stat.items.firstWhere((i) => i.label == '支出').value, 300);
    expect(events.whereType<AiChatCompleted>().single.answer, '本月支出 300 元。');
  });

  test('未知工具不崩溃，引擎提示后继续直至完成', () async {
    final events = await _collect(
      engine.run(
        transport: _scripted(<String>[
          '{"tool":"nope","args":{}}',
          '抱歉，我换个方式：这是结果。',
        ]),
        context: _ctx(),
        priorMessages: const <Map<String, String>>[],
        userInput: '随便问问',
      ),
    );
    expect(events.whereType<AiChatToolInvoked>(), isEmpty);
    expect(events.whereType<AiChatCompleted>().single.answer, '抱歉，我换个方式：这是结果。');
  });

  test('工具轮次超上限也会终止（不无限循环）', () async {
    final loopEngine = AiChatEngine(
      tools: buildAiQueryTools(),
      maxToolRounds: 2,
    );
    final events = await _collect(
      loopEngine.run(
        // 每轮都回工具调用，永不作答。
        transport: (messages) async* {
          yield '{"tool":"summary","args":{"range":"thisMonth"}}';
        },
        context: _ctx(),
        priorMessages: const <Map<String, String>>[],
        userInput: '死循环测试',
      ),
    );
    expect(events.whereType<AiChatCompleted>().length, 1);
  });

  test('传输出错产出 AiChatFailed', () async {
    final events = await _collect(
      engine.run(
        transport: _throwing(AiException(AiErrorCode.network)),
        context: _ctx(),
        priorMessages: const <Map<String, String>>[],
        userInput: '断网了',
      ),
    );
    final failed = events.whereType<AiChatFailed>().single;
    expect(failed.error, isA<AiException>());
    expect(events.whereType<AiChatCompleted>(), isEmpty);
  });

  test('系统提示词包含所有工具名与当前日期', () {
    final prompt = engine.buildSystemPrompt(_ctx());
    for (final tool in buildAiQueryTools()) {
      expect(prompt, contains(tool.name));
    }
    expect(prompt, contains('2026-06-20'));
  });
}
