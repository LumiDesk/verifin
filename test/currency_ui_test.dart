import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/assets_pages.dart';
import 'package:verifin/pages/currency_rates_page.dart';
import 'package:verifin/pages/entry_detail_page.dart';
import 'package:verifin/pages/home_page.dart';
import 'package:verifin/pages/ledger_books_page.dart';
import 'package:verifin/pages/recurring_page.dart';
import 'package:verifin/pages/sheets.dart';
import 'package:verifin/pages/transaction_detail_page.dart';

import 'support/in_memory_ledger_repository.dart';
import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> pumpPage(
    WidgetTester tester,
    VeriFinController controller,
    Widget page,
  ) {
    return tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: page),
      ),
    );
  }

  testWidgets('货币选择器支持按代码和名称搜索', (tester) async {
    CurrencyDefinition? selected;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selected = await showCurrencyPickerSheet(
                  context: context,
                  title: '选择货币',
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('currency_search_field')),
      'US Dollar',
    );
    await tester.pump();
    expect(find.text('USD'), findsOneWidget);
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    expect(selected?.code, 'USD');
  });

  testWidgets('新建账本同时选择本位币', (tester) async {
    final controller = await makeController();
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
    await pumpPage(tester, controller, const LedgerBooksPage());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ledger_book_name_field')),
      '美元账本',
    );
    await tester.tap(find.textContaining('CNY ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_book_save_button')));
    await tester.pumpAndSettle();

    expect(controller.activeBook.name, '美元账本');
    expect(controller.activeBook.baseCurrencyCode, 'USD');
    expect(find.textContaining('0 笔交易 · USD'), findsOneWidget);
  });

  testWidgets('账本行使用锚点菜单展示管理操作和禁用原因', (tester) async {
    final controller = await makeController();
    await pumpPage(tester, controller, const LedgerBooksPage());

    await tester.tap(find.byTooltip('账本操作'));
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('账本本位币'), findsOneWidget);
    expect(find.text('CNY'), findsOneWidget);
    expect(find.text('默认账本不可删除'), findsOneWidget);
  });

  testWidgets('新增账户可选择币种并按 minor unit 保存余额', (tester) async {
    final controller = await makeController();
    await pumpPage(tester, controller, const AddAccountPage());

    await tester.enterText(find.byType(TextFormField).first, '日元现金');
    await tester.tap(find.byKey(const Key('account_currency_select_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_JPY')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '12.7');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(controller.accounts.single.currencyCode, 'JPY');
    expect(controller.accounts.single.initialBalance, 13);
  });

  testWidgets('汇率管理页可保存十位精度的本地汇率', (tester) async {
    final controller = await makeController();
    await pumpPage(tester, controller, const CurrencyRatesPage());

    await tester.tap(find.byTooltip('添加汇率'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    for (final key in <String>['7', '.', '1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('number_key_$key')));
    }
    await tester.pump();
    expect(find.text('7.123456'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('number_pad_ok')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('汇率已保存'), findsOneWidget);
    expect(controller.exchangeRates.single.currencyCode, 'USD');
    expect(controller.exchangeRates.single.rateToBase, 7.123456);
    await tester.pumpAndSettle();
    expect(find.text('1 USD = 7.1235 CNY'), findsOneWidget);
    expect(find.textContaining('应用不会联网'), findsNothing);
  });

  testWidgets('汇率说明从页头问号打开且不再常驻显示', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await pumpPage(tester, controller, const CurrencyRatesPage());

    expect(find.textContaining('应用不会联网'), findsNothing);
    await tester.tap(find.byTooltip('汇率说明'));
    await tester.pumpAndSettle();

    expect(find.text('汇率说明'), findsOneWidget);
    expect(find.textContaining('应用不会联网'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.textContaining('应用不会联网'), findsNothing);
  });

  testWidgets('汇率历史行使用锚点菜单提供编辑和删除', (tester) async {
    final controller = await makeController();
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime.now(),
      rateToBase: 7.2,
    );
    await pumpPage(
      tester,
      controller,
      const CurrencyRateHistoryPage(currencyCode: 'USD'),
    );

    await tester.tap(find.byTooltip('USD 汇率历史'));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('旧账本从货币页完成一次性无换算重解释', (tester) async {
    final repository = InMemoryLedgerRepository();
    await repository.saveBooks(<LedgerBook>[
      LedgerBook(
        id: defaultLedgerBookId,
        name: '旧账本',
        createdAt: DateTime(2024),
        isDefault: true,
        currencySetupStatus: CurrencySetupStatus.legacyUnconfirmed,
      ),
    ]);
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repository,
    );
    await pumpPage(tester, controller, const CurrencyRatesPage());
    await tester.pumpAndSettle();

    expect(find.text('确认现有金额的币种'), findsWidgets);
    await tester.tap(find.text('现有金额其实是其他币种'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency_option_USD')));
    await tester.pumpAndSettle();
    expect(find.textContaining('所有数值保持不变'), findsOneWidget);
    await tester.tap(find.text('确认并应用'));
    await tester.pumpAndSettle();

    expect(controller.activeBook.baseCurrencyCode, 'USD');
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
  });

  testWidgets('外币普通交易同时保存原币、账户金额和冻结本位币金额', (tester) async {
    final controller = await makeController();
    final rateDate = DateTime.now();
    controller.addAccount(
      Account(
        id: 'usd-cash',
        bookId: controller.activeBook.id,
        name: '美元现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 100,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: 'USD',
      ),
    );
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: rateDate,
      rateToBase: 7.2,
    );
    await pumpPage(
      tester,
      controller,
      const EntryDetailPage(initialAmount: 10, initialAccountId: 'usd-cash'),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('entry_currency_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('entry_currency_button')),
        matching: find.text('USD'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('entry_base_amount')), findsOneWidget);
    expect(find.text('72 ¥'), findsOneWidget);
    expect(find.textContaining(currencyDateKey(rateDate)), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save_entry_button')));
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    final saved = controller.entries.single;
    expect(saved.amount, 10);
    expect(saved.currencyCode, 'USD');
    expect(saved.accountAmount, 10);
    expect(saved.baseAmount, 72);
    expect(saved.conversionSource, ConversionSource.rateTable);
  });

  testWidgets('跨币种转账显示并保存两端真实金额', (tester) async {
    final controller = await makeController();
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: controller.activeBook.id,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addAccount(
        Account(
          id: 'cny-cash',
          bookId: controller.activeBook.id,
          name: '人民币现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      );
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime.now(),
      rateToBase: 7.2,
    );
    await pumpPage(
      tester,
      controller,
      const EntryDetailPage(initialAmount: 10, initialAccountId: 'usd-cash'),
    );
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('entry_to_account_amount')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('entry_to_account_amount')), findsOneWidget);
    expect(find.text('72 ¥'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save_entry_button')));
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    final saved = controller.entries.single;
    expect(saved.type, EntryType.transfer);
    expect(saved.currencyCode, 'USD');
    expect(saved.accountAmount, 10);
    expect(saved.toAccountAmount, 72);
    expect(saved.baseAmount, 0);
  });

  testWidgets('收支统计按本位币聚合外币交易并标明单位', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'usd-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 10,
          currencyCode: 'USD',
          accountAmount: 10,
          baseAmount: 72,
          conversionSource: ConversionSource.manual,
          categoryId: 'dining',
          accountId: 'usd-cash',
          note: '',
          occurredAt: DateTime.now(),
        ),
      );

    await pumpPage(tester, controller, const IncomeExpenseStatsPage());

    expect(find.text('单位：¥'), findsOneWidget);
    expect(find.text('-72'), findsAtLeastNWidgets(2));
    expect(find.text('-10'), findsNothing);
  });

  testWidgets('历史外币交易只改日期时保持冻结金额', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'usd-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 10,
          currencyCode: 'USD',
          accountAmount: 10,
          baseAmount: 72,
          conversionSource: ConversionSource.manual,
          categoryId: 'dining',
          accountId: 'usd-cash',
          note: '',
          occurredAt: DateTime(2026, 8, 1, 12),
        ),
      );
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime(2026, 8, 2),
      rateToBase: 9,
    );
    await tester.binding.setSurfaceSize(const Size(460, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      controller,
      const TransactionDetailPage(entryId: 'usd-expense'),
    );

    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final saved = controller.entries.singleWhere(
      (entry) => entry.id == 'usd-expense',
    );
    expect(saved.occurredAt.day, 2);
    expect(saved.accountAmount, 10);
    expect(saved.baseAmount, 72);
    expect(saved.conversionSource, ConversionSource.manual);
  });

  testWidgets('手工结算交易改原币金额时保持既有结算比例', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 0,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'usd-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 10,
          currencyCode: 'USD',
          accountAmount: 10,
          baseAmount: 72,
          conversionSource: ConversionSource.manual,
          categoryId: 'dining',
          accountId: 'usd-cash',
          note: '',
          occurredAt: DateTime(2026, 8, 1),
        ),
      );
    await tester.binding.setSurfaceSize(const Size(460, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      controller,
      const TransactionDetailPage(entryId: 'usd-expense'),
    );

    await tester.tap(find.text('-10').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number_key_C')));
    await tester.tap(find.byKey(const Key('number_key_2')));
    await tester.tap(find.byKey(const Key('number_key_0')));
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final saved = controller.entries.singleWhere(
      (entry) => entry.id == 'usd-expense',
    );
    expect(saved.amount, 20);
    expect(saved.accountAmount, 20);
    expect(saved.baseAmount, 144);
    expect(saved.conversionSource, ConversionSource.manual);
  });

  testWidgets('已有退款的支出点击原币时解释锁定原因', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'usd-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 10,
          currencyCode: 'USD',
          accountAmount: 10,
          baseAmount: 72,
          conversionSource: ConversionSource.manual,
          categoryId: 'dining',
          accountId: 'usd-cash',
          note: '',
          occurredAt: DateTime.now(),
        ),
      )
      ..addRefund(
        expenseId: 'usd-expense',
        amount: 5,
        accountId: 'usd-cash',
        initiatedAt: DateTime.now(),
        settledAt: DateTime.now(),
        accountAmount: 5,
        baseAmount: 36,
      );
    await tester.binding.setSurfaceSize(const Size(460, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      controller,
      const TransactionDetailPage(entryId: 'usd-expense'),
    );

    await tester.tap(find.byKey(const Key('transaction_currency_field')));
    await tester.pump();

    expect(find.text('交易已有退款，原币不可修改。请先处理关联退款。'), findsOneWidget);
  });

  testWidgets('外币退款锁定原币并分别保存到账与本位币冲抵额', (tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-cash',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addAccount(
        Account(
          id: 'cny-cash',
          bookId: bookId,
          name: '人民币现金',
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
          id: 'usd-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 100,
          currencyCode: 'USD',
          accountAmount: 100,
          baseAmount: 720,
          conversionSource: ConversionSource.manual,
          categoryId: 'dining',
          accountId: 'usd-cash',
          note: '',
          occurredAt: DateTime.now(),
        ),
      );
    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      controller,
      const TransactionDetailPage(entryId: 'usd-expense'),
    );
    await tester.tap(find.text('添加退款'));
    await tester.pumpAndSettle();
    expect(find.textContaining('退款原币沿用原支出'), findsOneWidget);
    expect(find.text('100 \$'), findsWidgets);

    await tester.tap(find.text('到账账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('人民币现金'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('refund_account_amount')), findsOneWidget);
    expect(find.text('720 ¥'), findsAtLeastNWidgets(2));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final refund = controller.refundsForEntry('usd-expense').single;
    expect(refund.currencyCode, 'USD');
    expect(refund.amount, 100);
    expect(refund.accountId, 'cny-cash');
    expect(refund.accountAmount, 720);
    expect(refund.baseAmount, 720);
  });

  testWidgets('周期规则编辑器展示汇率策略与完整多币种金额', (tester) async {
    await tester.binding.setSurfaceSize(const Size(460, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller.addAccount(
      Account(
        id: 'usd-cash',
        bookId: bookId,
        name: '美元现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: 'USD',
      ),
    );
    final rule = RecurringRule(
      id: 'future-usd',
      bookId: bookId,
      type: EntryType.income,
      amount: 10,
      currencyCode: 'USD',
      accountAmount: 10,
      baseAmount: 72,
      ratePolicy: RecurringRatePolicy.latestAvailable,
      categoryId: 'salary',
      accountId: 'usd-cash',
      note: '',
      frequency: RecurringFrequency.monthly,
      startDate: DateTime(2030, 1, 1),
      nextRunDate: DateTime(2030, 1, 1),
    );
    expect(await controller.saveRecurringRuleDraft(rule, isNew: true), isTrue);
    await pumpPage(
      tester,
      controller,
      RecurringRuleEditPage(rule: controller.recurringRules.single),
    );

    expect(find.text('10 \$'), findsOneWidget);
    expect(find.text('72 ¥'), findsOneWidget);
    expect(find.text('每次使用最新本地汇率'), findsOneWidget);
    await tester.ensureVisible(find.text('每次使用最新本地汇率'));
    await tester.tap(find.text('每次使用最新本地汇率'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定当前金额'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(
      controller.recurringRules.single.ratePolicy,
      RecurringRatePolicy.fixedAmounts,
    );
  });
}
