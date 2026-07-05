import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('settings shows FAB action and AI settings rows', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('记一笔按钮'), 120);
    expect(find.text('记一笔按钮'), findsOneWidget);
    // 默认手动记账。
    expect(find.text('手动记账'), findsOneWidget);
    expect(find.text('AI 记账设置'), findsOneWidget);
    expect(find.text('未配置'), findsOneWidget);
  });

  testWidgets('switching FAB action to AI persists', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('记一笔按钮'), 120);
    await tester.tap(find.text('记一笔按钮'));
    await tester.pumpAndSettle();
    expect(find.text('记一笔按钮行为'), findsOneWidget);
    await tester.tap(find.text('AI 记账').last);
    await tester.pumpAndSettle();

    expect(store.read('verifin.fab_action.v1'), 'ai');
  });

  testWidgets('AI FAB mode prompts to configure when unconfigured', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    store.write('verifin.fab_action.v1', 'ai');
    await pumpApp(tester, store);

    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();

    expect(find.text('尚未配置 AI'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);

    // 「去设置」进入 AI 设置页。
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);
  });
}
