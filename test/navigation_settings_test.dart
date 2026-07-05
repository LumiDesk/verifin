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

    expect(find.text('日常账本'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('净资产'), findsAtLeastNWidgets(1));

    await tapBottomTab(tester, 2);
    expect(find.text('数据看板'), findsOneWidget);

    await tapBottomTab(tester, 3);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('changes theme preference from the profile page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('触感反馈'), findsOneWidget);
    expect(find.text('同步方式'), findsNothing);
    expect(find.text('Android 打包'), findsNothing);
    await tester.scrollUntilVisible(find.text('VeriFin $appVersionLabel'), 120);
    expect(find.text('VeriFin $appVersionLabel'), findsOneWidget);

    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('changes language preference and persists across restart', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(find.text('选择语言'), findsOneWidget);
    // 主题模式行的 trailing 也是「跟随系统」，弹窗里再出现一次。
    expect(find.text('跟随系统'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // 设置页即时切换为英文并落盘。
    expect(find.text('Language'), findsOneWidget);
    expect(store.read('verifin.locale.v1'), 'en');

    // 模拟重启：先卸载旧树（同类型根组件会被框架复用 State），再用同一
    // store 重建，语言仍是英文且底部导航渲染英文。
    await tester.pumpWidget(const SizedBox.shrink());
    final restarted = await pumpApp(tester, store);
    await tester.pumpAndSettle();
    expect(restarted.localePreference, LocalePreference.en);
    // 底部导航是纯图标，标签在 Tooltip 里。
    expect(find.byTooltip('Home'), findsOneWidget);
  });

  testWidgets('requires double confirmation before resetting data', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('数据管理'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('初始化数据'), 160);
    await tester.tap(find.text('初始化数据'));
    await tester.pumpAndSettle();

    expect(find.text('初始化所有数据？'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('再次确认初始化'), findsOneWidget);
    expect(find.text('确认初始化'), findsOneWidget);
  });
}
