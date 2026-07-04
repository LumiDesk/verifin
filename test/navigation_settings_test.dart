
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';

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
    expect(find.text('VeriFin $appVersionLabel'), findsOneWidget);
    expect(find.text('同步方式'), findsNothing);
    expect(find.text('Android 打包'), findsNothing);

    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('requires double confirmation before resetting data', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
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
