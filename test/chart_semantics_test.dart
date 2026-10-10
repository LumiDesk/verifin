import 'package:fl_chart/fl_chart.dart';
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

  testWidgets('折线图只画曲线，不画节点圆点', (tester) async {
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
                yLabels: const <String>['0', '2', '4'],
                tooltipOf: tooltipOf,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.dotData.show, isFalse);
    expect(chart.data.lineBarsData.single.isCurved, isTrue);
  });

  testWidgets('组合图预算点与柱子中心同列，点按选中对应槽位', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 160,
              child: InteractiveComboChart(
                barValues: const <double>[1, 2, 3],
                lineValues: const <double>[3, 3, 3],
                xLabels: const <String>['a', 'b', 'c'],
                yLabels: const <String>['0', '2', '4'],
                barColor: const Color(0xFFC2334F),
                lineColor: const Color(0xFF346EDB),
                tooltipOf: tooltipOf,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // BarChartAlignment.spaceAround 把第 i 根柱子放在 (i + 0.5) / count 处；
    // 折线必须用同一套坐标，否则预算点会整体偏到柱子左侧。
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.minX, 0);
    expect(lineChart.data.maxX, 3);
    expect(
      lineChart.data.lineBarsData.single.spots.map((spot) => spot.x).toList(),
      <double>[0.5, 1.5, 2.5],
    );

    // 点按图表水平中心落在中间槽位上：气泡内容对应该槽位。
    await tester.tapAt(tester.getCenter(find.byType(InteractiveComboChart)));
    await tester.pumpAndSettle();
    expect(find.text('第 1 天'), findsOneWidget);
  });
}
