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

  test('netAmount 与统计按净额（退款冲抵缓存）', () {
    // refundedAmount 是「已到账退款」缓存，只驱动统计净额；账户余额按支出全额扣，
    // 退款的回款由独立退款条目单独入账，故 accountDelta 为全额 -100（非净额）。
    final entry = _expense(amount: 100, refunded: 30);
    expect(entry.netAmount, 70);
    expect(signedAmount(entry), -70);
    expect(accountDeltaForEntry(entry, 'cash'), -100);
    expect(sumByType(<LedgerEntry>[entry], EntryType.expense), 70);
  });

  test('已冲抵额超过金额时净额钳制为 0，不会变负被当成收入', () {
    // 场景：待报销支出 amount=200 refunded=150，之后金额被改小到 100。
    final entry = _expense(amount: 100, refunded: 150, reimbursable: true);
    expect(entry.netAmount, 0);
    expect(signedAmount(entry), 0); // 不会变成 +50「收入」
    // 账户余额按支出全额扣（-100）；净额缓存只影响统计、不影响余额。
    expect(accountDeltaForEntry(entry, 'cash'), -100);
    expect(sumByType(<LedgerEntry>[entry], EntryType.expense), 0);
  });

  test('损坏数据金额为负时净额兜底为 0，不抛异常', () {
    final entry = _expense(amount: -50, refunded: 0);
    expect(entry.netAmount, 0);
  });

  Account cashAccount(String bookId) => Account(
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
  );

  test('addRefund 已到账后账户余额与统计反映净额', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(cashAccount(bookId))
      ..addEntry(_expense(amount: 100).copyWith(bookId: bookId));

    final cash = controller.accounts.single;
    expect(controller.accountBalance(cash), 900);

    // 已到账退款 40 回到现金：1000 − 100 + 40 = 940；净支出 60。
    controller.addRefund(
      expenseId: 'e1',
      amount: 40,
      accountId: 'cash',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 6),
    );
    final expense = controller.entries.firstWhere((e) => e.id == 'e1');
    expect(expense.refundedAmount, 40);
    expect(expense.netAmount, 60);
    expect(controller.accountBalance(cash), 940);
    controller.dispose();
  });

  test('addRefund 金额上限为剩余可退（禁止超额）', () async {
    final controller = await makeController();
    controller.addEntry(
      _expense(amount: 50).copyWith(bookId: controller.activeBook.id),
    );
    final refund = controller.addRefund(
      expenseId: 'e1',
      amount: 999,
      accountId: 'cash',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 4),
    );
    expect(refund?.amount, 50); // 截到原金额
    expect(controller.remainingRefundable('e1'), 0);
    controller.dispose();
  });

  test('待到账退款不进余额/净额，标记到账后才生效', () async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(cashAccount(bookId))
      ..addEntry(_expense(amount: 100).copyWith(bookId: bookId));
    final cash = controller.accounts.single;

    // 待到账（settledAt 为 null）：余额仍 900、净额仍 100。
    final refund = controller.addRefund(
      expenseId: 'e1',
      amount: 40,
      accountId: 'cash',
      initiatedAt: DateTime(2026, 7, 4),
    );
    expect(controller.accountBalance(cash), 900);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 100);

    // 标记已到账：余额 940、净额 60。
    controller.setRefundSettled(refund!.id, DateTime(2026, 7, 6));
    expect(controller.accountBalance(cash), 940);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 60);
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

  test('退款作为关联条目随导出导入往返（净额与到账保留）', () async {
    final source = await makeController();
    final bookId = source.activeBook.id;
    source
      ..addEntry(
        _expense(amount: 80, reimbursable: true).copyWith(bookId: bookId),
      )
      ..addRefund(
        expenseId: 'e1',
        amount: 20,
        accountId: 'cash',
        initiatedAt: DateTime(2026, 7, 4),
        settledAt: DateTime(2026, 7, 6),
      );
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    final entry = target.entries.firstWhere((e) => e.id == 'e1');
    expect(entry.reimbursable, isTrue);
    expect(entry.refundedAmount, 20); // 缓存重算保留
    expect(entry.netAmount, 60);
    // 退款条目本身也往返保留，且仍为已到账。
    final refunds = target.refundsForEntry('e1');
    expect(refunds.length, 1);
    expect(refunds.single.amount, 20);
    expect(refunds.single.settledAt, isNotNull);
    target.dispose();
  });

  test('旧标量退款在导入时自愈迁移为已到账退款条目', () async {
    // 模拟旧版备份：支出只带 refundedAmount 标量、无关联退款条目。
    final legacy = await makeController();
    legacy.addEntry(
      _expense(
        amount: 80,
        refunded: 20,
        reimbursable: true,
      ).copyWith(bookId: legacy.activeBook.id),
    );
    final backup = legacy.exportDataJson();
    legacy.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    final entry = target.entries.firstWhere((e) => e.id == 'e1');
    expect(entry.netAmount, 60); // 迁移后净额不变
    final refunds = target.refundsForEntry('e1');
    expect(refunds.length, 1); // 标量已合成一条退款条目
    expect(refunds.single.amount, 20);
    expect(refunds.single.settledAt, isNotNull); // 历史退款视为已到账
    target.dispose();
  });
}
