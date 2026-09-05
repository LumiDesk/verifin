import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('我的页宫格展示功能入口并可进入统计分析', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tapBottomTab(tester, 3);

    // 宫格分组标题与主要入口。
    expect(find.text('记账管理'), findsOneWidget);
    expect(find.text('数据与工具'), findsOneWidget);
    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('周期记账'), findsOneWidget);
    expect(find.byType(GridView), findsNWidgets(2));
    expect(find.textContaining('Web 开发预览'), findsNothing);

    final scrollable = firstVerticalScrollable();
    await tester.scrollUntilVisible(
      find.text('统计分析'),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.text('统计分析'));
    await tester.pumpAndSettle();

    // 统计分析页头部标题（与磁贴同名，故断言收支概览确认已进入页面）。
    expect(find.text('收支概览'), findsOneWidget);
  });
}
