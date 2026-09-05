import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/main.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/budget_pages.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();
  testWidgets('紧凑首页首屏可见总览、三条交易和预算摘要，点击仍进入详情', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final controller = await makeController();
    controller.importTransactionsFromCsv(
      File('docs/dev/preview-transactions.csv').readAsStringSync(),
    );
    controller.setMonthlyBudget(DateTime.now(), 5000);
    controller.setThemePreference(ThemePreference.light);
    await controller.waitForPendingWrites();
    await tester.pumpWidget(VeriFinApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final overview = tester.getRect(find.byType(HomeTrendPanel));
    expect(overview.height, lessThanOrEqualTo(280));
    final transactions = find.byType(TransactionTile);
    expect(transactions, findsNWidgets(3));
    final navTop = tester
        .getRect(find.byKey(const Key('main_nav_capsule')))
        .top;
    expect(tester.getRect(transactions.last).bottom, lessThan(navTop));
    final budget = find.byKey(const Key('home_compact_budget'));
    expect(tester.getRect(budget).bottom, lessThan(navTop));
    await tester.tap(budget);
    await tester.pumpAndSettle();
    expect(find.byType(HomeTrendPanel), findsNothing);
    expect(find.byType(BudgetOverviewPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !veriUnifiedDesignPreview);
}
