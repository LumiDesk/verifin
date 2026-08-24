import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('shows the main tabs and switches between pages', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('日常账本 · 单位：¥'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('净资产'), findsAtLeastNWidgets(1));

    await tapBottomTab(tester, 2);
    expect(find.text('数据看板 · 单位：¥'), findsOneWidget);

    await tapBottomTab(tester, 3);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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
