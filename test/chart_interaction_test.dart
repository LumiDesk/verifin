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

  Widget lineChart({List<double> values = const <double>[1, 3, 2]}) {
    return InteractiveTrendChart(
      color: const Color(0xFFC2334F),
      values: values,
      xLabels: const <String>['1', '2', '3'],
      yLabels: const <String>['0', '2', '4'],
      tooltipOf: tooltipOf,
    );
  }

  Widget barChart() {
    return InteractiveBarChart(
      values: const <double>[1, 2, 3],
      xLabels: const <String>['1', '2', '3'],
      yLabels: const <String>['0', '2', '4'],
      tooltipOf: tooltipOf,
    );
  }

  List<ShowingTooltipIndicators> lineTooltips(WidgetTester tester) {
    return tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .showingTooltipIndicators;
  }

  int? selectedLineIndex(WidgetTester tester) {
    final indicators = lineTooltips(tester);
    if (indicators.isEmpty || indicators.first.showingSpots.isEmpty) {
      return null;
    }
    return indicators.first.showingSpots.first.spotIndex;
  }

  /// 柱状图当前展示气泡的插槽下标。
  int? selectedBarGroup(WidgetTester tester) {
    for (final group
        in tester.widget<BarChart>(find.byType(BarChart)).data.barGroups) {
      if (group.showingTooltipIndicators.isNotEmpty) {
        return group.x;
      }
    }
    return null;
  }

  Future<void> pumpChart(WidgetTester tester, Widget chart) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, height: 160, child: chart)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('折线图点一下固定显示气泡，再点同一个点收起，点别的点移动', (tester) async {
    await pumpChart(tester, lineChart());
    final rect = tester.getRect(find.byType(InteractiveTrendChart));

    // 中间那个数据点：绘图区从 24dp 的纵轴预留之后开始，取第 2 个点。
    final second = Offset(
      rect.left + 24 + (rect.width - 24) * 0.5,
      rect.center.dy,
    );
    await tester.tapAt(second);
    await tester.pumpAndSettle();
    expect(selectedLineIndex(tester), 1);

    // 点同一个点：气泡收起。
    await tester.tapAt(second);
    await tester.pumpAndSettle();
    expect(lineTooltips(tester), isEmpty);

    // 点另一个点：气泡跟着移动，而不是收起。
    await tester.tapAt(second);
    await tester.pumpAndSettle();
    expect(selectedLineIndex(tester), 1);
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    await tester.pumpAndSettle();
    expect(selectedLineIndex(tester), 2);
  });

  testWidgets('柱状图点一下固定显示气泡，再点同一个插槽收起', (tester) async {
    await pumpChart(tester, barChart());
    final rect = tester.getRect(find.byType(InteractiveBarChart));

    // 第一个插槽的中心（24dp 纵轴预留 + 半个插槽）。
    final first = Offset(
      rect.left + 24 + (rect.width - 24) / 6,
      rect.center.dy,
    );
    await tester.tapAt(first);
    await tester.pumpAndSettle();
    expect(selectedBarGroup(tester), 0);

    await tester.tapAt(first);
    await tester.pumpAndSettle();
    expect(selectedBarGroup(tester), isNull);
  });

  testWidgets('点击图表以外的位置会收起气泡', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SizedBox(width: 300, height: 160, child: lineChart()),
              const SizedBox(height: 200),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(InteractiveTrendChart));
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    expect(selectedLineIndex(tester), 1);

    await tester.tapAt(Offset(rect.center.dx, rect.bottom + 80));
    await tester.pumpAndSettle();
    expect(lineTooltips(tester), isEmpty);
  });

  testWidgets('图表放在横向 PageView 里时横向滑动只滑动图表，不切换根页面', (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: PageView(
            controller: controller,
            children: <Widget>[
              Center(
                child: SizedBox(width: 300, height: 160, child: barChart()),
              ),
              const Center(child: Text('第二页')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(InteractiveBarChart), const Offset(-150, 0));
    await tester.pumpAndSettle();

    // 页面停在第一页，横向滑动被图表吃掉并用于查看数据。
    expect(controller.page, moreOrLessEquals(0, epsilon: 0.001));
    expect(selectedBarGroup(tester), 0);
  });

  testWidgets('图表放在竖向列表里时横向滑动不滚页面，竖向滑动仍交给页面', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: <Widget>[
              SizedBox(height: 160, child: barChart()),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(InteractiveBarChart), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(selectedBarGroup(tester), isNotNull);

    // 竖向滑动仍归页面滚动：图表不锁住整块区域的纵向滚动。
    await tester.drag(find.byType(InteractiveBarChart), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
  });
}
