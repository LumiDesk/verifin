import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/series_math.dart';

Account _account(String id, {double initial = 0}) => Account(
  id: id,
  bookId: 'b',
  name: id,
  type: AccountType.cash,
  groupId: null,
  initialBalance: initial,
  iconCode: 'cash',
  note: '',
  includeInAssets: true,
  hidden: false,
);

LedgerEntry _expense(String id, double amount, String accountId, DateTime at) =>
    LedgerEntry(
      id: id,
      bookId: 'b',
      type: EntryType.expense,
      amount: amount,
      categoryId: 'food',
      accountId: accountId,
      note: '',
      occurredAt: at,
    );

void main() {
  test('逐笔结余按生效日累加，包含账户初始余额', () {
    final balances = accountBalanceAfterEntry(
      accounts: <Account>[_account('cash', initial: 1000)],
      entries: <LedgerEntry>[
        _expense('b', 40, 'cash', DateTime(2026, 6, 2)),
        _expense('a', 30, 'cash', DateTime(2026, 6, 1)),
      ],
    );

    expect(balances['a'], 970);
    expect(balances['b'], 930, reason: '按时间顺序累计，而不是按传入顺序');
  });

  test('转账同时更新两端账户，手续费由转出账户承担', () {
    final transfer = LedgerEntry(
      id: 't',
      bookId: 'b',
      type: EntryType.transfer,
      amount: 200,
      categoryId: 'transfer_out',
      accountId: 'a',
      toAccountId: 'b',
      note: '',
      occurredAt: DateTime(2026, 6, 3),
      fee: 2,
    );
    final balances = accountBalanceAfterEntry(
      accounts: <Account>[
        _account('a', initial: 1000),
        _account('b', initial: 0),
      ],
      entries: <LedgerEntry>[transfer],
    );

    expect(balances['t'], 798, reason: '转出账户扣 200 本金 + 2 手续费');
  });

  test('无账户的交易不产生逐笔结余', () {
    final balances = accountBalanceAfterEntry(
      accounts: <Account>[_account('cash', initial: 0)],
      entries: <LedgerEntry>[_expense('n', 10, '', DateTime(2026, 6, 4))],
    );

    expect(balances.containsKey('n'), isFalse);
  });

  test('退款只在到账后计入到账账户', () {
    final refund = LedgerEntry(
      id: 'r',
      bookId: 'b',
      type: EntryType.refund,
      amount: 50,
      categoryId: 'food',
      accountId: 'cash',
      note: '',
      occurredAt: DateTime(2026, 6, 1),
      settledAt: DateTime(2026, 6, 5),
      refundOf: 'e',
    );
    final balances = accountBalanceAfterEntry(
      accounts: <Account>[_account('cash', initial: 0)],
      entries: <LedgerEntry>[refund],
    );

    expect(balances['r'], 50);
  });
}
