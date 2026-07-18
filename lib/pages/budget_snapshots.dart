part of 'budget_pages.dart';

/// 周期状态标签。[cyclic]（自定义预算周期）时用「本期」措辞，自然月用「本月」。
String _budgetPeriodLabel(
  AppLocalizations l10n,
  int remainingDays,
  bool isPastMonth,
  bool isCurrentMonth, {
  required bool cyclic,
}) {
  if (isPastMonth) {
    return cyclic ? l10n.periodEnded : l10n.monthEnded;
  }
  if (isCurrentMonth) {
    return l10n.remainingDaysInclToday(remainingDays);
  }
  return cyclic
      ? l10n.periodTotalDays(remainingDays)
      : l10n.monthTotalDays(remainingDays);
}

(String, String, IconData) _budgetInsight({
  required AppLocalizations l10n,
  required double budget,
  required double expense,
  required double remaining,
  required double ratio,
  required int remainingDays,
}) {
  if (budget <= 0) {
    return (
      l10n.budgetTipNoneTitle,
      l10n.budgetTipNoneDesc,
      Icons.flag_outlined,
    );
  }
  if (remaining < 0) {
    return (
      l10n.budgetTipOverTitle,
      l10n.budgetTipOverDesc(formatAmount(remaining.abs())),
      Icons.warning_amber_rounded,
    );
  }
  if (ratio >= 0.85) {
    return (
      l10n.budgetTipNearTitle,
      l10n.budgetTipNearDesc(
        (ratio * 100).toStringAsFixed(0),
        formatAmount(remaining),
      ),
      Icons.error_outline,
    );
  }
  if (remainingDays > 0) {
    return (
      l10n.budgetTipOkTitle,
      l10n.budgetTipOkDesc(formatAmount(remaining / remainingDays)),
      Icons.check_circle_outline,
    );
  }
  return (
    l10n.budgetTipEndedTitle,
    l10n.budgetTipEndedDesc,
    Icons.event_available_outlined,
  );
}

class CategoryBudgetSnapshot {
  const CategoryBudgetSnapshot({
    required this.category,
    required this.spent,
    required this.budget,
    required this.previousSpent,
  });

  final Category category;
  final double spent;
  final double budget;
  final double previousSpent;

  bool get hasBudget => budget > 0;

  double get remaining => budget - spent;

  double get ratio => hasBudget ? spent / budget : 0;

  double get progress => hasBudget ? ratio.clamp(0, 1).toDouble() : 0;

  bool get overBudget => hasBudget && spent > budget;

  bool get nearLimit => hasBudget && !overBudget && ratio >= 0.85;

  bool get needsAttention => overBudget || nearLimit;
}

class BudgetMonthSnapshot {
  const BudgetMonthSnapshot({
    required this.month,
    required this.budget,
    required this.expense,
  });

  final DateTime month;
  final double budget;
  final double expense;

  double get remaining => budget - expense;

  double get ratio => budget <= 0 ? 0 : expense / budget;

  bool get overBudget => budget > 0 && expense > budget;
}

List<BudgetMonthSnapshot> _budgetMonthSnapshots({
  required VeriFinController controller,
  required DateTime anchor,
  required int count,
}) {
  return List<BudgetMonthSnapshot>.generate(count, (index) {
    final month = DateTime(anchor.year, anchor.month - count + 1 + index);
    // 每个键月的支出按其预算周期窗口聚合（自然月时窗口即该月）。
    final entries = entriesInWindow(
      controller.entries,
      controller.budgetWindow(month),
    );
    return BudgetMonthSnapshot(
      month: month,
      budget: controller.monthlyBudget(month),
      expense: sumByType(entries, EntryType.expense),
    );
  });
}

