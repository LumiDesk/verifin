// 预算执行情况的纯计算：聚合某预算期的预算、支出与分类执行状态。
//
// 只做聚合与判定，不依赖 controller、不做本地化——文案与取色由调用方决定。
// AI 只读工具 `budgetStatus` 与预算页共用这里的口径；预算键月、单期覆盖等
// 由 controller 通过回调传入，避免两处各写一套 key 规则。

import 'category_tree.dart';
import 'ledger_math.dart';
import 'models.dart';

/// 单个分类在某预算期的执行情况。
class BudgetStatusCategoryRow {
  const BudgetStatusCategoryRow({
    required this.categoryId,
    required this.label,
    required this.spent,
    required this.budget,
  });

  final String categoryId;
  final String label;

  /// 该分类及其所有子分类的支出合计（本位币净额）。
  final double spent;

  /// 该期的分类预算（单期覆盖优先，否则默认值）；未设置为 0。
  final double budget;

  bool get hasBudget => budget > 0;

  double get remaining => budget - spent;

  double get ratio => hasBudget ? spent / budget : 0;

  bool get overBudget => hasBudget && spent > budget;

  bool get nearLimit => hasBudget && !overBudget && ratio >= 0.85;

  bool get needsAttention => overBudget || nearLimit;
}

/// 某预算期的执行摘要。
class BudgetStatusSummary {
  const BudgetStatusSummary({
    required this.budget,
    required this.expense,
    required this.previousExpense,
    required this.remainingDays,
    required this.categories,
  });

  final double budget;
  final double expense;
  final double previousExpense;

  /// 本期剩余天数（含今天）。
  final int remainingDays;
  final List<BudgetStatusCategoryRow> categories;

  double get remaining => budget - expense;

  double get ratio => budget > 0 ? expense / budget : 0;

  bool get overBudget => budget > 0 && expense > budget;

  /// 需要关注（超支或已用 ≥ 85%）的分类，按超支幅度降序。
  List<BudgetStatusCategoryRow> get attention {
    final rows = categories.where((row) => row.needsAttention).toList();
    rows.sort((a, b) => a.remaining.compareTo(b.remaining));
    return rows;
  }
}

/// 聚合 [window] 这一预算期的执行情况。
///
/// [windowEntries] / [previousWindowEntries] 是本期与上一期的交易（调用方按预算窗口取好）；
/// [budgetOf] 返回某分类在该期的预算（单期覆盖 ?? 默认），由 controller 决定口径。
BudgetStatusSummary computeBudgetStatus({
  required List<LedgerEntry> windowEntries,
  required List<LedgerEntry> previousWindowEntries,
  required List<Category> categories,
  required double budget,
  required double Function(Category category) budgetOf,
  required int remainingDays,
}) {
  final spentByCategory = _spentByCategory(windowEntries, categories);
  final rows = categories
      .where((category) => category.type == EntryType.expense)
      .where((category) => category.id != 'balance_adjust_expense')
      .map(
        (category) => BudgetStatusCategoryRow(
          categoryId: category.id,
          label: category.label,
          spent: spentByCategory[category.id] ?? 0,
          budget: budgetOf(category),
        ),
      )
      .toList(growable: false);
  return BudgetStatusSummary(
    budget: budget,
    expense: sumByType(windowEntries, EntryType.expense),
    previousExpense: sumByType(previousWindowEntries, EntryType.expense),
    remainingDays: remainingDays,
    categories: rows,
  );
}

/// 按「自身 + 所有上级分类」累计支出，父分类的预算因此覆盖其子分类。
Map<String, double> _spentByCategory(
  List<LedgerEntry> entries,
  List<Category> categories,
) {
  final index = categoryIndex(categories);
  final result = <String, double>{};
  for (final entry in entries) {
    if (entry.type != EntryType.expense) {
      continue;
    }
    final chain = <String>[
      entry.categoryId,
      ...ancestorIdsFrom(index, entry.categoryId),
    ];
    for (final id in chain) {
      result.update(
        id,
        (value) => value + entry.netAmount,
        ifAbsent: () => entry.netAmount,
      );
    }
  }
  return result;
}
