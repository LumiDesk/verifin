import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_query_tool.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('聊天记录落库并在重启后恢复', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setAiChatHistory(<Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': '本月花了多少'},
      <String, Object?>{'role': 'assistant', 'content': '本月支出 300 元'},
    ]);
    controller.dispose();

    // 同一 store 重新载入（模拟重启）。
    final reopened = await makeController(store);
    expect(reopened.aiChatHistory.length, 2);
    expect(reopened.aiChatHistory.first['content'], '本月花了多少');
    expect(reopened.aiChatHistory.last['role'], 'assistant');
    reopened.dispose();
  });

  test('结果卡片（displays）随历史落库并在重启后还原', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    const display = AiRankingDisplay(
      title: '本月 · 支出分类排行',
      rows: <AiRankingRow>[
        AiRankingRow(label: '餐饮', amount: 400, percent: 0.8, count: 3),
      ],
    );
    controller.setAiChatHistory(<Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': '分类排行'},
      <String, Object?>{
        'role': 'assistant',
        'content': '给你排行',
        'displays': <Map<String, Object?>>[display.toJson()],
      },
    ]);
    controller.dispose();

    final reopened = await makeController(store);
    final saved = reopened.aiChatHistory.last;
    final displays = saved['displays']! as List;
    final restored = aiResultDisplayFromJson(
      Map<String, Object?>.from(displays.first as Map),
    );
    expect(restored, isA<AiRankingDisplay>());
    expect((restored! as AiRankingDisplay).rows.first.label, '餐饮');
    expect((restored as AiRankingDisplay).rows.first.amount, 400);
    reopened.dispose();
  });

  test('清空聊天记录', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setAiChatHistory(<Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': 'hi'},
    ]);
    controller.clearAiChatHistory();
    expect(controller.aiChatHistory, isEmpty);

    final reopened = await makeController(store);
    expect(reopened.aiChatHistory, isEmpty);
    controller.dispose();
    reopened.dispose();
  });

  test('初始化数据保留聊天记录（设备本地、不随数据清除）', () async {
    final controller = await makeController();
    controller.setAiChatHistory(<Map<String, Object?>>[
      <String, Object?>{'role': 'user', 'content': '记得我'},
    ]);
    controller.resetAllData();
    expect(controller.aiChatHistory.length, 1);
    expect(controller.aiChatHistory.first['content'], '记得我');
    controller.dispose();
  });
}
