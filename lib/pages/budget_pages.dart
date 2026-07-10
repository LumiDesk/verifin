import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/category_tree.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

part 'budget_snapshots.dart';
part 'budget_trend_chart.dart';
part 'budget_widgets.dart';

class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );

  // 收起的父分类 id（默认全部展开，收起后隐藏其子树）。
  final Set<String> _collapsedCategories = <String>{};

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final monthEntries = controller.entries
        .where((entry) => isInMonth(entry, _month))
        .toList(growable: false);
    final previousMonth = DateTime(_month.year, _month.month - 1);
    final previousMonthEntries = controller.entries
        .where((entry) => isInMonth(entry, previousMonth))
        .toList(growable: false);
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final previousMonthExpense = sumByType(
      previousMonthEntries,
      EntryType.expense,
    );
    final budget = controller.monthlyBudget(_month);
    final previousBudget = controller.monthlyBudget(previousMonth);
    final remaining = budget - monthExpense;
    final ratio = budget <= 0
        ? 0.0
        : (monthExpense / budget).clamp(0, 1).toDouble();
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final isPastMonth =
        _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
    final remainingDays = isPastMonth
        ? 0
        : isCurrentMonth
        ? (daysInMonth - now.day + 1).clamp(1, daysInMonth)
        : daysInMonth;
    final dailyAvailable = remainingDays <= 0 || remaining <= 0
        ? 0.0
        : remaining / remainingDays;
    final categoryBudgetSnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: _month,
      monthEntries: monthEntries,
      previousMonthEntries: previousMonthEntries,
    );
    final recentBudgetMonths = _budgetMonthSnapshots(
      controller: controller,
      anchor: _month,
      count: 6,
    );
    final budgetedCategoryCount = categoryBudgetSnapshots
        .where((snapshot) => snapshot.hasBudget)
        .length;
    final categoryBudgetRisk = topCategoryBudgetRisk(categoryBudgetSnapshots);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).budgetSettingsTitle,
                subtitle: AppLocalizations.of(context).yearMonth(_month),
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MonthSwitcher(
                      month: _month,
                      onPrevious: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 118,
                                height: 118,
                                child: CustomPaint(
                                  painter: BudgetRingPainter(
                                    value: ratio,
                                    trackColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.48),
                                    progressColor: budgetProgressColor(
                                      budget,
                                      remaining,
                                      ratio,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    AppLocalizations.of(context).budgetUsed,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.48),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    '${(budget <= 0 ? 0 : monthExpense / budget * 100).toStringAsFixed(0)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: budgetProgressColor(
                                            budget,
                                            remaining,
                                            ratio,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                remaining < 0
                                    ? AppLocalizations.of(
                                        context,
                                      ).budgetOverspentThisMonth
                                    : AppLocalizations.of(
                                        context,
                                      ).budgetAvailableThisMonth,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      remaining < 0
                                          ? formatExpenseAmount(remaining.abs())
                                          : formatAmount(remaining),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: remaining < 0
                                                ? veriExpense
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkResponse(
                                    onTap: _editMonthlyBudget,
                                    radius: 18,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: veriRoyal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _budgetPeriodLabel(
                                  AppLocalizations.of(context),
                                  remainingDays,
                                  isPastMonth,
                                  isCurrentMonth,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.52),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.45,
                      children: <Widget>[
                        _BudgetMetricTile(
                          label: AppLocalizations.of(
                            context,
                          ).budgetMonthExpense,
                          value: formatExpenseAmount(monthExpense),
                          icon: Icons.payments_outlined,
                          color: veriExpense,
                        ),
                        _BudgetMetricTile(
                          label: remaining < 0
                              ? AppLocalizations.of(
                                  context,
                                ).budgetOverAmountLabel
                              : AppLocalizations.of(
                                  context,
                                ).budgetRemainingQuota,
                          value: remaining < 0
                              ? formatExpenseAmount(remaining.abs())
                              : formatAmount(remaining),
                          icon: remaining < 0
                              ? Icons.warning_amber_rounded
                              : Icons.account_balance_wallet_outlined,
                          color: remaining < 0 ? veriExpense : veriIncome,
                        ),
                        _BudgetMetricTile(
                          label: AppLocalizations.of(
                            context,
                          ).budgetDailyRemaining,
                          value: formatAmount(dailyAvailable),
                          icon: Icons.today_outlined,
                          color: veriRoyal,
                        ),
                        _BudgetMetricTile(
                          label: AppLocalizations.of(context).budgetAmountLabel,
                          value: formatAmount(budget),
                          icon: Icons.flag_outlined,
                          color: veriBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DailyBudgetCard(
                dailyBudget: controller.dailyBudget(),
                todayExpense: dayExpenseTotal(controller.entries, now),
                onEdit: _editDailyBudget,
              ),
              const SizedBox(height: 10),
              _BudgetInsightCard(
                budget: budget,
                expense: monthExpense,
                remaining: remaining,
                ratio: ratio,
                remainingDays: remainingDays,
              ),
              const SizedBox(height: 10),
              _BudgetTrendCard(months: recentBudgetMonths),
              const SizedBox(height: 10),
              _BudgetHistoryCard(
                currentMonth: _month,
                previousMonth: previousMonth,
                currentExpense: monthExpense,
                previousExpense: previousMonthExpense,
                currentBudget: budget,
                previousBudget: previousBudget,
                onHistoryTap: _openBudgetHistory,
              ),
              if (categoryBudgetRisk != null ||
                  budgetedCategoryCount > 0) ...<Widget>[
                const SizedBox(height: 10),
                _CategoryBudgetAlertCard(
                  snapshot: categoryBudgetRisk,
                  budgetedCategoryCount: budgetedCategoryCount,
                ),
              ],
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).categoryBudgetTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).monthExpenseCategories,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.48),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (categoryBudgetSnapshots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).noExpenseCategories,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.48),
                                ),
                          ),
                        ),
                      )
                    else
                      ..._buildCategoryBudgetTree(
                        controller,
                        <String, CategoryBudgetSnapshot>{
                          for (final snapshot in categoryBudgetSnapshots)
                            snapshot.category.id: snapshot,
                        },
                        controller.rootCategoriesForType(EntryType.expense),
                        0,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  /// 递归渲染分类预算树：按分类的父子层级展开，父行显示已含子类的合计花销/预算，
  /// 可折叠子树；点任意行给该分类设预算。顺序与分类管理页一致（按存储顺序），
  /// 便于查找。[byId] 提供各分类的预算快照（父快照已聚合子类花销）。
  List<Widget> _buildCategoryBudgetTree(
    VeriFinController controller,
    Map<String, CategoryBudgetSnapshot> byId,
    List<Category> siblings,
    int depth,
  ) {
    final rows = <Widget>[];
    for (final category in siblings) {
      final snapshot = byId[category.id];
      if (snapshot == null) {
        continue;
      }
      final children = controller.childCategories(category.id);
      final collapsed = _collapsedCategories.contains(category.id);
      rows.add(
        _CategoryBudgetRow(
          snapshot: snapshot,
          depth: depth,
          childCount: children.length,
          collapsed: collapsed,
          onToggle: children.isEmpty
              ? null
              : () => setState(() {
                  if (collapsed) {
                    _collapsedCategories.remove(category.id);
                  } else {
                    _collapsedCategories.add(category.id);
                  }
                }),
          onTap: () => _editCategoryBudget(category),
        ),
      );
      if (children.isNotEmpty && !collapsed) {
        rows.addAll(
          _buildCategoryBudgetTree(controller, byId, children, depth + 1),
        );
      }
    }
    return rows;
  }

  /// 预算金额输入统一走数字键盘（与记账一致，支持算式）；允许 0（清除该预算）。
  /// 返回 null 表示取消，返回 >=0 的金额。
  Future<double?> _promptBudgetAmount(String title, double current) {
    return showNumberPadSheet(
      context,
      title: title,
      initialAmount: current > 0 ? current : null,
      allowZero: true,
    );
  }

  Future<void> _editMonthlyBudget() async {
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setMonthBudgetTitle,
      controller.monthlyBudget(_month),
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() {
      controller.setMonthlyBudget(_month, amount);
    });
  }

  Future<void> _editCategoryBudget(Category category) async {
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setCategoryBudgetTitle(category.label),
      controller.categoryBudget(_month, category.id),
    );
    if (amount == null || !mounted) {
      return;
    }
    controller.setCategoryBudget(_month, category.id, amount);
  }

  Future<void> _editDailyBudget() async {
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setDailyBudgetTitle,
      controller.dailyBudget(),
    );
    if (amount == null || !mounted) {
      return;
    }
    controller.setDailyBudget(amount);
  }

  void _openBudgetHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => BudgetHistoryPage(anchorMonth: _month),
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: AppLocalizations.of(context).calendarPrevMonth,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          AppLocalizations.of(context).yearMonth(month),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).calendarNextMonth,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class BudgetHistoryPage extends StatelessWidget {
  const BudgetHistoryPage({super.key, required this.anchorMonth});

  final DateTime anchorMonth;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final months = _budgetMonthSnapshots(
      controller: controller,
      anchor: anchorMonth,
      count: 12,
    ).reversed.toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).budgetHistoryTitle,
                subtitle: AppLocalizations.of(context).last12MonthsSub,
                showBack: true,
              ),
              const SizedBox(height: 10),
              _BudgetTrendCard(
                months: months.take(6).toList().reversed.toList(),
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppLocalizations.of(context).monthSummary,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in months)
                      _BudgetMonthRow(
                        snapshot: item,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  BudgetSettingsPage(initialMonth: item.month),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
