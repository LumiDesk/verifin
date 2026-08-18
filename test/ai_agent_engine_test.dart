import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_agent_engine.dart';
import 'package:verifin/app/ai/ai_agent_event.dart';
import 'package:verifin/app/ai/ai_agent_message.dart';
import 'package:verifin/app/ai/ai_completion_event.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_query_tool.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';

AiToolContext _context() {
  return AiToolContext(
    entries: <LedgerEntry>[
      LedgerEntry(
        id: 'e1',
        bookId: 'b',
        type: EntryType.expense,
        amount: 300,
        categoryId: 'food',
        accountId: 'acc',
        note: '午餐',
        occurredAt: DateTime(2026, 6, 10),
      ),
    ],
    accounts: const <Account>[],
    categories: const <Category>[],
    tags: const <Tag>[],
    balanceOf: (_) => 0,
    baseCurrencyCode: 'CNY',
    now: DateTime(2026, 6, 20),
  );
}

class _ScriptedTransport {
  _ScriptedTransport(this.rounds);

  final List<Object> rounds;
  final List<List<AiAgentMessage>> messages = <List<AiAgentMessage>>[];
  final List<List<Map<String, Object?>>> toolDefinitions =
      <List<Map<String, Object?>>>[];
  var _index = 0;

  Stream<AiCompletionEvent> stream(
    List<AiAgentMessage> requestMessages,
    List<Map<String, Object?>> tools,
  ) async* {
    messages.add(List<AiAgentMessage>.from(requestMessages));
    toolDefinitions.add(List<Map<String, Object?>>.from(tools));
    final round = rounds[_index++];
    if (round is List<AiCompletionEvent>) {
      for (final event in round) {
        yield event;
      }
      return;
    }
    throw round;
  }
}

List<AiCompletionEvent> _answer(String text) => <AiCompletionEvent>[
  AiContentDelta(text),
  const AiCompletionFinished(AiFinishReason.stop),
  const AiStreamDone(),
];

Future<List<AiAgentEvent>> _run(
  AiAgentEngine engine,
  _ScriptedTransport transport, {
  AiToolCallMode mode = AiToolCallMode.native,
  AiAgentCompleteTransport? completeTransport,
  List<AiTextMessage> priorMessages = const <AiTextMessage>[],
}) {
  return engine
      .run(
        mode: mode,
        streamTransport: transport.stream,
        completeTransport: completeTransport,
        context: _context(),
        priorMessages: priorMessages,
        userInput: '本月花了多少',
      )
      .toList();
}

