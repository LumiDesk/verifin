import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/in_memory_ledger_repository.dart';
import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('Controller 状态变化统一使桌面小组件投影失效', () async {
    final controller = await makeController();
    var invalidations = 0;
    controller.onWidgetProjectionInvalidated = () => invalidations++;

    controller.setDefaultMonthlyBudget(123);
    expect(invalidations, 1);

    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime(2026, 8, 25),
      rateToBase: 7.2,
    );
    expect(invalidations, 2);
  });

  test('交易聚合保存返回稳定的校验失败原因', () async {
    final controller = await makeController();
    final result = await controller.saveEntryAggregateDraftResult(
      entry: LedgerEntry(
        id: 'invalid',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 0,
        accountAmount: null,
        baseAmount: 0,
        categoryId: 'dining',
        accountId: '',
        note: '',
        occurredAt: DateTime(2026, 8, 25),
      ),
      isNew: true,
    );

    expect(result, isA<EntrySaveValidationFailure>());
    expect(
      (result as EntrySaveValidationFailure).code,
      EntryValidationCode.invalidAmounts,
    );
  });

  test('seeds English defaults when system locale is not Chinese', () async {
    // 不经 makeController（它预置中文），模拟英文系统的全新首启动。
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: InMemoryLedgerRepository(),
      systemIsEnglish: true,
    );
    expect(controller.activeBook.name, 'Daily Ledger');
    expect(controller.categories.map((c) => c.label), contains('Dining'));
    expect(controller.profile.bio, 'Completely free · Own your data');
  });

  test('seeds Chinese defaults when locale preference is zh', () async {
    final controller = await makeController();
    expect(controller.activeBook.name, '日常账本');
    expect(controller.categories.map((c) => c.label), contains('餐饮'));
  });

  test('新增/编辑账户时名称去首尾空格', () async {
    final controller = await makeController();
    Account cash(String name) => Account(
      id: 'trim-test',
      bookId: controller.activeBook.id,
      name: name,
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );

    controller.addAccount(cash(' 现金 '));
    expect(
      controller.accounts.singleWhere((a) => a.id == 'trim-test').name,
      '现金',
    );

    controller.updateAccount(cash('招商银行　'));
    expect(
      controller.accounts.singleWhere((a) => a.id == 'trim-test').name,
      '招商银行',
    );
  });

  test(
    'deleting account with related entries removes touched transfers too',
    () async {
      final controller = await makeController();
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
      controller.addRefund(
        expenseId: 'delete-expense-test',
        amount: 2,
        accountId: card.id,
        initiatedAt: DateTime(2026, 7, 4),
        settledAt: DateTime(2026, 7, 5),
      );

      await controller.deleteAccountAndRelatedEntries(cash.id);

      expect(controller.accounts.map((account) => account.id), <String>[
        card.id,
      ]);
      expect(controller.entries.map((entry) => entry.id), <String>[
        'keep-income-test',
      ]);

      controller.dispose();
    },
  );

  test('跨表删除落库失败时保留 Controller 与仓储原状态', () async {
    final repository = _FailingReplaceRepository();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repository,
    );
    final account = Account(
      id: 'atomic-delete-account',
      bookId: controller.activeBook.id,
      name: '待删除账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller
      ..addAccount(account)
      ..addEntry(
        LedgerEntry(
          id: 'atomic-delete-entry',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 10,
          categoryId: 'dining',
          accountId: account.id,
          note: '',
          occurredAt: DateTime(2026, 8, 27),
        ),
      );
    await controller.waitForPendingWrites();
    repository.failReplace = true;

    expect(await controller.deleteAccountAndRelatedEntries(account.id), isNull);
    expect(controller.accounts.any((item) => item.id == account.id), isTrue);
    expect(
      controller.entries.any((item) => item.id == 'atomic-delete-entry'),
      isTrue,
    );
    expect(
      (await repository.loadAccounts()).any((item) => item.id == account.id),
      isTrue,
    );
    expect(
      (await repository.loadEntries()).any(
        (item) => item.id == 'atomic-delete-entry',
      ),
      isTrue,
    );
    controller.dispose();
  });

  test(
    'transfer entries update both account balances without income expense',
    () async {
      final source = await makeController();
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
      final target = await makeController();
      target.importDataJson(backup);

      expect(target.entries.single.toAccountId, card.id);
      expect(target.accountBalance(target.accounts.first), 420);
      expect(target.accountBalance(target.accounts.last), 180);

      source.dispose();
      target.dispose();
    },
  );

  test('account balance normalizes floating-point residue to zero', () async {
    final controller = await makeController();
    final account = Account(
      id: 'floating-zero-account',
      bookId: controller.activeBook.id,
      name: '零钱账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0.3,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller
      ..addAccount(account)
      ..addEntry(
        LedgerEntry(
          id: 'floating-zero-expense-1',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 0.1,
          categoryId: 'dining',
          accountId: account.id,
          note: '',
          occurredAt: DateTime(2026, 7, 3, 9),
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'floating-zero-expense-2',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 0.2,
          categoryId: 'dining',
          accountId: account.id,
          note: '',
          occurredAt: DateTime(2026, 7, 3, 10),
        ),
      );

    final balance = controller.accountBalance(account);
    expect(balance, 0);
    expect(balance.isNegative, isFalse);
    controller.dispose();
  });

  test('deleting a ledger book removes its asset view preferences', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.addLedgerBook('临时账本');
    final bookId = controller.activeBook.id;
    controller.toggleAssetSectionCollapsed(
      mode: AssetAccountViewMode.type,
      sectionId: 'cash',
    );
    expect(store.read('verifin.asset_section_collapsed.v1'), contains(bookId));

    controller.deleteLedgerBook(bookId);

    expect(
      store.read('verifin.asset_section_collapsed.v1'),
      isNot(contains(bookId)),
    );
    controller.dispose();
  });

  test(
    'rebase balance updates initial balance without a transaction',
    () async {
      final controller = await makeController();
      final account = Account(
        id: 'rebase-acc',
        bookId: controller.activeBook.id,
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 100,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      );
      controller.addAccount(account);

      controller.rebaseAccountBalance(account, 250);

      expect(controller.entries, isEmpty);
      expect(controller.accountBalance(controller.accounts.single), 250);
      expect(controller.accounts.single.initialBalance, 250);
      controller.dispose();
    },
  );
}

class _FailingReplaceRepository extends InMemoryLedgerRepository {
  bool failReplace = false;

  @override
  Future<void> replaceAllLedgerData(LedgerDataSnapshot snapshot) {
    if (failReplace) {
      throw StateError('simulated replace failure');
    }
    return super.replaceAllLedgerData(snapshot);
  }
}
