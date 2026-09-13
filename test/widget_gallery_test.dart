import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('desktop widget page is a read-only template gallery', (
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

    expect(find.text('桌面小组件'), findsOneWidget);
    expect(find.text('查看 VeriFin 提供的固定组件样式'), findsOneWidget);
    expect(find.text('我的小组件'), findsNothing);
    expect(find.byTooltip('创建小组件'), findsNothing);
    expect(find.text('保存到我的小组件'), findsNothing);
  });
}
