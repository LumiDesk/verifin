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

  testWidgets('双柱图每个插槽两根柱子，横向拖过空白处也能选中最近插槽并保持', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 160,
              child: InteractiveBarChart(
                // 第 3 个月支出为 0：矩形命中永远点不中零值柱，
                // 必须靠插槽命中才能查看这个月的数据。
                series: const <VeriBarSeries>[
                  VeriBarSeries(
                    values: <double>[3, 3, 3],
                    color: Color(0xFF346EDB),
                  ),
                  VeriBarSeries(
                    values: <double>[2, 1, 0],
                    color: Color(0xFFC2334F),
                  ),
                ],
                xLabels: const <String>['1', '2', '3'],
                yLabels: const <String>['0', '2', '4'],
                tooltipOf: tooltipOf,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
    int? pressedGroup() {
      for (final group in chart().data.barGroups) {
        if (group.showingTooltipIndicators.isNotEmpty) {
          return group.x;
        }
      }
      return null;
    }

    expect(chart().data.barGroups.first.barRods.length, 2);
    expect(pressedGroup(), isNull);

    // 从最右侧（第 3 个月那一列的空白处）开始横向拖动：仍要选中第 3 个插槽。
    final gesture = await tester.startGesture(
      tester.getTopRight(find.byType(InteractiveBarChart)) -
          const Offset(4, 0) +
          const Offset(0, 80),
    );
    await tester.pump();
    // 只按下不动不会选中任何插槽（竖向拖动要留给页面滚动）。
    expect(pressedGroup(), isNull);
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    expect(pressedGroup(), 2);

    // 横向拖动到最左侧：连续跟随下一个插槽。
    await gesture.moveBy(const Offset(-280, 0));
    await tester.pump();
    expect(pressedGroup(), 0);

    // 松手保留最后一次选中，抬手后仍能读数。
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressedGroup(), 0);
  });

  testWidgets('柱状图放在可跳转卡片里时，点图表不触发卡片跳转', (tester) async {
    var cardTaps = 0;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 160,
              child: GestureDetector(
                onTap: () => cardTaps++,
                child: InteractiveBarChart(
                  values: const <double>[1, 2, 3],
                  xLabels: const <String>['1', '2', '3'],
                  yLabels: const <String>['0', '2', '4'],
                  tooltipOf: tooltipOf,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(InteractiveBarChart)));
    await tester.pumpAndSettle();
    expect(cardTaps, 0);
  });
}
