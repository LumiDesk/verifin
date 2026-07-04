
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/home_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('home trend chart tap shows data instead of navigating', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // 点击图表区域只选中数据点,不进入收支统计页。
    await tester.tap(find.byType(InteractiveTrendChart).first);
    await tester.pumpAndSettle();
    expect(find.text('收支统计'), findsNothing);
    expect(find.text('支出走势'), findsOneWidget);

    // 点击卡片标题区域仍然进入收支统计页。
    await tester.tap(find.text('支出走势'));
    await tester.pumpAndSettle();
    expect(find.text('收支统计'), findsOneWidget);
  });

  testWidgets('edits monthly budget from the home budget card', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(BudgetPanel));
    await tester.pumpAndSettle();

    expect(find.text('预算设置'), findsOneWidget);
    expect(find.text('本月支出'), findsAtLeastNWidgets(1));
    expect(find.text('剩余日均'), findsOneWidget);
    expect(find.text('近 6 月趋势'), findsOneWidget);

    // 通过顶部“本月可用预算”旁的编辑图标设置本月预算
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('设置本月预算'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2400');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('餐饮'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('餐饮'), findsOneWidget);
    await tester.ensureVisible(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('设置餐饮预算'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '600');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('600'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('预算设置'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetPanel), findsOneWidget);
    expect(find.text('预算 2400'), findsOneWidget);
  });

  testWidgets('shows category budget risk on home and budget page', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 12);
    controller
      ..addEntry(
        LedgerEntry(
          id: 'dining-risk',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 75,
          categoryId: 'dining',
          accountId: 'cash-test',
          note: '晚餐',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'dining-previous',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 40,
          categoryId: 'dining',
          accountId: 'cash-test',
          note: '上月晚餐',
          occurredAt: previousMonth,
        ),
      )
      ..setMonthlyBudget(now, 100)
      ..setCategoryBudget(now, 'dining', 50)
      ..dispose();

    await pumpApp(tester, store);
    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('餐饮超出 25'), findsOneWidget);
    tester.widget<BudgetPanel>(find.byType(BudgetPanel)).onTap();
    await tester.pumpAndSettle();

    expect(find.text('预算设置'), findsOneWidget);
    expect(find.text('近 6 月趋势'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('历史对比'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('历史对比'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('预算历史'), findsOneWidget);
    expect(find.text('月份汇总'), findsOneWidget);
    Navigator.of(tester.element(find.text('预算历史'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('餐饮已超支'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('餐饮已超支'), findsOneWidget);
    expect(find.textContaining('已超出 25'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('上月 40'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('上月 40'), findsOneWidget);

    Navigator.of(tester.element(find.text('上月 40'))).pop();
    await tester.pumpAndSettle();
    await tapBottomTab(tester, 2);

    expect(find.text('预算执行'), findsOneWidget);
    expect(find.text('1 个超支'), findsOneWidget);
  });

  test('isolates budgets between ledger books', () async {
    final controller = await makeController();
    final month = DateTime(2026, 7);
    controller.setMonthlyBudget(month, 5000);
    controller.setCategoryBudget(month, 'dining', 600);

    controller.addLedgerBook('旅行账本');

    expect(controller.monthlyBudget(month), 800);
    expect(controller.categoryBudget(month, 'dining'), 0);

    controller.setMonthlyBudget(month, 1200);
    controller.switchLedgerBook('default');

    expect(controller.monthlyBudget(month), 5000);
    expect(controller.categoryBudget(month, 'dining'), 600);
    controller.dispose();
  });
}