List<CategoryBudgetSnapshot> computeCategoryBudgetSnapshots({
  required VeriFinController controller,
  required DateTime month,
  required List<LedgerEntry> monthEntries,
  List<LedgerEntry> previousMonthEntries = const <LedgerEntry>[],
  // true 时快照的 budget 取「分类默认预算」（设置页编辑默认用）；否则取该键月的
  // 实际预算（单月覆盖 ?? 默认，总览展示用）。
  bool useDefaultBudget = false,
}) {
  // 多级分类按层级聚合：每笔支出计入其所属分类**及所有上级分类**，
  // 这样父分类的预算会包含其子分类的支出。
  final all = controller.categories;
  void accumulate(Map<String, double> into, List<LedgerEntry> source) {
    for (final entry in source.where(
      (entry) => entry.type == EntryType.expense,
    )) {
      final chain = <String>[
        entry.categoryId,
        ...ancestorIds(all, entry.categoryId),
      ];
      for (final id in chain) {
        into.update(
          id,
          (amount) => amount + entry.netAmount,
          ifAbsent: () => entry.netAmount,
        );
      }
    }
  }

  final spentByCategory = <String, double>{};
  accumulate(spentByCategory, monthEntries);
  final previousSpentByCategory = <String, double>{};
  accumulate(previousSpentByCategory, previousMonthEntries);

  final snapshots = controller
      .categoriesForType(EntryType.expense)
      .where((category) => category.id != 'balance_adjust_expense')
      .map(
        (category) => CategoryBudgetSnapshot(
          category: category,
          spent: spentByCategory[category.id] ?? 0,
          budget: useDefaultBudget
              ? controller.defaultCategoryBudget(category.id)
              : controller.categoryBudget(month, category.id),
          previousSpent: previousSpentByCategory[category.id] ?? 0,
        ),
      )
      .toList(growable: false);
  return snapshots..sort(_compareCategoryBudgetSnapshots);
}

CategoryBudgetSnapshot? topCategoryBudgetRisk(
  List<CategoryBudgetSnapshot> snapshots,
) {
  for (final snapshot in snapshots) {
    if (snapshot.needsAttention) {
      return snapshot;
    }
  }
  return null;
}

int _compareCategoryBudgetSnapshots(
  CategoryBudgetSnapshot a,
  CategoryBudgetSnapshot b,
) {
  final rankCompare = _categoryBudgetSortRank(
    a,
  ).compareTo(_categoryBudgetSortRank(b));
  if (rankCompare != 0) {
    return rankCompare;
  }
  final ratioCompare = b.ratio.compareTo(a.ratio);
  if (ratioCompare != 0) {
    return ratioCompare;
  }
  final spentCompare = b.spent.compareTo(a.spent);
  if (spentCompare != 0) {
    return spentCompare;
  }
  return a.category.label.compareTo(b.category.label);
}

int _categoryBudgetSortRank(CategoryBudgetSnapshot snapshot) {
  if (snapshot.overBudget) {
    return 0;
  }
  if (snapshot.nearLimit) {
    return 1;
  }
  if (snapshot.hasBudget) {
    return 2;
  }
  if (snapshot.spent > 0) {
    return 3;
  }
  return 4;
}

/// 与上一周期的支出差额标签。[cyclic] 时用「上期」措辞，自然月用「上月」。
String _expenseDeltaLabel(
  AppLocalizations l10n,
  double delta, {
  required bool cyclic,
}) {
  if (isZeroAmount(delta)) {
    return cyclic ? l10n.deltaFlatVsLastPeriod : l10n.deltaFlatVsLastMonth;
  }
  if (delta > 0) {
    return cyclic
        ? l10n.deltaMoreVsLastPeriod(formatAmount(delta))
        : l10n.deltaMoreVsLastMonth(formatAmount(delta));
  }
  return cyclic
      ? l10n.deltaLessVsLastPeriod(formatAmount(delta.abs()))
      : l10n.deltaLessVsLastMonth(formatAmount(delta.abs()));
}

String _usageDeltaLabel(AppLocalizations l10n, double delta) {
  final points = (delta.abs() * 100).toStringAsFixed(0);
  if (points == '0') {
    return l10n.usageFlat;
  }
  return delta > 0 ? l10n.usageUp(points) : l10n.usageDown(points);
}
