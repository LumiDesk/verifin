import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/budget_pages.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/profile_pages.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('设置的外观金额显示与通用各自成组', (tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    for (final item in {
      '主题模式': 'settingsSectionAppearance',
      '金额保留两位小数': 'settingsSectionAmountDisplay',
      '触感反馈': 'settingsSectionGeneral',
    }.entries) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(item.value)),
          matching: find.text(item.key),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('金额显示'), findsOneWidget);
  });

  testWidgets('shows the main tabs and switches between pages', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // 底栏已改为停靠式（不透明、整宽贴底），内容不再延伸到它背后。
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('main_shell_scaffold')))
          .extendBody,
      isFalse,
    );
    expect(
      tester
          .widget<SafeArea>(find.byKey(const Key('main_shell_body_safe_area')))
          .bottom,
      isFalse,
    );
    final homeList = tester.widget<ListView>(
      find
          .descendant(
            of: find.byType(HomePage),
            matching: find.byType(ListView),
          )
          .first,
    );
    final homeListPadding = homeList.padding! as EdgeInsets;
    // Scaffold 已为停靠底栏让位，列表末项只需少量留白。
    expect(homeListPadding.bottom, 12);
    expect(find.text('日常账本 · 单位：¥'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('净资产'), findsAtLeastNWidgets(1));

    await tapBottomTab(tester, 2);
    expect(find.text('预算与统计 · 单位：¥'), findsOneWidget);

    await tapBottomTab(tester, 3);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('floating navigation inset does not inflate nested grids', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(
      find.byType(CalendarPreview),
      500,
      scrollable: firstVerticalScrollable(),
    );
    final calendarGrid = find.descendant(
      of: find.byType(CalendarPreview),
      matching: find.byType(GridView),
    );
    expect(calendarGrid, findsOneWidget);
    expect(MediaQuery.paddingOf(tester.element(calendarGrid)).bottom, 0);
    final calendar = tester.widget<GridView>(calendarGrid);
    final calendarDelegate =
        calendar.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final calendarRows = (calendar.semanticChildCount! + 6) ~/ 7;
    final expectedCalendarHeight =
        calendarRows * calendarDelegate.mainAxisExtent! +
        (calendarRows - 1) * calendarDelegate.mainAxisSpacing;
    expect(
      tester.getSize(calendarGrid).height,
      closeTo(expectedCalendarHeight, 0.1),
    );

    await tapBottomTab(tester, 3);
    final featureGrids = find.descendant(
      of: find.byType(ProfilePage),
      matching: find.byType(GridView),
    );
    expect(featureGrids, findsNWidgets(2));
    for (final grid in <Finder>[featureGrids.at(0), featureGrids.at(1)]) {
      expect(MediaQuery.paddingOf(tester.element(grid)).bottom, 0);
    }

    final firstGrid = featureGrids.at(0);
    final secondGrid = featureGrids.at(1);
    final firstDelegate =
        tester.widget<GridView>(firstGrid).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    final cellWidth =
        (tester.getSize(firstGrid).width -
            firstDelegate.crossAxisSpacing *
                (firstDelegate.crossAxisCount - 1)) /
        firstDelegate.crossAxisCount;
    // 宫格显式给了 mainAxisExtent（随系统字号放大），此时 childAspectRatio 不生效。
    final rowHeight =
        firstDelegate.mainAxisExtent ??
        cellWidth / firstDelegate.childAspectRatio;
    expect(tester.getSize(firstGrid).height, closeTo(rowHeight, 0.1));
    expect(
      tester.getSize(secondGrid).height,
      closeTo(rowHeight * 2 + firstDelegate.mainAxisSpacing, 0.1),
    );
  });

  testWidgets('点击底栏条目切到对应页面', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final navRect = tester.getRect(find.byKey(const Key('main_bottom_nav')));
    final slotWidth = navRect.width / 4;
    // 第四个条目的中心：点「我的」。
    await tester.tapAt(
      Offset(navRect.left + slotWidth * 3.5, navRect.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('相邻页面点击后立刻开始切换，不等底栏动画', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();

    // 从「我的」回到相邻的「看板」。切页必须由点击同步发起；若依赖底栏动画结束时
    // 的回调，这里推进 100ms 后页面还停在原处。
    await tester.tapAt(rootTabCenter(tester, 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final page = controller.page!;
    expect(page, lessThan(3), reason: '点击后 100ms 内页面应已在移动，说明切页与底栏动画同时起步');
    expect(page, greaterThan(2), reason: '此时应还在过渡中，未到看板');

    // 走完整段动画后应正好落在看板页。
    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 2);
  });

  testWidgets('安卓返回回首页同样走滚动动画，不瞬移', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(controller.page!.round(), 3);

    // 安卓返回：在第 4 个 Tab 上按返回键回首页。跨度 3 页也要正常滚动过去，
    // 不能一步到位——跨多页时用户同样要看到页面滚动动画。
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.page, lessThan(3), reason: '返回后页面应已开始滚动');
    expect(controller.page, greaterThan(0), reason: '100ms 后应还在过渡中，不能直接落位');

    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 0);
    expect(find.text('日常账本 · 单位：¥'), findsOneWidget);
  });

  testWidgets('跨多页点按同样滚动过去，并落在目标页', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;

    // 从「我的」直接点「首页」，跨度 3 页。跨多页同样要看到页面滚动，不能一步到位。
    await tester.tapAt(rootTabCenter(tester, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.page, lessThan(3), reason: '跨多页点按也要滚动，不能瞬移');
    expect(controller.page, greaterThan(0), reason: '100ms 后应还在途中');

    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 0);
  });

  testWidgets('连点不同 Tab 改目标后仍然正确落位', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;

    // 动画没播完就改点别的 Tab：页面必须改朝新目标走，而不是停住或退回原处。
    await tester.tapAt(rootTabCenter(tester, 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.page, lessThan(3), reason: '第一次点按应已开始滚动');

    await tester.tapAt(rootTabCenter(tester, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.page, greaterThan(0), reason: '改目标后仍在过渡途中');

    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 0, reason: '应落在最后点选的首页');
    expect(find.text('日常账本 · 单位：¥'), findsOneWidget);
  });

  testWidgets('连点不同 Tab 之后仍然响应，且底栏与页面一致', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    int barIndex() => tester
        .widget<VeriRootNavigation>(find.byType(VeriRootNavigation))
        .currentIndex;

    // 在两个相距最远的 Tab 之间连点，让切页动画反复被打断。此时底栏下标是点击时
    // 乐观写入的，页面还在半路，两者会短暂脱节。
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(rootTabCenter(tester, 0));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(rootTabCenter(tester, 3));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();

    expect(
      barIndex(),
      controller.page!.round(),
      reason: '停稳后底栏下标必须与页面实际页码一致，否则会看不出自己在哪一页',
    );

    // 脱节状态下点「底栏已经显示在那儿的那个 Tab」曾被当成重复点击丢掉，表现是
    // 点了没反应、卡在某个 Tab 上。这里连点之后必须仍然点得动。
    await tester.tapAt(rootTabCenter(tester, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.page, lessThan(3), reason: '连点之后点击仍应立刻开始切页');

    await tester.pump(VeriRootNavigation.switchDuration);
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 1);
    expect(barIndex(), 1, reason: '底栏要跟着落到资产页');
  });

  testWidgets('点击开关行的标题也能切换开关', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('触感反馈'), 120);
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('触感反馈'),
      matching: find.byType(CompactSwitchRow),
    );
    expect(row, findsOneWidget);
    final before = tester.widget<CompactSwitchRow>(row).value;

    // 点标题文字而不是右侧被缩小过的开关：整行都应可点。
    await tester.tap(find.text('触感反馈'));
    await tester.pumpAndSettle();

    expect(tester.widget<CompactSwitchRow>(row).value, !before);
  });

  testWidgets('changes theme preference from the profile page', (
    WidgetTester tester,
  ) async {
    final controller = await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('触感反馈'), findsOneWidget);
    expect(find.text('同步方式'), findsNothing);
    expect(find.text('Android 打包'), findsNothing);
    await tester.scrollUntilVisible(find.text('VeriFin $appVersionLabel'), 120);
    expect(find.text('VeriFin $appVersionLabel'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('主题模式'), -180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(controller.themePreference, ThemePreference.system);

    await tester.fling(firstVerticalScrollable(), const Offset(0, 1200), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.themePreference, ThemePreference.dark);
    expect(find.byTooltip('保存'), findsNothing);
    expect(find.text('未保存的修改'), findsNothing);
  });

  testWidgets('changes language preference and persists across restart', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await pumpApp(tester, store);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);

    // 设置页比一屏长，先滚到「语言」再点，否则点击会落在屏幕外。
    await tester.scrollUntilVisible(find.text('语言'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('veri_menu_item_settings_locale_system'),
      ),
      findsOneWidget,
    );
    // 主题模式行的 trailing 也是「跟随系统」，弹窗里再出现一次。
    expect(find.text('跟随系统'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // 选择仅更新草稿，保存前不切换应用语言、不写 KV。
    expect(find.text('语言'), findsOneWidget);
    expect(controller.localePreference, LocalePreference.zh);
    expect(store.read('verifin.locale.v1'), 'zh');

    // 保存按钮在页头，滚回顶部才能点到。
    await tester.fling(firstVerticalScrollable(), const Offset(0, 1200), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.localePreference, LocalePreference.en);
    expect(store.read('verifin.locale.v1'), 'en');

    // 模拟重启：先卸载旧树（同类型根组件会被框架复用 State），再用同一
    // store 重建，语言仍是英文且底部导航渲染英文标签与 Tooltip。
    await tester.pumpWidget(const SizedBox.shrink());
    final restarted = await pumpApp(tester, store);
    await tester.pumpAndSettle();
    expect(restarted.localePreference, LocalePreference.en);
    // 底部导航标签常显（规范要求），随语言切换为英文。
    expect(
      find.descendant(
        of: find.byKey(const Key('main_bottom_nav')),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('changes currency unit style and single-currency visibility', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await pumpApp(tester, store);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('货币单位样式'));

    expect(find.text('符号后置（100 ¥）'), findsOneWidget);
    await tester.tap(find.text('货币单位样式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('代码前置（CNY 100）'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('hide_single_currency_unit')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    // 设置页先维护草稿，保存前不修改 Controller。
    expect(controller.moneyUnitStyle, MoneyUnitStyle.symbol);
    expect(controller.hideUnitInSingleCurrency, isTrue);
    await tester.fling(firstVerticalScrollable(), const Offset(0, 1200), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.moneyUnitStyle, MoneyUnitStyle.code);
    expect(controller.hideUnitInSingleCurrency, isFalse);

    final restarted = await makeController(store);
    expect(restarted.moneyUnitStyle, MoneyUnitStyle.code);
    expect(restarted.hideUnitInSingleCurrency, isFalse);
    restarted.dispose();
  });

  testWidgets('requires double confirmation before resetting data', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('数据管理'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('初始化数据'), 160);
    await tester.ensureVisible(find.text('初始化数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('初始化数据'));
    await tester.pumpAndSettle();

    expect(find.text('初始化所有数据？'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('再次确认初始化'), findsOneWidget);
    expect(find.text('确认初始化'), findsOneWidget);
  });

  testWidgets('我的宫格提供预算与 AI 助理入口', (WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 3);

    await tester.scrollUntilVisible(
      find.text('AI 财务助理'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('AI 财务助理'), findsOneWidget);
    expect(find.text('预算'), findsOneWidget);

    // 首页预算面板被关掉后，这个入口是预算功能唯一的入口。
    await tester.ensureVisible(find.text('预算'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预算'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetOverviewPage), findsOneWidget);
  });
}
