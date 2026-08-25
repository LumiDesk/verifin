import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/profile_pages.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('shows the main tabs and switches between pages', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('main_shell_scaffold')))
          .extendBody,
      isTrue,
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
    final navigationHeight = tester
        .getSize(find.byKey(const Key('main_bottom_nav')))
        .height;
    expect(homeListPadding.bottom, navigationHeight + 12);
    expect(find.text('日常账本 · 单位：¥'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('净资产'), findsAtLeastNWidgets(1));

    await tapBottomTab(tester, 2);
    expect(find.text('数据看板 · 单位：¥'), findsOneWidget);

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
    final rowHeight = cellWidth / firstDelegate.childAspectRatio;
    expect(tester.getSize(firstGrid).height, closeTo(rowHeight, 0.1));
    expect(
      tester.getSize(secondGrid).height,
      closeTo(rowHeight * 2 + firstDelegate.mainAxisSpacing, 0.1),
    );
  });

  testWidgets('drag release keeps snapping from the finger position', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    final firstCenter = capsuleRect.left + slotWidth * 0.5;
    final gesture = await tester.startGesture(
      Offset(firstCenter, capsuleRect.center.dy),
    );
    await gesture.moveTo(
      Offset(firstCenter + slotWidth * 2.7, capsuleRect.center.dy),
    );
    await tester.pump();

    final beforeRelease = tester
        .getRect(find.byKey(const Key('main_nav_indicator')))
        .center
        .dx;
    await gesture.up();
    var previousPosition = beforeRelease;
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      final currentPosition = tester
          .getRect(find.byKey(const Key('main_nav_indicator')))
          .center
          .dx;
      expect(
        currentPosition,
        greaterThanOrEqualTo(previousPosition - 0.1),
        reason: '吸附到右侧目标时，第 $frame 帧不应向原 Tab 回退',
      );
      previousPosition = currentPosition;
    }
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('数据看板 · 单位：¥'), findsOneWidget);
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

    await tester.ensureVisible(find.text('主题模式'));
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
    // 底部导航是纯图标，标签在 Tooltip 里。
    expect(find.byTooltip('Home'), findsOneWidget);
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
}
