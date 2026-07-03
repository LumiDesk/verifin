import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/ledger_math.dart';
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

  testWidgets('opens account icon picker from add account page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_icon_select_field')));
    await tester.pumpAndSettle();

    expect(find.text('选择账户图标'), findsOneWidget);
    expect(find.text('通用图标'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text('花呗'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('花呗'), findsOneWidget);
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
    expect(find.text('近 6 月趋势'), findsOneWidget);

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

  testWidgets('filters transaction list by search and account', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = VeriFinController(store);
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

    await tester.pumpWidget(VeriFinApp(store: store));
    await tester.tap(find.text('今日交易'));
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

  testWidgets('starts with no default accounts', (WidgetTester tester) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);

    expect(find.text('支付宝'), findsNothing);
    expect(find.text('微信'), findsNothing);
    expect(find.text('花呗'), findsNothing);
  });

  testWidgets('shows empty state on account groups page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理分组'));
    await tester.pumpAndSettle();

    expect(find.text('还没有账户分组'), findsOneWidget);
    expect(find.text('点击右上角加号创建分组，用来整理不同账户。'), findsOneWidget);
  });

  testWidgets('shows accounts by type in the assets page by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '现金账户');

    expect(find.text('网络支付'), findsOneWidget);
    expect(find.text('现金账户'), findsOneWidget);
  });

  testWidgets('switches asset account view and persists collapsed sections', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = VeriFinController(store);
    controller
      ..addAccount(
        Account(
          id: 'asset-view-alipay',
          bookId: controller.activeBook.id,
          name: '支付宝账户',
          type: AccountType.onlinePayment,
          groupId: null,
          initialBalance: 0,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..dispose();

    await tester.pumpWidget(VeriFinApp(store: store));
    await tapBottomTab(tester, 1);

    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换为分类视图'));
    await tester.pumpAndSettle();

    expect(find.text('未分组'), findsOneWidget);
    expect(find.text('支付宝账户'), findsOneWidget);

    await tester.tap(find.text('未分组'));
    await tester.pumpAndSettle();
    expect(find.text('支付宝账户'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(VeriFinApp(store: store));
    await tapBottomTab(tester, 1);

    expect(find.text('未分组'), findsOneWidget);
    expect(find.text('支付宝账户'), findsNothing);
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
      ..setHapticsEnabled(false)
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
    expect(target.hapticsEnabled, isFalse);
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

  test('persists asset account view mode collapse and manual ordering', () {
    final store = LocalKeyValueStore();
    final source = VeriFinController(store);
    final first = Account(
      id: 'order-a',
      bookId: source.activeBook.id,
      name: 'A 账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final second = Account(
      id: 'order-b',
      bookId: source.activeBook.id,
      name: 'B 账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    source
      ..addAccount(first)
      ..addAccount(second)
      ..toggleAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
      );
    final sorted = source.sortedAccountsForAssetSection(
      mode: AssetAccountViewMode.type,
      sectionId: AccountType.cash.name,
      accounts: source.accounts,
    );
    source
      ..reorderAssetAccounts(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
        accounts: sorted,
        oldIndex: 0,
        newIndex: 1,
      )
      ..dispose();

    final target = VeriFinController(store);
    final targetSorted = target.sortedAccountsForAssetSection(
      mode: AssetAccountViewMode.type,
      sectionId: AccountType.cash.name,
      accounts: target.accounts,
    );

    expect(target.assetAccountViewMode, AssetAccountViewMode.type);
    expect(
      target.isAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
      ),
      isTrue,
    );
    expect(targetSorted.map((account) => account.id), <String>[
      'order-b',
      'order-a',
    ]);

    target.dispose();
  });

  test('persists manual asset section ordering', () {
    final store = LocalKeyValueStore();
    final source = VeriFinController(store);
    const sections = <String>['onlinePayment', 'creditCard', 'debitCard'];
    source
      ..reorderAssetSections<String>(
        mode: AssetAccountViewMode.type,
        sections: sections,
        idOf: (section) => section,
        oldIndex: 0,
        newIndex: 2,
      )
      ..dispose();

    final target = VeriFinController(store);
    final sorted = target.sortedAssetSections<String>(
      mode: AssetAccountViewMode.type,
      sections: sections,
      idOf: (section) => section,
    );

    expect(sorted, <String>['creditCard', 'debitCard', 'onlinePayment']);

    target.dispose();
  });

  test('sample backup imports into controller', () {
    final rawJson = File(
      'docs/dev/verifin-sample-backup.json',
    ).readAsStringSync();
    final controller = VeriFinController(LocalKeyValueStore());

    controller.importDataJson(rawJson);

    expect(controller.accounts.length, greaterThanOrEqualTo(8));
    expect(controller.entries.length, greaterThanOrEqualTo(20));
    expect(controller.accountGroups.length, greaterThanOrEqualTo(4));
    expect(
      controller.categories.any((category) => category.id == 'coffee'),
      isTrue,
    );
    expect(
      controller.categoryBudget(DateTime(2026, 7), 'dining'),
      greaterThan(0),
    );
    expect(
      controller.isAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.investment.name,
      ),
      isTrue,
    );
    expect(
      controller
          .sortedAssetSections<String>(
            mode: AssetAccountViewMode.type,
            sections: AccountType.values.map((type) => type.name).toList(),
            idOf: (section) => section,
          )
          .first,
      AccountType.onlinePayment.name,
    );

    controller.dispose();
  });

  test(
    'deleting account with related entries removes touched transfers too',
    () {
      final controller = VeriFinController(LocalKeyValueStore());
      final cash = Account(
        id: 'delete-cash-test',
        bookId: controller.activeBook.id,
        name: '现金账户',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      final card = Account(
        id: 'delete-card-test',
        bookId: controller.activeBook.id,
        name: '银行卡',
        type: AccountType.debitCard,
        groupId: null,
        initialBalance: 0,
        iconCode: 'bank',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      controller
        ..addAccount(cash)
        ..addAccount(card)
        ..addEntry(
          LedgerEntry(
            id: 'delete-expense-test',
            bookId: controller.activeBook.id,
            type: EntryType.expense,
            amount: 12,
            categoryId: 'dining',
            accountId: cash.id,
            note: '现金消费',
            occurredAt: DateTime(2026, 7, 3, 9),
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 'delete-transfer-test',
            bookId: controller.activeBook.id,
            type: EntryType.transfer,
            amount: 30,
            categoryId: 'transfer_out',
            accountId: cash.id,
            toAccountId: card.id,
            note: '转入银行卡',
            occurredAt: DateTime(2026, 7, 3, 10),
          ),
        )
        ..addEntry(
          LedgerEntry(
            id: 'keep-income-test',
            bookId: controller.activeBook.id,
            type: EntryType.income,
            amount: 100,
            categoryId: 'salary',
            accountId: card.id,
            note: '工资',
            occurredAt: DateTime(2026, 7, 3, 11),
          ),
        );

      controller.deleteAccountAndRelatedEntries(cash.id);

      expect(controller.accounts.map((account) => account.id), <String>[
        card.id,
      ]);
      expect(controller.entries.map((entry) => entry.id), <String>[
        'keep-income-test',
      ]);

      controller.dispose();
    },
  );

  test(
    'transfer entries update both account balances without income expense',
    () {
      final source = VeriFinController(LocalKeyValueStore());
      final cash = Account(
        id: 'transfer-cash-test',
        bookId: source.activeBook.id,
        name: '现金账户',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 500,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      final card = Account(
        id: 'transfer-card-test',
        bookId: source.activeBook.id,
        name: '银行卡',
        type: AccountType.debitCard,
        groupId: null,
        initialBalance: 100,
        iconCode: 'bank',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      source
        ..addAccount(cash)
        ..addAccount(card)
        ..addEntry(
          LedgerEntry(
            id: 'transfer-entry-test',
            bookId: source.activeBook.id,
            type: EntryType.transfer,
            amount: 80,
            categoryId: 'transfer_out',
            accountId: cash.id,
            toAccountId: card.id,
            note: '转入银行卡',
            occurredAt: DateTime(2026, 7, 3, 10),
          ),
        );

      expect(source.accountBalance(cash), 420);
      expect(source.accountBalance(card), 180);
      expect(sumByType(source.entries, EntryType.expense), 0);
      expect(sumByType(source.entries, EntryType.income), 0);

      final backup = source.exportDataJson();
      final target = VeriFinController(LocalKeyValueStore());
      target.importDataJson(backup);

      expect(target.entries.single.toAccountId, card.id);
      expect(target.accountBalance(target.accounts.first), 420);
      expect(target.accountBalance(target.accounts.last), 180);

      source.dispose();
      target.dispose();
    },
  );
}
