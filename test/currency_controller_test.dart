import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/in_memory_ledger_repository.dart';

void main() {
  Future<VeriFinController> controllerWith(
    InMemoryLedgerRepository repository,
  ) {
    return VeriFinController.create(
      LocalKeyValueStore(),
      repository: repository,
    );
  }

  test('新账本有已确认的 CNY 本位币', () async {
    final controller = await controllerWith(InMemoryLedgerRepository());
    expect(controller.activeBook.baseCurrencyCode, 'CNY');
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
    expect(controller.activeBaseCurrency.nameZh, '人民币');
    controller.dispose();
  });

  test('汇率新增、同日覆盖、历史解析、重启载入与删除', () async {
    final repository = InMemoryLedgerRepository();
    final controller = await controllerWith(repository);
    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'USD',
        effectiveDate: DateTime(2026, 8, 1, 23),
        rateToBase: 7.1,
      ),
      isTrue,
    );
    final id = controller.exchangeRates.single.id;
    expect(controller.exchangeRates.single.effectiveDate, DateTime(2026, 8, 1));
    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'usd',
        effectiveDate: DateTime(2026, 8, 1),
        rateToBase: 7.2,
      ),
      isTrue,
    );
    expect(controller.exchangeRates, hasLength(1));
    expect(controller.exchangeRates.single.id, id);
    expect(controller.exchangeRates.single.rateToBase, 7.2);
    expect(controller.rateToBaseFor('USD', DateTime(2026, 8, 2)), 7.2);
    expect(controller.rateToBaseFor('USD', DateTime(2026, 7, 31)), isNull);
    expect(controller.rateToBaseFor('CNY', DateTime(1900)), 1);
    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'CNY',
        effectiveDate: DateTime(2026, 8, 1),
        rateToBase: 1,
      ),
      isFalse,
    );
    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'EUR',
        effectiveDate: DateTime(2026, 8, 1),
        rateToBase: double.nan,
      ),
      isFalse,
    );

    final restarted = await controllerWith(repository);
    expect(restarted.exchangeRates.single.id, id);
    expect(await restarted.deleteExchangeRate(id), isTrue);
    expect(restarted.exchangeRates, isEmpty);
    controller.dispose();
    restarted.dispose();
  });

  test('空账本可改本位币，有交易后锁定', () async {
    final controller = await controllerWith(InMemoryLedgerRepository());
    controller.addLedgerBook('旅行', baseCurrencyCode: 'USD');
    final bookId = controller.activeBook.id;
    controller.addAccount(
      Account(
        id: 'travel-cash',
        bookId: bookId,
        name: '现金',
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
    expect(
      await controller.changeEmptyLedgerBookBaseCurrency(bookId, 'JPY'),
      isTrue,
    );
    expect(controller.activeBook.baseCurrencyCode, 'JPY');
    expect(controller.accounts.single.currencyCode, 'JPY');

    controller.addEntry(
      LedgerEntry(
        id: 'travel-entry',
        bookId: bookId,
        type: EntryType.expense,
        amount: 100,
        currencyCode: 'JPY',
        accountAmount: 100,
        baseAmount: 100,
        categoryId: 'dining',
        accountId: 'travel-cash',
        note: '',
        occurredAt: DateTime(2026, 8, 1),
      ),
    );
    expect(controller.ledgerBookHasFinancialData(bookId), isTrue);
    expect(
      await controller.changeEmptyLedgerBookBaseCurrency(bookId, 'EUR'),
      isFalse,
    );
    expect(controller.activeBook.baseCurrencyCode, 'JPY');
    controller.dispose();
  });

  test('旧账本重解释在一个快照中改标签而不改任何数字', () async {
    final repository = InMemoryLedgerRepository();
    final book = LedgerBook(
      id: 'legacy',
      name: '旧账本',
      createdAt: DateTime(2025),
      isDefault: false,
      currencySetupStatus: CurrencySetupStatus.legacyUnconfirmed,
    );
    const account = Account(
      id: 'legacy-account',
      bookId: 'legacy',
      name: '旧账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 123.45,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
      creditLimit: 999.99,
    );
    final expense = LedgerEntry(
      id: 'legacy-expense',
      bookId: 'legacy',
      type: EntryType.expense,
      amount: 12.34,
      categoryId: 'dining',
      accountId: account.id,
      note: '',
      occurredAt: DateTime(2025, 1, 1),
      conversionSource: ConversionSource.legacy,
    );
    final transfer = LedgerEntry(
      id: 'legacy-transfer',
      bookId: 'legacy',
      type: EntryType.transfer,
      amount: 56.78,
      categoryId: 'transfer_out',
      accountId: account.id,
      toAccountId: 'legacy-target',
      note: '',
      occurredAt: DateTime(2025, 1, 2),
      conversionSource: ConversionSource.legacy,
    );
    final rule = RecurringRule(
      id: 'legacy-rule',
      bookId: 'legacy',
      type: EntryType.expense,
      amount: 88.88,
      categoryId: 'housing',
      accountId: account.id,
      note: '',
      frequency: RecurringFrequency.monthly,
      startDate: DateTime(2025, 1, 1),
      nextRunDate: DateTime(2025, 2, 1),
    );
    await repository.replaceAllLedgerData(
      LedgerDataSnapshot(
        books: <LedgerBook>[book],
        accounts: const <Account>[account],
        accountGroups: const <AccountGroup>[],
        categories: const <Category>[],
        tags: const <Tag>[],
        attachments: const <Attachment>[],
        entries: <LedgerEntry>[expense, transfer],
        recurringRules: <RecurringRule>[rule],
        monthlyBudgets: const <String, double>{'legacy:2025-01': 3000},
        categoryBudgets: const <String, double>{'legacy:2025-01:dining': 500},
        dailyBudgets: const <String, double>{'legacy': 100},
      ),
    );
    final controller = await VeriFinController.create(
      LocalKeyValueStore()..write('verifin.active_book.v1', 'legacy'),
      repository: repository,
    );

    expect(
      await controller.reinterpretLegacyLedgerBookCurrency('legacy', 'KWD'),
      isTrue,
    );
    expect(controller.activeBook.baseCurrencyCode, 'KWD');
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.confirmed,
    );
    expect(controller.accounts.single.currencyCode, 'KWD');
    expect(controller.accounts.single.initialBalance, 123.45);
    expect(controller.accounts.single.creditLimit, 999.99);
    final restoredExpense = controller.entries.singleWhere(
      (entry) => entry.id == expense.id,
    );
    expect(restoredExpense.amount, 12.34);
    expect(restoredExpense.accountAmount, 12.34);
    expect(restoredExpense.baseAmount, 12.34);
    expect(restoredExpense.currencyCode, 'KWD');
    final restoredTransfer = controller.entries.singleWhere(
      (entry) => entry.id == transfer.id,
    );
    expect(restoredTransfer.amount, 56.78);
    expect(restoredTransfer.toAccountAmount, 56.78);
    expect(restoredTransfer.baseAmount, 0);
    expect(controller.recurringRules.single.amount, 88.88);
    expect(controller.recurringRules.single.currencyCode, 'KWD');
    expect(controller.recurringRules.single.baseAmount, 88.88);
    expect(
      await controller.reinterpretLegacyLedgerBookCurrency('legacy', 'USD'),
      isFalse,
    );

    final restarted = await VeriFinController.create(
      LocalKeyValueStore()..write('verifin.active_book.v1', 'legacy'),
      repository: repository,
    );
    expect(restarted.activeBook.baseCurrencyCode, 'KWD');
    expect(
      restarted.entries.singleWhere((e) => e.id == expense.id).amount,
      12.34,
    );
    controller.dispose();
    restarted.dispose();
  });

  test('旧账本重解释持久化失败时内存保持原样', () async {
    final repository = _FailingReplaceRepository();
    await repository.replaceAllLedgerData(
      LedgerDataSnapshot(
        books: <LedgerBook>[
          LedgerBook(
            id: 'legacy',
            name: '旧账本',
            createdAt: DateTime(2025),
            isDefault: false,
            currencySetupStatus: CurrencySetupStatus.legacyUnconfirmed,
          ),
        ],
        accounts: const <Account>[],
        accountGroups: const <AccountGroup>[],
        categories: const <Category>[],
        tags: const <Tag>[],
        attachments: const <Attachment>[],
        entries: const <LedgerEntry>[],
        recurringRules: const <RecurringRule>[],
        monthlyBudgets: const <String, double>{},
        categoryBudgets: const <String, double>{},
        dailyBudgets: const <String, double>{},
      ),
    );
    final controller = await VeriFinController.create(
      LocalKeyValueStore()..write('verifin.active_book.v1', 'legacy'),
      repository: repository,
    );
    repository.failReplace = true;
    expect(
      await controller.reinterpretLegacyLedgerBookCurrency('legacy', 'USD'),
      isFalse,
    );
    expect(controller.activeBook.baseCurrencyCode, 'CNY');
    expect(
      controller.activeBook.currencySetupStatus,
      CurrencySetupStatus.legacyUnconfirmed,
    );
    controller.dispose();
  });

  test('核心数学分别使用冻结本位币金额和账户真实金额', () {
    final expense = LedgerEntry(
      id: 'expense',
      bookId: 'book',
      type: EntryType.expense,
      amount: 10,
      currencyCode: 'USD',
      accountAmount: 72.35,
      baseAmount: 72.35,
      refundedBaseAmount: 20,
      conversionSource: ConversionSource.manual,
      categoryId: 'dining',
      accountId: 'cny-card',
      note: '',
      occurredAt: DateTime(2026, 8, 1),
    );
    expect(signedAmount(expense), closeTo(-52.35, 0.000001));
    expect(accountDeltaForEntry(expense, 'cny-card'), -72.35);

    final transfer = LedgerEntry(
      id: 'transfer',
      bookId: 'book',
      type: EntryType.transfer,
      amount: 100,
      currencyCode: 'USD',
      accountAmount: 100,
      toAccountAmount: 720,
      baseAmount: 0,
      categoryId: 'transfer_out',
      accountId: 'usd-cash',
      toAccountId: 'cny-card',
      fee: 1,
      note: '',
      occurredAt: DateTime(2026, 8, 1),
    );
    expect(accountDeltaForEntry(transfer, 'usd-cash'), -101);
    expect(accountDeltaForEntry(transfer, 'cny-card'), 720);
    expect(signedAmount(transfer), 0);
  });

  test('混合币种资产缺汇率时不返回部分总额，补齐后按本位币估值', () async {
    final controller = await controllerWith(InMemoryLedgerRepository());
    final bookId = controller.activeBook.id;
    const cnyAccount = Account(
      id: 'cny-account',
      bookId: defaultLedgerBookId,
      name: '人民币账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'CNY',
    );
    const usdAccount = Account(
      id: 'usd-account',
      bookId: defaultLedgerBookId,
      name: '美元账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 10,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'USD',
    );
    controller.addAccount(cnyAccount);
    controller.addAccount(usdAccount);

    final missing = controller.accountBalancesInBase();
    expect(missing.completeTotal, isNull);
    expect(missing.missingCurrencyCodes, <String>{'USD'});
    expect(missing.affectedAccountIds, <String>{'usd-account'});
    expect(missing.amountsByAccountId['cny-account'], 100);

    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'USD',
        effectiveDate: DateTime(2020),
        rateToBase: 7.2,
      ),
      isTrue,
    );
    final complete = controller.accountBalancesInBase();
    expect(complete.isComplete, isTrue);
    expect(complete.amountsByAccountId['usd-account'], 72);
    expect(complete.completeTotal, 172);
    expect(controller.activeBook.id, bookId);
    controller.dispose();
  });

  test('退款原币限额与本位币净额缓存分开计算', () async {
    final controller = await controllerWith(InMemoryLedgerRepository());
    final expense = LedgerEntry(
      id: 'expense',
      bookId: controller.activeBook.id,
      type: EntryType.expense,
      amount: 100,
      currencyCode: 'USD',
      accountAmount: 100,
      baseAmount: 720,
      conversionSource: ConversionSource.manual,
      categoryId: 'dining',
      accountId: 'usd-account',
      note: '',
      occurredAt: DateTime(2026, 8, 1),
    );
    final refund = LedgerEntry(
      id: 'refund',
      bookId: controller.activeBook.id,
      type: EntryType.refund,
      amount: 50,
      currencyCode: 'USD',
      accountAmount: 370,
      baseAmount: 360,
      conversionSource: ConversionSource.manual,
      categoryId: 'dining',
      accountId: 'cny-account',
      note: '',
      occurredAt: DateTime(2026, 8, 2),
      refundOf: expense.id,
      settledAt: DateTime(2026, 8, 3),
    );
    expect(
      await controller.saveEntryAggregateDraft(
        entry: expense,
        isNew: true,
        refunds: <LedgerEntry>[refund],
      ),
      isTrue,
    );
    final saved = controller.entries.singleWhere(
      (entry) => entry.id == expense.id,
    );
    expect(saved.refundedBaseAmount, 360);
    expect(saved.netBaseAmount, 360);
    expect(accountDeltaForEntry(refund, 'cny-account'), 370);
    controller.dispose();
  });

  test('交易可与记住的当日汇率原子保存并覆盖同日记录', () async {
    final repository = InMemoryLedgerRepository();
    final controller = await controllerWith(repository);
    final occurredAt = DateTime(2026, 8, 18, 20, 30);
    final entry = LedgerEntry(
      id: 'foreign-cash',
      bookId: controller.activeBook.id,
      type: EntryType.expense,
      amount: 10,
      currencyCode: 'USD',
      accountAmount: null,
      baseAmount: 72.35,
      conversionSource: ConversionSource.manual,
      categoryId: 'dining',
      accountId: '',
      note: '',
      occurredAt: occurredAt,
    );

    expect(
      await controller.saveEntryAggregateDraft(
        entry: entry,
        isNew: true,
        rememberRateCurrencyCode: 'USD',
        rememberRateToBase: 7.235,
        rememberRateEffectiveDate: occurredAt,
      ),
      isTrue,
    );
    final rateId = controller.exchangeRates.single.id;
    expect(
      controller.exchangeRates.single.effectiveDate,
      DateTime(2026, 8, 18),
    );
    expect(controller.exchangeRates.single.rateToBase, 7.235);

    expect(
      await controller.saveEntryAggregateDraft(
        entry: entry.copyWith(baseAmount: 73),
        isNew: false,
        rememberRateCurrencyCode: 'USD',
        rememberRateToBase: 7.3,
        rememberRateEffectiveDate: occurredAt,
      ),
      isTrue,
    );
    expect(controller.exchangeRates.single.id, rateId);
    expect(controller.exchangeRates.single.rateToBase, 7.3);

    final restarted = await controllerWith(repository);
    expect(restarted.entries.single.baseAmount, 73);
    expect(restarted.exchangeRates.single.rateToBase, 7.3);
    controller.dispose();
    restarted.dispose();
  });
}

class _FailingReplaceRepository extends InMemoryLedgerRepository {
  bool failReplace = false;

  @override
  Future<void> replaceAllLedgerData(LedgerDataSnapshot snapshot) {
    if (failReplace) throw StateError('simulated replace failure');
    return super.replaceAllLedgerData(snapshot);
  }
}
