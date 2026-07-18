import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/budget_cycle.dart';
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
part 'budget_settings_page.dart';

/// 预算总览（只读）：查看某月/某周期的预算执行情况。所有「配置」动作（默认预算、
/// 按日上限、周期起始日、分类默认预算）都在右上角齿轮进入的 [BudgetSettingsPage]，
/// 单月覆盖走状态 chip / 历史列表的 [showMonthlyBudgetOverrideSheet]，本页不内联编辑。
class BudgetOverviewPage extends StatefulWidget {
  const BudgetOverviewPage({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<BudgetOverviewPage> createState() => _BudgetOverviewPageState();
}

class _BudgetOverviewPageState extends State<BudgetOverviewPage> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );

  // 收起的父分类 id（默认折叠：首次构建时把所有含子类的分类加入，只显示顶级行）。
  final Set<String> _collapsedCategories = <String>{};
  bool _collapseInitialized = false;

  void _initCollapse(VeriFinController controller) {
    if (_collapseInitialized) {
      return;
    }
    _collapseInitialized = true;
    for (final category in controller.categoriesForType(EntryType.expense)) {
      if (controller.childCategories(category.id).isNotEmpty) {
        _collapsedCategories.add(category.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    _initCollapse(controller);
    // 预算按周期取数：_month 是周期的「键月」（预算存储键），窗口由账本的
    // 周期起始日决定；起始日 = 1 时窗口即自然月，行为与旧版完全一致。
    final cyclic = controller.budgetCycleIsCustom;
    final window = controller.budgetWindow(_month);
    final monthEntries = entriesInWindow(controller.entries, window);
    final previousMonth = DateTime(_month.year, _month.month - 1);
    final previousMonthEntries = entriesInWindow(
      controller.entries,
      controller.budgetWindow(previousMonth),
    );
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
    final daysInCycle = window.days.length;
    final now = DateTime.now();
    final nowKeyMonth = controller.budgetKeyMonthFor(now);
    final isCurrentMonth =
        _month.year == nowKeyMonth.year && _month.month == nowKeyMonth.month;
    final isPastMonth = DateTime(
      _month.year,
      _month.month,
    ).isBefore(nowKeyMonth);
    final today = dateOnly(now);
    final remainingDays = isPastMonth
        ? 0
        : isCurrentMonth
        ? window.days
              .where((day) => !day.isBefore(today))
              .length
              .clamp(1, daysInCycle)
        : daysInCycle;
    final dailyAvailable = remainingDays <= 0 || remaining <= 0
        ? 0.0
        : remaining / remainingDays;
    // 自定义周期时标签展示日期范围（如「7月22日 至 8月21日」）而非「2026年7月」。
    final cycleLabel = cyclic
        ? l10n.budgetCycleRange(window.start, window.end)
        : l10n.yearMonth(_month);
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
                title: AppLocalizations.of(context).budgetTitle,
                subtitle: cycleLabel,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.tune,
                    tooltip: l10n.budgetSettingsTitle,
                    onPressed: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MonthSwitcher(
                      label: cycleLabel,
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
                                    ? (cyclic
                                          ? l10n.budgetOverspentThisPeriod
                                          : l10n.budgetOverspentThisMonth)
                                    : (cyclic
                                          ? l10n.budgetAvailableThisPeriod
                                          : l10n.budgetAvailableThisMonth),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                remaining < 0
                                    ? formatExpenseAmount(remaining.abs())
                                    : formatAmount(remaining),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: remaining < 0
                                          ? veriExpense
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _budgetPeriodLabel(
                                  AppLocalizations.of(context),
                                  remainingDays,
                                  isPastMonth,
                                  isCurrentMonth,
                                  cyclic: cyclic,
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
                              const SizedBox(height: 8),
                              _MonthBudgetStatusChip(
                                isOverride: controller.monthlyBudgetIsOverride(
                                  _month,
                                ),
                                defaultBudget: controller.defaultMonthlyBudget,
                                onTap: () => _openOverride(_month),
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
                          label: cyclic
                              ? l10n.budgetPeriodExpense
                              : l10n.budgetMonthExpense,
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
              // 按日预算卡仅在已设上限时展示（只读追踪）；设置入口在预算设置页。
              if (controller.dailyBudget() > 0) ...<Widget>[
                const SizedBox(height: 10),
                _DailyBudgetCard(
                  dailyBudget: controller.dailyBudget(),
                  todayExpense: dayExpenseTotal(controller.entries, now),
                ),
              ],
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
                          cyclic
                              ? AppLocalizations.of(
                                  context,
                                ).periodExpenseCategories
                              : AppLocalizations.of(
                                  context,
                                ).monthExpenseCategories,
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

  /// 递归渲染分类预算树（**只读**）：按分类的父子层级展开，父行显示已含子类的合计
  /// 花销/预算，可折叠子树。顺序与分类管理页一致（按存储顺序）。设置分类默认预算在
  /// 预算设置页，本页仅展示执行情况。[byId] 提供各分类的预算快照（父快照已聚合子类花销）。
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

  /// 进入预算设置页（默认预算、按日上限、周期起始日、分类默认预算）。
  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (context) => const BudgetSettingsPage()),
    );
  }

  /// 打开某月的「单月覆盖」弹窗：为该月单独设额度或恢复沿用默认。
  void _openOverride(DateTime month) {
    showMonthlyBudgetOverrideSheet(context, month);
  }

  void _openBudgetHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => BudgetHistoryPage(anchorMonth: _month),
      ),
    );
  }
}

/// 前后翻页 + 中间标签的通用切换器（预算页按月，收支统计页按周/月/季/年）。
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
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
          label,
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
                        // 点某月 → 调整该月的单月覆盖（或恢复沿用默认）。
                        onTap: () =>
                            showMonthlyBudgetOverrideSheet(context, item.month),
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
