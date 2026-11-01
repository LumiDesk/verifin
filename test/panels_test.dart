import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/home_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('manages home panels from the bottom entry', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);

    await tester.scrollUntilVisible(
      find.byKey(const Key('panel_settings_entry_home')),
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('4个首页面板'), findsOneWidget);
    expect(find.byType(CalendarPreview), findsOneWidget);
    expect(find.byType(MoneyUnitLabel), findsWidgets);

    await tester.tap(find.byKey(const Key('panel_settings_entry_home')));
    await tester.pumpAndSettle();

    expect(find.text('首页面板'), findsOneWidget);
    expect(find.text('支出走势'), findsOneWidget);
    expect(find.text('可自定义展示的数据与走势曲线'), findsOneWidget);

    // 开关只改页面草稿。
    await tester.tap(find.byKey(const Key('panel_switch_calendar')));
    await tester.pumpAndSettle();

    // 只剩一个开启面板时继续关闭会被阻止并提示。
    await tester.tap(find.byKey(const Key('panel_switch_recent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panel_switch_budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panel_switch_trend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('至少保留一个开启的首页面板'), findsOneWidget);

    // 恢复日历面板,返回首页验证渲染与数量文案。
    await tester.tap(find.byKey(const Key('panel_switch_calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetPanel), findsNothing);
    // 回到顶部确认支出走势仍然渲染。
    await tester.drag(firstVerticalScrollable(), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTrendPanel), findsOneWidget);
    // 评审外观：走势卡右上角是走势窗口（如「10.1-10.7」），单位角标只留在预算卡等
    // 聚合卡上。
    expect(
      find.descendant(
        of: find.byType(HomeTrendPanel),
        matching: find.byType(MoneyUnitLabel),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('panel_settings_entry_home')),
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('2个首页面板'), findsOneWidget);
    expect(find.byType(CalendarPreview), findsOneWidget);

    // 面板配置持久化:重启后仍然生效。
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, store);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetPanel), findsNothing);
    expect(find.byType(HomeTrendPanel), findsOneWidget);
  });

  testWidgets('reorders report panels in sorting mode', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('panel_settings_entry_reportsMonthly')),
      200,
      scrollable: firstVerticalScrollable(),
    );
    // 看板顶部新增本月摘要卡后入口更靠下，先确保完全进入视口再点击。
    await tester.ensureVisible(
      find.byKey(const Key('panel_settings_entry_reportsMonthly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('5个月统计面板'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('panel_settings_entry_reportsMonthly')),
    );
    await tester.pumpAndSettle();
    expect(find.text('月统计面板'), findsOneWidget);

    // 进入排序模式后出现拖动手柄,拖动第一个面板到第二位。
    await tester.tap(find.byKey(const Key('panel_sort_toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(5));

    final firstHandle = tester.getCenter(
      find.byIcon(Icons.drag_indicator).first,
    );
    final secondHandle = tester.getCenter(
      find.byIcon(Icons.drag_indicator).at(1),
    );
    await tester.timedDragFrom(
      firstHandle,
      Offset(0, secondHandle.dy - firstHandle.dy + 8),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('panel_sort_toggle')));
    await tester.pumpAndSettle();

    final beforeSave = await makeController(store);
    expect(
      beforeSave
          .panelSettings(PanelPageKind.reportsMonthly)
          .map((panel) => panel.id)
          .take(2),
      <String>['summary', 'budget_execution'],
    );
    beforeSave.dispose();

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final controller = await makeController(store);
    expect(
      controller
          .panelSettings(PanelPageKind.reportsMonthly)
          .map((panel) => panel.id)
          .take(2),
      <String>['budget_execution', 'summary'],
    );
    controller.dispose();
  });

  testWidgets('resets panels to defaults after confirmation', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final seed = await makeController(store);
    seed
      ..setPanelEnabled(PanelPageKind.home, 'calendar', false)
      ..reorderPanels(PanelPageKind.home, 0, 2)
      ..dispose();

    await pumpApp(tester, store);
    await tester.scrollUntilVisible(
      find.byKey(const Key('panel_settings_entry_home')),
      200,
      scrollable: firstVerticalScrollable(),
    );
    // 首页空状态插画变高后入口更靠下，先确保完全进入视口再点击。
    await tester.ensureVisible(
      find.byKey(const Key('panel_settings_entry_home')),
    );
    await tester.pumpAndSettle();
    expect(find.text('3个首页面板'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panel_settings_entry_home')));
    await tester.pumpAndSettle();

    // 取消确认弹窗时不重置。
    await tester.tap(find.byKey(const Key('panel_reset')));
    await tester.pumpAndSettle();
    expect(find.text('恢复默认首页面板？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final beforeReset = await makeController(store);
    expect(beforeReset.enabledPanelIds(PanelPageKind.home).length, 3);
    beforeReset.dispose();

    // 确认后只恢复页面草稿。
    await tester.tap(find.byKey(const Key('panel_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();

    final beforeSave = await makeController(store);
    expect(beforeSave.enabledPanelIds(PanelPageKind.home).length, 3);
    beforeSave.dispose();

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    final afterReset = await makeController(store);
    expect(
      afterReset.panelSettings(PanelPageKind.home).map((panel) => panel.id),
      homePanelSpecs.map((spec) => spec.id),
    );
    expect(
      afterReset.enabledPanelIds(PanelPageKind.home).length,
      homePanelSpecs.length,
    );
    afterReset.dispose();
  });

  test('panel settings toggle, keep-one guard, reorder and persist', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);

    expect(controller.enabledPanelIds(PanelPageKind.home), <String>[
      'trend',
      'recent',
      'budget',
      'calendar',
    ]);

    expect(
      controller.setPanelEnabled(PanelPageKind.home, 'calendar', false),
      isTrue,
    );
    controller
      ..setPanelEnabled(PanelPageKind.home, 'recent', false)
      ..setPanelEnabled(PanelPageKind.home, 'budget', false);

    // 最后一个开启的面板不允许关闭。
    expect(
      controller.setPanelEnabled(PanelPageKind.home, 'trend', false),
      isFalse,
    );
    expect(controller.enabledPanelIds(PanelPageKind.home), <String>['trend']);

    controller
      ..reorderPanels(PanelPageKind.reportsMonthly, 0, 2)
      ..dispose();

    final reloaded = await makeController(store);
    expect(reloaded.enabledPanelIds(PanelPageKind.home), <String>['trend']);
    expect(
      reloaded
          .panelSettings(PanelPageKind.reportsMonthly)
          .map((panel) => panel.id)
          .take(3),
      <String>['budget_execution', 'category_stats', 'summary'],
    );

    await reloaded.resetAllData();
    expect(
      reloaded.enabledPanelIds(PanelPageKind.home).length,
      homePanelSpecs.length,
    );
    expect(
      reloaded.enabledPanelIds(PanelPageKind.reportsMonthly).length,
      reportMonthlyPanelSpecs.length,
    );

    reloaded.dispose();
  });

  test('panel settings survive export and import', () async {
    final source = await makeController();
    source
      ..setPanelEnabled(PanelPageKind.home, 'calendar', false)
      ..reorderPanels(PanelPageKind.home, 0, 2);
    final exported = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    await target.importDataJson(exported);

    expect(target.enabledPanelIds(PanelPageKind.home), <String>[
      'recent',
      'budget',
      'trend',
    ]);
    expect(
      target.panelSettings(PanelPageKind.home).map((panel) => panel.id),
      <String>['recent', 'budget', 'trend', 'calendar'],
    );

    target.dispose();
  });

  test(
    'panel normalization inserts new specs at their catalog position',
    () async {
      final store = LocalKeyValueStore();
      // 模拟旧版本的清单：缺少 summary（目录下标 0），且带着已下线的旧面板。
      store.write(
        'verifin.report_panels.v1',
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{'id': 'budget_execution', 'enabled': true},
          <String, Object?>{'id': 'category_ring', 'enabled': true},
          <String, Object?>{'id': 'category_rank', 'enabled': true},
          <String, Object?>{'id': 'daily_trend', 'enabled': true},
          <String, Object?>{'id': 'monthly_structure', 'enabled': true},
        ]),
      );

      final controller = await makeController(store);
      expect(
        controller
            .panelSettings(PanelPageKind.reportsMonthly)
            .map((panel) => panel.id),
        <String>[
          'summary',
          'budget_execution',
          'category_stats',
          'ranking',
          'daily_trend',
        ],
      );
      expect(
        controller
            .panelSettings(PanelPageKind.reportsMonthly)
            .firstWhere((panel) => panel.id == 'category_stats')
            .enabled,
        isTrue,
      );
      controller.dispose();
    },
  );

  test('backup carries every report tab panel list', () async {
    final controller = await makeController();
    final data =
        (jsonDecode(controller.exportDataJson())
                as Map<String, Object?>)['data']!
            as Map<String, Object?>;
    expect(data['reportPanels'], isA<List<Object?>>());
    expect(data['reportDailyPanels'], isA<List<Object?>>());
    expect(data['reportYearlyPanels'], isA<List<Object?>>());
    controller.dispose();
  });
}
