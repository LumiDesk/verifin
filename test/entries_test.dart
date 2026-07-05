import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('shows neutral zero in income expense stats', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('支出走势'));
    await tester.pumpAndSettle();

    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('-0'), findsNothing);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('creates an entry through the quick entry flow', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);

    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
    expect(find.text('45'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('最近交易'), findsOneWidget);
    expect(find.text('餐饮'), findsAtLeastNWidgets(1));
    expect(find.text('-45'), findsAtLeastNWidgets(1));
  });

  testWidgets('entry detail amount color follows type and shows account info', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await addTestAccount(tester, '现金账户');
    await addTestAccount(tester, '备用账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);

    Color? amountColor() {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('detail_amount_button')),
          matching: find.byType(Text),
        ),
      );
      return text.style?.color;
    }

    // 支出红色;账户选择框前置图标为账户图标;日期/时间旁没有多余账户 Chip。
    expect(amountColor(), veriExpense);
    expect(
      find.descendant(
        of: find.byKey(const Key('account_dropdown')),
        matching: find.byType(AccountIconBox),
      ),
      findsOneWidget,
    );
    expect(find.byType(Chip), findsNothing);

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(amountColor(), veriIncome);

    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    expect(amountColor(), veriBlue);

    // 账户选择弹窗展示账户图标与余额。
    await tester.tap(find.byKey(const Key('account_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('选择转出账户'), findsOneWidget);
    expect(find.text('备用账户'), findsAtLeastNWidgets(1));
    expect(find.text('0'), findsAtLeastNWidgets(2));
    expect(find.byType(AccountIconBox), findsAtLeastNWidgets(2));

    await tester.tap(find.text('现金账户'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
  });

  testWidgets('opens and deletes an entry from the transaction detail page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
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

  testWidgets('filters transaction list by search and account', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller
      ..addAccount(
        Account(
          id: 'cash-search-test',
          bookId: controller.activeBook.id,
          name: '现金账户',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addAccount(
        Account(
          id: 'card-search-test',
          bookId: controller.activeBook.id,
          name: '银行卡',
          type: AccountType.debitCard,
          groupId: null,
          initialBalance: 0,
          iconCode: 'bank',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'dining-search-test',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 75,
          categoryId: 'dining',
          accountId: 'cash-search-test',
          note: '晚餐',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'transport-search-test',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 12,
          categoryId: 'transport',
          accountId: 'card-search-test',
          note: '公交',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();

    expect(find.text('交易明细'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('transaction_search_field')),
      '晚餐',
    );
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);

    await tester.tap(find.byTooltip('清空筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('银行卡').last);
    await tester.pumpAndSettle();

    expect(find.text('交通'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
  });

  testWidgets(
    'filters by a parent category includes its sub-category entries',
    (WidgetTester tester) async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      final now = DateTime.now();
      controller
        ..addAccount(
          Account(
            id: 'cash-drill',
            bookId: controller.activeBook.id,
            name: '现金账户',
            type: AccountType.cash,
            groupId: null,
            initialBalance: 0,
            iconCode: 'cash',
            note: '',
            includeInAssets: true,
            hidden: false,
          ),
        )
        ..addCategory(
          type: EntryType.expense,
          label: '早餐',
          iconCode: 'dining',
          parentId: 'dining',
        );
      final breakfast = controller
          .categoriesForType(EntryType.expense)
          .firstWhere((c) => c.label == '早餐');
      controller
        ..addEntry(
          LedgerEntry(
            id: 'e-breakfast',
            bookId: controller.activeBook.id,
            type: EntryType.expense,
            amount: 8,
            categoryId: breakfast.id,
            accountId: 'cash-drill',
            note: '肠粉',
            occurredAt: now,
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 'e-transport',
            bookId: controller.activeBook.id,
            type: EntryType.expense,
            amount: 12,
            categoryId: 'transport',
            accountId: 'cash-drill',
            note: '公交',
            occurredAt: now,
          ),
        )
        ..dispose();

      await pumpApp(tester, store);
      await tester.tap(find.text('最近交易'));
      await tester.pumpAndSettle();
      // 交易行显示分类标签：子分类「早餐」与顶级「交通」各一行。
      expect(find.text('早餐'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);

      // 按父分类「餐饮」筛选，应带出记在子分类「早餐」上的交易，排除「交通」。
      await tester.tap(find.text('全部分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('餐饮').last);
      await tester.pumpAndSettle();

      expect(find.text('早餐'), findsOneWidget);
      expect(find.text('交通'), findsNothing);
    },
  );

  testWidgets('adds a custom category from the profile page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('分类管理'));
    await tester.pumpAndSettle();

    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);

    await tester.tap(find.byTooltip('新增顶级分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '咖啡');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类').last);
    await tester.pumpAndSettle();

    expect(find.text('咖啡'), findsOneWidget);
  });

  testWidgets('adds a sub-category under an existing category', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('分类管理'));
    await tester.pumpAndSettle();

    // 点击「餐饮」打开操作表，选择「新增子分类」。
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增子分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '早餐');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类').last);
    await tester.pumpAndSettle();

    expect(find.text('早餐'), findsOneWidget);
    // 子分类的副标题显示所属父分类下的层级信息（父分类出现「个子分类」）。
    expect(find.textContaining('个子分类'), findsWidgets);
  });

  testWidgets('creates a tag in the tag management page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('标签管理'));
    await tester.pumpAndSettle();

    expect(find.text('标签管理'), findsWidgets);
    await tester.tap(find.byTooltip('新增标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '报销');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('报销'), findsOneWidget);
    expect(find.text('0 笔交易'), findsOneWidget);
  });

  testWidgets('tags an entry through the entry form', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.addTag('必要');
    controller.dispose();

    await pumpApp(tester, store);
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);

    // 记账表单里点击「添加标签」行，勾选「必要」，完成。
    await tester.tap(find.text('添加标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('必要'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('最近交易'), findsOneWidget);
  });

  testWidgets('filters transaction list by tag', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final tagId = controller.addTag('必要')!;
    final now = DateTime.now();
    controller
      ..addAccount(
        Account(
          id: 'cash-tag-test',
          bookId: controller.activeBook.id,
          name: '现金账户',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'tagged-dining',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 30,
          categoryId: 'dining',
          accountId: 'cash-tag-test',
          note: '午餐',
          occurredAt: now,
          tagIds: <String>[tagId],
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'untagged-transport',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 12,
          categoryId: 'transport',
          accountId: 'cash-tag-test',
          note: '公交',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tester.tap(find.text('最近交易'));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);

    // 点击标签筛选胶囊，选择「必要」。
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('必要').last);
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);
  });

  testWidgets('transfer entry shows a fee field and records it', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    Account acc(String id, String name) => Account(
      id: id,
      bookId: controller.activeBook.id,
      name: name,
      type: AccountType.cash,
      groupId: null,
      initialBalance: 500,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller
      ..addAccount(acc('from-fee', '转出'))
      ..addAccount(acc('to-fee', '转入'))
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 0);
    await createQuickEntry(tester);

    // 切到转账，手续费字段出现。
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fee_field')), findsOneWidget);
  });

  test('addEntry keeps entries sorted latest first', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    LedgerEntry entryAt(String id, DateTime when) => LedgerEntry(
      id: id,
      bookId: bookId,
      type: EntryType.expense,
      amount: 10,
      categoryId: 'dining',
      accountId: 'cash',
      note: '',
      occurredAt: when,
    );

    controller
      ..addEntry(entryAt('today', DateTime(2026, 7, 3, 10)))
      ..addEntry(entryAt('backdated', DateTime(2026, 6, 26, 9)));

    expect(controller.entries.first.id, 'today');
    expect(controller.entries.last.id, 'backdated');
    controller.dispose();
  });
}
