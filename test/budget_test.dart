import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/budget_pages.dart';
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

    // 通过顶部“本月可用预算”旁的编辑图标设置本月预算（月度卡片在开屏即可见，
    // 每日预算卡片的编辑图标在其后，.first 命中的仍是月度卡片）
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('设置本月预算'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2400');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 趋势卡片位于每日预算卡片之后，滚动到可见再断言
    await tester.scrollUntilVisible(
      find.text('近 6 月趋势'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('近 6 月趋势'), findsOneWidget);

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
    await tester.scrollUntilVisible(
      find.text('近 6 月趋势'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

  testWidgets('home budget card shows negative remaining when overspent', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller
      ..addEntry(
        LedgerEntry(
          id: 'over-budget',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 150,
          categoryId: 'dining',
          accountId: 'cash-test',
          note: '大额支出',
          occurredAt: now,
        ),
      )
      ..setMonthlyBudget(now, 100)
      ..dispose();

    await pumpApp(tester, store);
    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // 支出 150、预算 100：剩余应显示 -50（负数），而不再夹到 0。
    expect(find.text('-50'), findsOneWidget);
  });

  test('category budget rolls up sub-category spending into parent', () async {
    final controller = await makeController();
    final month = DateTime(2026, 7);
    final diningId = controller.categories
        .firstWhere((c) => c.label == '餐饮')
        .id;
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = controller.categories
        .firstWhere((c) => c.label == '咖啡')
        .id;

    final entries = <LedgerEntry>[
      LedgerEntry(
        id: 'e-dining',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 30,
        categoryId: diningId,
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(2026, 7, 2),
      ),
      LedgerEntry(
        id: 'e-coffee',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 20,
        categoryId: coffeeId,
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(2026, 7, 3),
      ),
    ];

    final snapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: month,
      monthEntries: entries,
    );
    final dining = snapshots.firstWhere((s) => s.category.id == diningId);
    final coffee = snapshots.firstWhere((s) => s.category.id == coffeeId);
    // 父分类「餐饮」应包含自身 30 + 子分类「咖啡」20 = 50。
    expect(dining.spent, 50);
    // 子分类只计自身。
    expect(coffee.spent, 20);
    controller.dispose();
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

  test('daily budget: set, clear, and isolate between books', () async {
    final controller = await makeController();
    expect(controller.dailyBudget(), 0);

    controller.setDailyBudget(80);
    expect(controller.dailyBudget(), 80);

    controller.addLedgerBook('旅行账本');
    // 新账本没有独立的每日预算。
    expect(controller.dailyBudget(), 0);
    controller.setDailyBudget(200);

    controller.switchLedgerBook('default');
    expect(controller.dailyBudget(), 80);

    // 设为 0 视为清除。
    controller.setDailyBudget(0);
    expect(controller.dailyBudget(), 0);
    controller.dispose();
  });

  test('daily budget persists across restart', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setDailyBudget(66);
    controller.dispose();

    // 复用同一存储的仓储即模拟重启后重新载入。
    final restarted = await makeController(store);
    expect(restarted.dailyBudget(), 66);
    restarted.dispose();
  });

  test('daily budget survives backup export/import roundtrip', () async {
    final controller = await makeController();
    controller.setDailyBudget(123);
    final json = controller.exportDataJson();

    final target = await makeController();
    expect(target.dailyBudget(), 0);
    target.importDataJson(json);
    expect(target.dailyBudget(), 123);
    controller.dispose();
    target.dispose();
  });
}
