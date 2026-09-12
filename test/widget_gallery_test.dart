import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('widget gallery lists all widgets and reaches add-to-home', (
    tester,
  ) async {
    await pumpApp(tester);
    // 入口在「我的 → 数据与工具」宫格里。
    await tapBottomTab(tester, 3);
    await tester.scrollUntilVisible(
      find.text('桌面小组件'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('桌面小组件'));
    await tester.pumpAndSettle();

    expect(find.text('我的小组件'), findsOneWidget);
    expect(find.text('还没有保存的小组件'), findsOneWidget);
    expect(find.text('基础模板'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '基于模板创建'), findsWidgets);
  });
}