void main() {
  final engine = AiAgentEngine(tools: buildAiQueryTools());

  test(
    'native protocol assembles fragmented calls and executes sequentially',
    () async {
      final transport = _ScriptedTransport(<Object>[
        <AiCompletionEvent>[
          const AiReasoningDelta('private reasoning'),
          const AiToolCallDelta(
            index: 0,
            id: 'call_1',
            name: 'sum',
            arguments: '{"range":',
          ),
          const AiToolCallDelta(
            index: 0,
            name: 'mary',
            arguments: '"thisMonth"}',
          ),
          const AiToolCallDelta(
            index: 1,
            id: 'call_2',
            name: 'largestTransactions',
            arguments: '{"range":"thisMonth","limit":1}',
          ),
          const AiCompletionFinished(AiFinishReason.toolCalls),
          const AiStreamDone(),
        ],
        _answer('本月支出 300 元，最大一笔也是 300 元。'),
      ]);

      final events = await _run(engine, transport);

      expect(events.whereType<AiAgentToolStarted>(), hasLength(2));
      expect(events.whereType<AiAgentToolCompleted>(), hasLength(2));
      expect(events.whereType<AiAgentToolFailed>(), isEmpty);
      expect(
        events.whereType<AiAgentCompleted>().single.answer,
        '本月支出 300 元，最大一笔也是 300 元。',
      );
      expect(
        events.whereType<AiAgentAnswerDelta>().single.text,
        isNot(contains('private reasoning')),
      );
      expect(transport.toolDefinitions.first, hasLength(5));
      final secondRound = transport.messages[1];
      expect(secondRound.whereType<AiAssistantToolMessage>(), hasLength(1));
      expect(secondRound.whereType<AiToolResultMessage>(), hasLength(2));
    },
  );

  test('prompt protocol consumes noisy tool JSON without leaking it', () async {
    const rawTool =
        '<think>需要查询</think>\n'
        '我先看一下。\n'
        '{"tool":"summary","args":{"range":"thisMonth"}}';
    final transport = _ScriptedTransport(<Object>[
      <AiCompletionEvent>[
        const AiContentDelta(rawTool),
        const AiCompletionFinished(AiFinishReason.stop),
        const AiStreamDone(),
      ],
      _answer('VERIFIN_ANSWER\n本月支出 300 元。'),
    ]);

    final events = await _run(engine, transport, mode: AiToolCallMode.prompt);

    expect(events.whereType<AiAgentToolCompleted>(), hasLength(1));
    expect(events.whereType<AiAgentCompleted>().single.answer, '本月支出 300 元。');
    final visible = events
        .whereType<AiAgentAnswerDelta>()
        .map((event) => event.text)
        .join();
    expect(visible, isNot(contains('{"tool"')));
    expect(visible, isNot(contains('<think>')));
    expect(transport.toolDefinitions.every((tools) => tools.isEmpty), isTrue);
  });

  test(
    'auto mode falls back only after explicit native protocol rejection',
    () async {
      final transport = _ScriptedTransport(<Object>[
        AiException(AiErrorCode.protocolUnsupported),
        _answer('VERIFIN_ANSWER\n兼容模式回答。'),
      ]);

      final events = await _run(engine, transport, mode: AiToolCallMode.auto);

      expect(
        events.whereType<AiAgentRetrying>().single.reason,
        'protocolFallback',
      );
      expect(events.whereType<AiAgentCompleted>().single.answer, '兼容模式回答。');
      expect(transport.toolDefinitions[0], isNotEmpty);
      expect(transport.toolDefinitions[1], isEmpty);
    },
  );

  test('forced native mode does not silently downgrade', () async {
    final transport = _ScriptedTransport(<Object>[
      AiException(AiErrorCode.protocolUnsupported),
    ]);

    final events = await _run(engine, transport);

    expect(events.whereType<AiAgentRetrying>(), isEmpty);
    final error = events.whereType<AiAgentFailed>().single.error as AiException;
    expect(error.code, AiErrorCode.protocolUnsupported);
    expect(transport.messages, hasLength(1));
  });

  test(
    'transient stream failure retries once with non-stream transport',
    () async {
      final transport = _ScriptedTransport(<Object>[
        AiException(AiErrorCode.network),
      ]);
      var completeCalls = 0;

      final events = await _run(
        engine,
        transport,
        completeTransport: (messages, tools) async {
          completeCalls += 1;
          return const AiCompletionResult(
            content: '重试成功。',
            finishReason: AiFinishReason.stop,
          );
        },
      );

      expect(events.whereType<AiAgentRetrying>().single.reason, 'network');
      expect(events.whereType<AiAgentCompleted>().single.answer, '重试成功。');
      expect(completeCalls, 1);
    },
  );

  test(
    'malformed compatibility control fails without visible raw JSON',
    () async {
      final transport = _ScriptedTransport(<Object>[
        _answer('VERIFIN_TOOL\n{"tool":"summary","args":{'),
      ]);

      final events = await _run(engine, transport, mode: AiToolCallMode.prompt);

      expect(events.whereType<AiAgentAnswerDelta>(), isEmpty);
      expect(events.whereType<AiAgentCompleted>(), isEmpty);
      expect(events.whereType<AiAgentFailed>(), hasLength(1));
    },
  );

  test('prior visible messages are bounded before transport', () async {
    final transport = _ScriptedTransport(<Object>[_answer('回答。')]);
    final prior = <AiTextMessage>[
      for (var index = 0; index < 20; index += 1)
        index.isEven
            ? AiTextMessage.user('user-$index')
            : AiTextMessage.assistant('assistant-$index'),
    ];

    await _run(engine, transport, priorMessages: prior);

    // system + at most 12 prior messages + current user question。
    expect(transport.messages.single.length, lessThanOrEqualTo(14));
    expect(transport.messages.single.first.role, AiMessageRole.system);
    expect(transport.messages.single.last.role, AiMessageRole.user);
  });
}
