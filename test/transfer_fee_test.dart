import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  LedgerEntry transfer({required double amount, required double fee}) =>
      LedgerEntry(
        id: 't1',
        bookId: defaultLedgerBookId,
        type: EntryType.transfer,
        amount: amount,
        categoryId: 'transfer_out',
        accountId: 'from',
        toAccountId: 'to',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
        fee: fee,
      );

  test('accountDeltaForEntry 转出账户扣除金额+手续费，转入只加金额', () {
    final entry = transfer(amount: 100, fee: 3);
    expect(accountDeltaForEntry(entry, 'from'), -103);
    expect(accountDeltaForEntry(entry, 'to'), 100);
    expect(accountDeltaForEntry(entry, 'other'), 0);
  });

  test('同账户转账（转出=转入）净额为 −手续费，不吞掉入账', () {
    final entry = LedgerEntry(
      id: 'self',
      bookId: defaultLedgerBookId,
      type: EntryType.transfer,
      amount: 100,
      categoryId: 'transfer_out',
      accountId: 'a',
      toAccountId: 'a',
      note: '',
      occurredAt: DateTime(2026, 7, 4),
      fee: 3,
    );
    // 转出 -103 + 转入 +100 = -3（仅手续费），而非 -103。
    expect(accountDeltaForEntry(entry, 'a'), -3);
  });

  test('手续费影响账户余额，且不计入收支统计', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    Account acc(String id, String name) => Account(
      id: id,
      bookId: bookId,
      name: name,
      type: AccountType.cash,
      groupId: null,
      initialBalance: 1000,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller
      ..addAccount(acc('from', '转出'))
      ..addAccount(acc('to', '转入'))
      ..addEntry(transfer(amount: 200, fee: 5));

    final from = controller.accounts.firstWhere((a) => a.id == 'from');
    final to = controller.accounts.firstWhere((a) => a.id == 'to');
    // 转出 1000 - 200 - 5 = 795；转入 1000 + 200 = 1200。
    expect(controller.accountBalance(from), 795);
    expect(controller.accountBalance(to), 1200);
    controller.dispose();
  });

  test('手续费随导出/导入往返', () async {
    final source = await makeController();
    source.addEntry(transfer(amount: 100, fee: 2.5));
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    await target.importDataJson(backup);
    expect(target.entries.single.fee, 2.5);
    target.dispose();
  });
}
