import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
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
    // 默认标题为「概览」（可自定义，留空时回落此默认）。
    expect(find.text('概览'), findsOneWidget);

    // 点击卡片标题区域仍然进入收支统计页。
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    expect(find.text('收支统计'), findsOneWidget);
  });

  testWidgets('sets default budget and category default from budget settings', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: firstVerticalScrollable(),
    );
    await tester.tap(find.byType(BudgetPanel));
    await tester.pumpAndSettle();

    // 总览页标题为「预算」，只读；配置走右上角设置齿轮。
    expect(find.text('预算'), findsWidgets);
    expect(find.text('本月支出'), findsAtLeastNWidgets(1));

    // 进入预算设置页，设默认月预算 2400（每月自动沿用，无需逐月改）。
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('预算设置'), findsOneWidget);
    await tester.tap(find.text('默认月预算'));
    await tester.pumpAndSettle();
    expect(find.text('设置默认月预算'), findsOneWidget);
    for (final key in <String>['2', '4', '00']) {
      await tester.tap(find.byKey(Key('number_key_$key')));
    }
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    // 设餐饮默认预算 600。
    await tester.scrollUntilVisible(
      find.text('餐饮'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('设置餐饮默认预算'), findsOneWidget);
    for (final key in <String>['6', '00']) {
      await tester.tap(find.byKey(Key('number_key_$key')));
    }
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();
    expect(find.text('600'), findsWidgets);

    // 返回总览再回主页：BudgetPanel 应显示沿用默认的「预算 2400」。
    // （列表已滚动到分类行、顶部返回按钮已滚出视口，改用 Navigator.pop 返回。）
    Navigator.of(tester.element(find.byType(BudgetSettingsPage))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BudgetOverviewPage))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetPanel), findsOneWidget);
    expect(find.text('预算 2400'), findsOneWidget);
  });

  testWidgets('category budget list renders as a collapsible tree', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    // 在种子分类「餐饮」下建一个子分类，形成父子层级。
    controller.addCategory(
      type: EntryType.expense,
      label: '午餐',
      iconCode: 'category',
      parentId: 'dining',
    );
    controller.dispose();

    await pumpApp(tester, store);
    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: firstVerticalScrollable(),
    );
    tester.widget<BudgetPanel>(find.byType(BudgetPanel)).onTap();
    await tester.pumpAndSettle();

    // 分类树默认折叠：父分类「餐饮」可见，子分类「午餐」隐藏。
    await tester.scrollUntilVisible(
      find.text('餐饮'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);

    // 展开父分类后子分类进入组件树（展开后可能在视口外，用 skipOffstage 断言存在）。
    // 分类卡内的 chevron_right 才是折叠开关（MonthSwitcher 的下一月箭头也用该图标）。
    final toggle = find.descendant(
      of: find.ancestor(of: find.text('餐饮'), matching: find.byType(VeriCard)),
      matching: find.byIcon(Icons.chevron_right),
    );
    await tester.ensureVisible(toggle.first);
    await tester.pumpAndSettle();
    await tester.tap(toggle.first);
    await tester.pumpAndSettle();
    expect(find.text('午餐', skipOffstage: false), findsOneWidget);
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
      scrollable: firstVerticalScrollable(),
    );

    expect(find.text('餐饮超出 25'), findsOneWidget);
    tester.widget<BudgetPanel>(find.byType(BudgetPanel)).onTap();
    await tester.pumpAndSettle();

    // 总览页标题为「预算」。
    expect(find.text('预算'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('近 6 月趋势'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('近 6 月趋势'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('历史对比'),
      200,
      scrollable: firstVerticalScrollable(),
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
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('餐饮已超支'), findsOneWidget);
    expect(find.textContaining('已超出 25'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('上月 40'),
      200,
      scrollable: firstVerticalScrollable(),
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
      scrollable: firstVerticalScrollable(),
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

    // 新账本无单月覆盖也无默认月预算，回落 0（不再有硬编码 800）。
    expect(controller.monthlyBudget(month), 0);
    expect(controller.categoryBudget(month, 'dining'), 0);

    controller.setMonthlyBudget(month, 1200);
    controller.switchLedgerBook('default');

    expect(controller.monthlyBudget(month), 5000);
    expect(controller.categoryBudget(month, 'dining'), 600);
    controller.dispose();
  });

  group('默认月预算 + 单月覆盖（issue #21）', () {
    test('无预算时回落 0；默认月预算每月自动沿用', () async {
      final controller = await makeController();
      final july = DateTime(2026, 7);
      final august = DateTime(2026, 8);
      // 不再有硬编码 800：未设默认、未设覆盖 → 0。
      expect(controller.defaultMonthlyBudget, 0);
      expect(controller.monthlyBudget(july), 0);

      controller.setDefaultMonthlyBudget(2000);
      // 默认每月自动沿用，任意月都是 2000，且不算「单月覆盖」。
      expect(controller.monthlyBudget(july), 2000);
      expect(controller.monthlyBudget(august), 2000);
      expect(controller.monthlyBudgetIsOverride(july), isFalse);
      controller.dispose();
    });

    test('单月覆盖优先于默认；清除覆盖回到沿用默认', () async {
      final controller = await makeController();
      final july = DateTime(2026, 7);
      controller.setDefaultMonthlyBudget(2000);

      controller.setMonthlyBudget(july, 5000);
      expect(controller.monthlyBudget(july), 5000);
      expect(controller.monthlyBudgetIsOverride(july), isTrue);
      // 其它月仍沿用默认。
      expect(controller.monthlyBudget(DateTime(2026, 8)), 2000);

      controller.clearMonthlyBudgetOverride(july);
      expect(controller.monthlyBudgetIsOverride(july), isFalse);
      expect(controller.monthlyBudget(july), 2000);
      controller.dispose();
    });

    test('默认月预算按账本隔离', () async {
      final controller = await makeController();
      controller.setDefaultMonthlyBudget(2000);

      controller.addLedgerBook('旅行账本');
      expect(controller.defaultMonthlyBudget, 0);
      controller.setDefaultMonthlyBudget(500);

      controller.switchLedgerBook('default');
      expect(controller.defaultMonthlyBudget, 2000);
      controller.dispose();
    });

    test('分类默认预算：沿用/覆盖/持久化 + 备份 roundtrip', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      final july = DateTime(2026, 7);
      controller.setDefaultCategoryBudget('dining', 800);
      controller.setDefaultMonthlyBudget(3000);
      // 分类默认每月沿用；单月覆盖优先。
      expect(controller.categoryBudget(july, 'dining'), 800);
      controller.setCategoryBudget(july, 'dining', 1200);
      expect(controller.categoryBudget(july, 'dining'), 1200);
      expect(controller.categoryBudget(DateTime(2026, 8), 'dining'), 800);
      final json = controller.exportDataJson();
      controller.dispose();

      // 重启：默认预算随预算表持久化。
      final restarted = await makeController(store);
      expect(restarted.defaultMonthlyBudget, 3000);
      expect(restarted.defaultCategoryBudget('dining'), 800);
      restarted.dispose();

      // 备份导入：默认预算进 JSON 备份。
      final target = await makeController();
      expect(target.defaultMonthlyBudget, 0);
      target.importDataJson(json);
      expect(target.defaultMonthlyBudget, 3000);
      expect(target.defaultCategoryBudget('dining'), 800);
      target.dispose();
    });

    test('初始化数据清除默认预算', () async {
      final controller = await makeController();
      controller.setDefaultMonthlyBudget(2000);
      controller.setDefaultCategoryBudget('dining', 500);
      controller.resetAllData();
      expect(controller.defaultMonthlyBudget, 0);
      expect(controller.defaultCategoryBudget('dining'), 0);
      controller.dispose();
    });
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

  group('预算周期起始日（issue #19）', () {
    test('默认自然月；设置/清除/账本隔离/钳位', () async {
      final controller = await makeController();
      expect(controller.budgetCycleStartDay, 1);
      expect(controller.budgetCycleIsCustom, isFalse);

      controller.setBudgetCycleStartDay(22);
      expect(controller.budgetCycleStartDay, 22);
      expect(controller.budgetCycleIsCustom, isTrue);

      // 账本隔离：新账本回落默认，各账本独立。
      controller.addLedgerBook('旅行账本');
      expect(controller.budgetCycleStartDay, 1);
      controller.setBudgetCycleStartDay(10);
      controller.switchLedgerBook('default');
      expect(controller.budgetCycleStartDay, 22);

      // 越界钳到 1–28；设回 1 即清除自定义。
      controller.setBudgetCycleStartDay(31);
      expect(controller.budgetCycleStartDay, 28);
      controller.setBudgetCycleStartDay(1);
      expect(controller.budgetCycleIsCustom, isFalse);
      controller.dispose();
    });

    test('周期窗口与键月：起始日 22 时 21/22 日分属两期', () async {
      final controller = await makeController();
      controller.setBudgetCycleStartDay(22);
      final window = controller.budgetWindow(DateTime(2026, 7));
      expect(window.start, DateTime(2026, 7, 22));
      expect(window.end, DateTime(2026, 8, 21));
      expect(
        controller.budgetKeyMonthFor(DateTime(2026, 7, 21)),
        DateTime(2026, 6),
      );
      expect(
        controller.budgetKeyMonthFor(DateTime(2026, 7, 22)),
        DateTime(2026, 7),
      );
      controller.dispose();
    });

    test('重启持久化 + 备份导出/导入 roundtrip', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      controller.setBudgetCycleStartDay(22);
      final json = controller.exportDataJson();
      controller.dispose();

      // 复用同一存储即模拟重启。
      final restarted = await makeController(store);
      expect(restarted.budgetCycleStartDay, 22);
      restarted.dispose();

      final target = await makeController();
      expect(target.budgetCycleStartDay, 1);
      target.importDataJson(json);
      expect(target.budgetCycleStartDay, 22);
      target.dispose();
    });

    test('初始化数据后回到自然月', () async {
      final controller = await makeController();
      controller.setBudgetCycleStartDay(22);
      controller.resetAllData();
      expect(controller.budgetCycleStartDay, 1);
      controller.dispose();
    });

    testWidgets('预算页按周期取数并用「本期」文案', (WidgetTester tester) async {
      final controller = await makeController();
      controller.setBudgetCycleStartDay(22);
      controller.setDefaultMonthlyBudget(800);
      final bookId = controller.activeBook.id;
      controller
        ..addEntry(
          LedgerEntry(
            id: 'in-cycle',
            bookId: bookId,
            type: EntryType.expense,
            amount: 100,
            categoryId: 'dining',
            accountId: '',
            note: '周期内',
            occurredAt: DateTime(2026, 7, 23),
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 'prev-cycle',
            bookId: bookId,
            type: EntryType.expense,
            amount: 40,
            categoryId: 'dining',
            accountId: '',
            note: '上一期',
            occurredAt: DateTime(2026, 7, 21),
          ),
        );

      await tester.pumpWidget(
        VeriFinScope(
          controller: controller,
          child: zhMaterialApp(
            home: BudgetOverviewPage(initialMonth: DateTime(2026, 7)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 周期标签展示日期范围而非「2026年7月」，文案用「本期」。
      expect(find.textContaining('7月22日'), findsWidgets);
      expect(find.text('本期支出'), findsAtLeastNWidgets(1));
      expect(find.text('本月支出'), findsNothing);
      // 键月 2026-07 的周期是 7/22~8/21：只计入 23 日那笔（默认预算 800，
      // 剩余 700，大字与「剩余额度」瓦片各一处）；若误按自然月聚合会把 21 日
      // 的 40 也算进来（剩余 660）。
      expect(find.text('700'), findsWidgets);
      expect(find.text('660'), findsNothing);
      controller.dispose();
    });
  });
}
