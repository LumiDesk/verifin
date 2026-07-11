import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

/// 退款关联条目（[EntryType.refund]）的模型层行为：跨账户到账、多笔部分退款、
/// 级联删除、删除退款恢复净额、明细排序、更新超额拦截。
void main() {
  useTestDatabases();

  Account account(String id, String bookId, double initial) => Account(
    id: id,
    bookId: bookId,
    name: id,
    type: AccountType.cash,
    groupId: null,
    initialBalance: initial,
    iconCode: 'cash',
    note: '',
    includeInAssets: true,
    hidden: false,
  );

  LedgerEntry expense(String bookId, {String id = 'e1', double amount = 100}) =>
      LedgerEntry(
        id: id,
        bookId: bookId,
        type: EntryType.expense,
        amount: amount,
        categoryId: 'dining',
        accountId: 'A',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
      );

  test('跨账户退款：原账户扣全额、到账账户单独入账', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addAccount(account('B', bookId, 500))
      ..addEntry(expense(bookId));

    final a = controller.accounts.firstWhere((x) => x.id == 'A');
    final b = controller.accounts.firstWhere((x) => x.id == 'B');
    expect(controller.accountBalance(a), 900); // 1000 − 100

    // 全额退款到另一个账户 B。
    controller.addRefund(
      expenseId: 'e1',
      amount: 100,
      accountId: 'B',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 6),
    );

    expect(controller.accountBalance(a), 900); // A 仍扣全额，不因退款回补
    expect(controller.accountBalance(b), 600); // 退款进 B：500 + 100
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 0);
    controller.dispose();
  });

  test('多笔部分退款：累计净额与剩余可退递减', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addEntry(expense(bookId));

    controller.addRefund(
      expenseId: 'e1',
      amount: 30,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 5),
    );
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 70);
    expect(controller.remainingRefundable('e1'), 70);

    controller.addRefund(
      expenseId: 'e1',
      amount: 20,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 6),
      settledAt: DateTime(2026, 7, 7),
    );
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 50);
    expect(controller.remainingRefundable('e1'), 50);
    expect(controller.refundsForEntry('e1').length, 2);
    controller.dispose();
  });

  test('删除原支出级联删除其退款条目', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addEntry(expense(bookId));
    controller.addRefund(
      expenseId: 'e1',
      amount: 40,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 5),
    );
    expect(controller.refundsForEntry('e1').length, 1);

    controller.deleteEntry('e1');
    expect(controller.entries.where((e) => e.id == 'e1'), isEmpty);
    expect(controller.refundsForEntry('e1'), isEmpty);
    // 退款条目也一并清掉（列表里没有任何退款残留）。
    expect(
      controller.entries.where((e) => e.type == EntryType.refund),
      isEmpty,
    );
    controller.dispose();
  });

  test('删除退款条目后原支出净额与余额恢复', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addEntry(expense(bookId));
    final a = controller.accounts.single;

    final refund = controller.addRefund(
      expenseId: 'e1',
      amount: 40,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 5),
    );
    expect(controller.accountBalance(a), 940);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 60);

    controller.deleteRefund(refund!.id);
    expect(controller.accountBalance(a), 900); // 回到只有支出的状态
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 100);
    controller.dispose();
  });

  test('refundsForEntry 按到账优先时间倒序（待到账用发起日）', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addEntry(expense(bookId));

    // 已到账，到账日 7/6。
    controller.addRefund(
      expenseId: 'e1',
      amount: 10,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 6),
    );
    // 待到账，发起日 7/10（更晚）。
    controller.addRefund(
      expenseId: 'e1',
      amount: 10,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 10),
    );

    final refunds = controller.refundsForEntry('e1');
    expect(refunds.length, 2);
    // 7/10（待到账）排在 7/6（已到账）前面。
    expect(refunds.first.isPendingRefund, isTrue);
    controller.dispose();
  });

  test('updateRefund 改金额受剩余可退约束（禁止超额）', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(account('A', bookId, 1000))
      ..addEntry(expense(bookId));

    final first = controller.addRefund(
      expenseId: 'e1',
      amount: 30,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 5),
    );
    controller.addRefund(
      expenseId: 'e1',
      amount: 40,
      accountId: 'A',
      initiatedAt: DateTime(2026, 7, 6),
      settledAt: DateTime(2026, 7, 7),
    );
    // 想把第一笔改到 80：剩余可退（不含本笔）= 100 − 40 = 60，截到 60。
    controller.updateRefund(first!.copyWith(amount: 80));
    final updated = controller
        .refundsForEntry('e1')
        .firstWhere((r) => r.id == first.id);
    expect(updated.amount, 60);
    expect(controller.remainingRefundable('e1'), 0);
    controller.dispose();
  });

  test('applyImportEntries：带退款标量的导入交易当场自愈成退款条目', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller.addAccount(account('A', bookId, 1000));
    // 模拟平台导入（如一木「退款」列）：一条带 refundedAmount 标量的支出。
    controller.applyImportEntries(
      entries: <LedgerEntry>[
        LedgerEntry(
          id: 'imp1',
          bookId: bookId,
          type: EntryType.expense,
          amount: 100,
          categoryId: 'dining',
          accountId: 'A',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
          refundedAmount: 30,
        ),
      ],
      candidateAccounts: const <Account>[],
      candidateCategories: const <Category>[],
    );
    // 标量当场迁成一条已到账退款条目，净额 = 70，余额 = 1000 − 100 + 30 = 930。
    final refunds = controller.refundsForEntry('imp1');
    expect(refunds.length, 1);
    expect(refunds.single.amount, 30);
    expect(refunds.single.settledAt, isNotNull);
    expect(controller.entries.firstWhere((e) => e.id == 'imp1').netAmount, 70);
    final a = controller.accounts.firstWhere((x) => x.id == 'A');
    expect(controller.accountBalance(a), 930);
    controller.dispose();
  });
}
