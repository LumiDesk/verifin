import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/main.dart';

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('main_tab_$index')));
  await tester.pumpAndSettle();
}

Future<void> addTestAccount(WidgetTester tester, String name) async {
  await tapBottomTab(tester, 1);
  await tester.tap(find.byTooltip('资产操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加账户'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.tap(find.byTooltip('保存账户'));
  await tester.pumpAndSettle();
}

Future<void> createQuickEntry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quick_entry_fab')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('number_key_4')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_key_5')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_pad_ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the main tabs and switches between pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

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
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('opens asset cover selector from the assets page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('更换资产卡片背景'));
    await tester.pumpAndSettle();

    expect(find.text('资产卡片背景'), findsOneWidget);
    expect(find.text('使用线上图片'), findsOneWidget);
    expect(find.text('选择本地图片'), findsOneWidget);
  });

  testWidgets('shows neutral zero in income expense stats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tester.tap(find.text('支出走势'));
    await tester.pumpAndSettle();

    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('-0'), findsNothing);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('edits monthly budget from the home budget card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

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

    await tester.scrollUntilVisible(
      find.text('设置预算'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, '2400');
    await tester.pump();
    expect(find.text('2400'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('分类预算'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('餐饮'), findsOneWidget);
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
    final saveAction = tester.widget<HeaderAction>(
      find.byWidgetPredicate(
        (widget) => widget is HeaderAction && widget.tooltip == '保存预算',
      ),
    );
    saveAction.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.byType(BudgetPanel), findsOneWidget);
    expect(find.text('预算 2400'), findsOneWidget);
  });

  testWidgets('shows category budget risk on home and budget page', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = VeriFinController(store);
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

    await tester.pumpWidget(VeriFinApp(store: store));
    await tester.scrollUntilVisible(
      find.byType(BudgetPanel),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('餐饮超出 25'), findsOneWidget);
    tester.widget<BudgetPanel>(find.byType(BudgetPanel)).onTap();
    await tester.pumpAndSettle();

    expect(find.text('预算设置'), findsOneWidget);
    expect(find.text('历史对比'), findsOneWidget);
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

  testWidgets('creates an entry through the quick entry flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);

    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
    expect(find.text('45'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('今日交易'), findsOneWidget);
    expect(find.text('餐饮'), findsAtLeastNWidgets(1));
    expect(find.text('-45'), findsAtLeastNWidgets(1));
  });

  testWidgets('opens and deletes an entry from the transaction detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮').first);
    await tester.pumpAndSettle();

    expect(find.text('支出'), findsAtLeastNWidgets(1));
    expect(find.text('账户'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(find.text('还没有交易'), findsOneWidget);
  });

  testWidgets('starts with no default accounts', (WidgetTester tester) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);

    expect(find.text('支付宝'), findsNothing);
    expect(find.text('微信'), findsNothing);
    expect(find.text('花呗'), findsNothing);
  });

  testWidgets('isolates accounts between ledger books', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '默认账本账户');

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('日常账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '旅行账本');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);

    expect(find.text('默认账本账户'), findsNothing);
  });

  testWidgets('adds a custom category from the profile page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('分类管理'));
    await tester.pumpAndSettle();

    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);

    await tester.tap(find.byTooltip('新增分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '咖啡');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类').last);
    await tester.pumpAndSettle();

    expect(find.text('咖啡'), findsOneWidget);
  });

  test('exports and imports a local data backup', () {
    final source = VeriFinController(LocalKeyValueStore());
    final account = Account(
      id: 'cash-test',
      bookId: source.activeBook.id,
      name: '现金账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'wallet',
      note: '测试账户',
      includeInAssets: true,
      hidden: false,
    );
    source
      ..addAccount(account)
      ..addEntry(
        LedgerEntry(
          id: 'entry-test',
          bookId: source.activeBook.id,
          type: EntryType.expense,
          amount: 45,
          categoryId: 'dining',
          accountId: account.id,
          note: '午餐',
          occurredAt: DateTime(2026, 7, 2, 12),
        ),
      )
      ..setMonthlyBudget(DateTime(2026, 7), 2400)
      ..setCategoryBudget(DateTime(2026, 7), 'dining', 600)
      ..setThemePreference(ThemePreference.dark)
      ..addCategory(type: EntryType.expense, label: '咖啡', iconCode: 'dining');
    final coffeeIndex = source
        .categoriesForType(EntryType.expense)
        .indexWhere((category) => category.label == '咖啡');
    source.reorderCategories(EntryType.expense, coffeeIndex, 0);

    final backup = source.exportDataJson();
    final target = VeriFinController(LocalKeyValueStore());
    target.importDataJson(backup);

    expect(target.accounts.single.name, '现金账户');
    expect(target.entries.single.amount, 45);
    expect(target.entries.single.note, '午餐');
    expect(target.monthlyBudget(DateTime(2026, 7)), 2400);
    expect(target.categoryBudget(DateTime(2026, 7), 'dining'), 600);
    expect(target.themePreference, ThemePreference.dark);
    expect(target.categories.any((category) => category.label == '咖啡'), isTrue);
    expect(target.categoriesForType(EntryType.expense).first.label, '咖啡');

    expect(
      () => target.importDataJson(
        '{"data":{"ledgerBooks":[],"entries":[],"accounts":"bad"}}',
      ),
      throwsFormatException,
    );
    expect(target.entries.single.id, 'entry-test');
    expect(target.accounts.single.id, account.id);

    source.dispose();
    target.dispose();
  });
}
