import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_agent_engine.dart';
import 'package:verifin/app/ai/ai_completion_event.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/ai_chat_page.dart';

import 'support/test_harness.dart';

/// 按调用顺序返回结构化补全事件。
AiAgentStreamTransport _scripted(List<List<AiCompletionEvent>> responses) {
  var index = 0;
  return (messages, tools) async* {
    final events = index < responses.length
        ? responses[index]
        : const <AiCompletionEvent>[];
    index += 1;
    for (final event in events) {
      yield event;
    }
  };
}

List<AiCompletionEvent> _answer(String text) => <AiCompletionEvent>[
  AiContentDelta(text),
  const AiCompletionFinished(AiFinishReason.stop),
  const AiStreamDone(),
];

void main() {
  useTestDatabases();

  testWidgets('未配置 AI 时显示引导按钮', (tester) async {
    final controller = await makeController();
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiChatPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('去配置 AI'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('已配置：发问 → 工具卡片 + 流式答复', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..setAiSettings(
        const AiSettings(baseUrl: 'http://x/v1', apiKey: 'k', model: 'm'),
      )
      ..addEntry(
        LedgerEntry(
          id: 'e1',
          bookId: bookId,
          type: EntryType.expense,
          amount: 300,
          categoryId: 'dining',
          accountId: 'cash',
          note: '',
          occurredAt: DateTime.now(),
        ),
      );

    final transport = _scripted(<List<AiCompletionEvent>>[
      <AiCompletionEvent>[
        const AiToolCallDelta(
          index: 0,
          id: 'call_1',
          name: 'summary',
          arguments: '{"range":"thisMonth"}',
        ),
        const AiCompletionFinished(AiFinishReason.toolCalls),
        const AiStreamDone(),
      ],
      _answer('本月支出合计 300 元。'),
    ]);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: AiChatPage(debugTransport: transport)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '本月花了多少');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // 用户气泡
    expect(find.text('本月花了多少'), findsOneWidget);
    // summary 工具的结果卡（标题含「收支汇总」）
    expect(find.textContaining('收支汇总'), findsWidgets);
    expect(find.text('查询收支汇总'), findsOneWidget);
    expect(find.textContaining('{"tool"'), findsNothing);
    // 统计卡里的净额/支出行
    expect(find.text('支出'), findsWidgets);
    controller.dispose();
  });

  testWidgets('清空聊天记录', (tester) async {
    final controller = await makeController()
      ..setAiSettings(
        const AiSettings(baseUrl: 'http://x/v1', apiKey: 'k', model: 'm'),
      );
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: AiChatPage(
            debugTransport: _scripted(<List<AiCompletionEvent>>[
              _answer('你好呀'),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '在吗');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('在吗'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('在吗'), findsNothing);
    controller.dispose();
  });

  testWidgets('网络错误保留友好文案并提供重新回答', (tester) async {
    final controller = await makeController()
      ..setAiSettings(
        const AiSettings(baseUrl: 'http://x/v1', apiKey: 'k', model: 'm'),
      );
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: AiChatPage(
            debugTransport: (messages, tools) async* {
              throw AiException(
                AiErrorCode.network,
                detail: 'HttpException: secret upstream detail',
              );
            },
            debugCompleteTransport: (messages, tools) async {
              throw AiException(
                AiErrorCode.network,
                detail: 'HttpException: secret upstream detail',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '帮我查一下');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('无法连接到服务器'), findsOneWidget);
    expect(find.text('重新回答'), findsOneWidget);
    expect(find.textContaining('HttpException'), findsNothing);
    expect(find.textContaining('secret upstream'), findsNothing);
    controller.dispose();
  });

  testWidgets('重开时从历史还原结果卡片（图表不再丢失）', (tester) async {
    final controller = await makeController()
      ..setAiSettings(
        const AiSettings(baseUrl: 'http://x/v1', apiKey: 'k', model: 'm'),
      )
      ..setAiChatHistory(<Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': '分类排行'},
        <String, Object?>{
          'role': 'assistant',
          'content': '这是排行',
          'displays': <Map<String, Object?>>[
            <String, Object?>{
              'kind': 'ranking',
              'title': '本月 · 支出分类排行',
              'rows': <Map<String, Object?>>[
                <String, Object?>{
                  'label': '餐饮',
                  'amount': 400,
                  'percent': 0.8,
                  'count': 3,
                },
              ],
            },
          ],
          'steps': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'call_1',
              'tool': 'categoryRanking',
              'status': 'succeeded',
              'args': <String, Object?>{
                'range': 'thisMonth',
                'type': 'expense',
              },
              'summary': '得到 1 项结果',
            },
          ],
        },
      ]);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiChatPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 历史文字与还原的结果卡片都在。
    expect(find.text('分类排行'), findsOneWidget);
    expect(find.textContaining('支出分类排行'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('查询分类排行'), findsOneWidget);
    controller.dispose();
  });
}
