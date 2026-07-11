import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_chat_engine.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/ai_chat_page.dart';

import 'support/test_harness.dart';

/// 按调用顺序返回脚本响应、切片模拟流式的假传输。
AiChatTransport _scripted(List<String> responses) {
  var index = 0;
  return (messages) async* {
    final text = index < responses.length ? responses[index] : '';
    index += 1;
    for (var i = 0; i < text.length; i += 6) {
      yield text.substring(i, (i + 6).clamp(0, text.length));
    }
  };
}

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

    final transport = _scripted(<String>[
      '{"tool":"summary","args":{"range":"thisMonth"}}',
      '本月支出合计 300 元。',
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
    expect(find.textContaining('收支汇总'), findsOneWidget);
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
          home: AiChatPage(debugTransport: _scripted(<String>['你好呀'])),
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
    controller.dispose();
  });
}
