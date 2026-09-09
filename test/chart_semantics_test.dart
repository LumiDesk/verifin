import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';

import 'support/test_harness.dart';

void main() {
  ChartTooltip tooltipOf(int index) => ChartTooltip(
    title: '第 $index 天',
    lines: const <ChartTooltipLine>[ChartTooltipLine(text: '¥1')],
  );

  testWidgets('未选中数据点时折线图给出整图无障碍摘要', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 160,
              child: InteractiveTrendChart(
                color: const Color(0xFFC2334F),
                values: const <double>[1, 3, 2],
                tooltipOf: tooltipOf,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 屏幕阅读器至少要能听到「这是一张有几个点的图」，而不是一个无标签的图形。
    expect(find.bySemanticsLabel(RegExp('3 个数据点')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('未选中柱子时柱状图给出整图无障碍摘要', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 160,
              child: InteractiveBarChart(
                values: const <double>[1, 3, 2],
                tooltipOf: tooltipOf,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('3 个数据项')), findsOneWidget);
    handle.dispose();
  });
}
