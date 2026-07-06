import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/pages/transactions_pages.dart';

import 'support/test_harness.dart';

LedgerEntry _expense({
  required double amount,
  double refunded = 0,
  bool reimbursable = false,
  String account = 'cash',
}) => LedgerEntry(
  id: 'e1',
  bookId: defaultLedgerBookId,
  type: EntryType.expense,
  amount: amount,
  categoryId: 'dining',
  accountId: account,
  note: '',
  occurredAt: DateTime(2026, 7, 4),
  reimbursable: reimbursable,
  refundedAmount: refunded,
);

void main() {
  useTestDatabases();

  test('netAmount 与统计按净额（退款冲抵）', () {
    final entry = _expense(amount: 100, refunded: 30);
    expect(entry.netAmount, 70);
    expect(signedAmount(entry), -70);
    expect(accountDeltaForEntry(entry, 'cash'), -70);
    expect(sumByType(<LedgerEntry>[entry], EntryType.expense), 70);
  });

  test('setEntryRefundedAmount 冲抵后账户余额与月支出反映净额', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'cash',
          bookId: bookId,
          name: '现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 1000,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(_expense(amount: 100).copyWith(bookId: bookId));

    final cash = controller.accounts.single;
    expect(controller.accountBalance(cash), 900);

    controller.setEntryRefundedAmount('e1', 40);
    expect(controller.entries.single.refundedAmount, 40);
    // 退款 40 回到原账户：1000 - 100 + 40 = 940。
    expect(controller.accountBalance(cash), 940);
    controller.dispose();
  });

  test('setEntryRefundedAmount 上限为原金额', () async {
    final controller = await makeController();
    controller.addEntry(
      _expense(amount: 50).copyWith(bookId: controller.activeBook.id),
    );
    controller.setEntryRefundedAmount('e1', 999);
    expect(controller.entries.single.refundedAmount, 50);
    controller.dispose();
  });

  test('setEntryReimbursable 标记待报销', () async {
    final controller = await makeController();
    controller.addEntry(
      _expense(amount: 20).copyWith(bookId: controller.activeBook.id),
    );
    controller.setEntryReimbursable('e1', true);
    expect(controller.entries.single.reimbursable, isTrue);
    controller.dispose();
  });

  group('ReimbursementFilter.matches 筛选语义', () {
    test('all 匹配所有交易', () {
      expect(ReimbursementFilter.all.matches(_expense(amount: 10)), isTrue);
      expect(
        ReimbursementFilter.all.matches(
          _expense(amount: 10, reimbursable: true),
        ),
        isTrue,
      );
    });

    test('pending 仅匹配已标记且未完全冲抵', () {
      // 已标记、未冲抵：命中。
      expect(
        ReimbursementFilter.pending.matches(
          _expense(amount: 100, reimbursable: true),
        ),
        isTrue,
      );
      // 已标记、部分冲抵：仍有余额待报，命中。
      expect(
        ReimbursementFilter.pending.matches(
          _expense(amount: 100, reimbursable: true, refunded: 40),
        ),
        isTrue,
      );
      // 已标记、完全冲抵：不再命中。
      expect(
        ReimbursementFilter.pending.matches(
          _expense(amount: 100, reimbursable: true, refunded: 100),
        ),
        isFalse,
      );
      // 未标记：不命中。
      expect(
        ReimbursementFilter.pending.matches(_expense(amount: 100)),
        isFalse,
      );
    });

    test('reimbursed 匹配已有回款冲抵（含部分）', () {
      expect(
        ReimbursementFilter.reimbursed.matches(
          _expense(amount: 100, refunded: 30),
        ),
        isTrue,
      );
      expect(
        ReimbursementFilter.reimbursed.matches(
          _expense(amount: 100, refunded: 0, reimbursable: true),
        ),
        isFalse,
      );
    });
  });

  test('报销/退款字段随导出导入往返', () async {
    final source = await makeController();
    source.addEntry(
      _expense(
        amount: 80,
        refunded: 20,
        reimbursable: true,
      ).copyWith(bookId: source.activeBook.id),
    );
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    final entry = target.entries.single;
    expect(entry.reimbursable, isTrue);
    expect(entry.refundedAmount, 20);
    expect(entry.netAmount, 60);
    target.dispose();
  });
}
