
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

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

  test('rebase balance updates initial balance without a transaction', () async {
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
  });
}
