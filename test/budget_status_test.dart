import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/budget_status.dart';
import 'package:verifin/app/models.dart';

Category _cat(String id, String label, {String? parentId}) => Category(
  id: id,
  label: label,
  type: EntryType.expense,
  iconCode: 'food',
  parentId: parentId,
);

LedgerEntry _expense(String id, double amount, String categoryId) =>
    LedgerEntry(
      id: id,
      bookId: 'b',
      type: EntryType.expense,
      amount: amount,
      categoryId: categoryId,
      accountId: 'acc',
      note: '',
      occurredAt: DateTime(2026, 6, 3),
    );

void main() {
  test('分类支出按自身与上级累计，父分类预算覆盖子分类', () {
    final status = computeBudgetStatus(
      windowEntries: <LedgerEntry>[_expense('a', 60, 'coffee')],
      previousWindowEntries: const <LedgerEntry>[],
      categories: <Category>[
        _cat('food', '餐饮'),
        _cat('coffee', '咖啡', parentId: 'food'),
      ],
      budget: 1000,
      budgetOf: (category) => category.id == 'food' ? 500 : 0,
      remainingDays: 10,
    );

    expect(status.expense, 60);
    expect(status.remaining, 940);
    final food = status.categories.firstWhere(
      (row) => row.categoryId == 'food',
    );
    expect(food.spent, 60, reason: '父分类的支出应包含子分类');
    expect(food.ratio, closeTo(0.12, 1e-9));
    expect(food.needsAttention, isFalse);
    final coffee = status.categories.firstWhere(
      (row) => row.categoryId == 'coffee',
    );
    expect(coffee.hasBudget, isFalse, reason: '未设置预算的分类不参与判定');
  });

  test('超支与接近上限进入需要关注，按剩余额度升序', () {
    final status = computeBudgetStatus(
      windowEntries: <LedgerEntry>[
        _expense('x', 600, 'a'),
        _expense('y', 90, 'b'),
      ],
      previousWindowEntries: const <LedgerEntry>[],
      categories: <Category>[_cat('a', 'A'), _cat('b', 'B')],
      budget: 1000,
      budgetOf: (_) => 100,
      remainingDays: 0,
    );

    expect(status.overBudget, isFalse, reason: '总预算未超');
    final attention = status.attention;
    expect(attention.map((row) => row.categoryId), <String>['a', 'b']);
    expect(attention.first.overBudget, isTrue);
    expect(attention.last.nearLimit, isTrue);
    expect(attention.last.overBudget, isFalse);
  });

  test('上一期支出用于对比，不混入本期', () {
    final status = computeBudgetStatus(
      windowEntries: <LedgerEntry>[_expense('x', 100, 'a')],
      previousWindowEntries: <LedgerEntry>[_expense('y', 250, 'a')],
      categories: <Category>[_cat('a', 'A')],
      budget: 0,
      budgetOf: (_) => 0,
      remainingDays: 5,
    );

    expect(status.expense, 100);
    expect(status.previousExpense, 250);
    expect(status.ratio, 0, reason: '未设预算时比例按 0 处理');
  });
}
