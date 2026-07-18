part of 'budget_pages.dart';

class BudgetSideStat extends StatelessWidget {
  const BudgetSideStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// 按日预算卡片：展示当前账本的每日花销上限与今日已花进度。
/// 每日上限是账本级偏好（适用于每一天），未设置时提示点击配置。
class _DailyBudgetCard extends StatelessWidget {
  const _DailyBudgetCard({
    required this.dailyBudget,
    required this.todayExpense,
  });

  final double dailyBudget;
  final double todayExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasBudget = dailyBudget > 0;
    final remaining = dailyBudget - todayExpense;
    final ratio = hasBudget
        ? (todayExpense / dailyBudget).clamp(0, 1).toDouble()
        : 0.0;
    final progressColor = budgetProgressColor(dailyBudget, remaining, ratio);
    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              VeriIconBox(
                icon: Icons.today_outlined,
                color: veriRoyal,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.dailyBudgetTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasBudget
                          ? l10n.dailyBudgetLimitLabel(
                              formatAmount(dailyBudget),
                            )
                          : l10n.dailyBudgetNotSet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasBudget) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.48),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _DailyBudgetStat(
                  label: l10n.dailyBudgetTodaySpent,
                  value: formatExpenseAmount(todayExpense),
                  color: veriExpense,
                ),
                const SizedBox(width: 16),
                _DailyBudgetStat(
                  label: remaining < 0
                      ? l10n.dailyBudgetTodayOver
                      : l10n.dailyBudgetTodayLeft,
                  value: remaining < 0
                      ? formatExpenseAmount(remaining.abs())
                      : formatAmount(remaining),
                  color: remaining < 0 ? veriExpense : veriIncome,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyBudgetStat extends StatelessWidget {
  const _DailyBudgetStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.50),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BudgetMetricTile extends StatelessWidget {
  const _BudgetMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.50),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetHistoryCard extends StatelessWidget {
  const _BudgetHistoryCard({
    required this.currentMonth,
    required this.previousMonth,
    required this.currentExpense,
    required this.previousExpense,
    required this.currentBudget,
    required this.previousBudget,
    required this.onHistoryTap,
  });

  final DateTime currentMonth;
  final DateTime previousMonth;
  final double currentExpense;
  final double previousExpense;
  final double currentBudget;
  final double previousBudget;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    // 自定义预算周期时对比措辞用「本期/上期」（对比的是相邻两个周期而非自然月）。
    final cyclic = VeriFinScope.of(context).budgetCycleIsCustom;
    final expenseDelta = currentExpense - previousExpense;
    final currentUsage = currentBudget <= 0
        ? 0.0
        : currentExpense / currentBudget;
    final previousUsage = previousBudget <= 0
        ? 0.0
        : previousExpense / previousBudget;
    final usageDelta = currentUsage - previousUsage;
    final deltaColor = isZeroAmount(expenseDelta)
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)
        : expenseDelta > 0
        ? veriExpense
        : veriIncome;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).historyCompare,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onHistoryTap,
                icon: const Icon(Icons.history, size: 15),
                label: Text(
                  '${AppLocalizations.of(context).monthNumber(previousMonth.month)} → ${AppLocalizations.of(context).monthNumber(currentMonth.month)}',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 32),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetCompareTile(
                  label: cyclic
                      ? AppLocalizations.of(context).budgetPeriodExpense
                      : AppLocalizations.of(context).budgetMonthExpense,
                  value: formatExpenseAmount(currentExpense),
                  detail: _expenseDeltaLabel(
                    AppLocalizations.of(context),
                    expenseDelta,
                    cyclic: cyclic,
                  ),
                  color: deltaColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BudgetCompareTile(
                  label: cyclic
                      ? AppLocalizations.of(context).lastPeriodExpense
                      : AppLocalizations.of(context).lastMonthExpense,
                  value: formatExpenseAmount(previousExpense),
                  detail: previousExpense <= 0
                      ? AppLocalizations.of(context).noExpenseYet
                      : AppLocalizations.of(context).compareBaseline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: currentUsage.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(
                currentUsage >= 1
                    ? veriExpense
                    : currentUsage >= 0.85
                    ? veriWarning
                    : veriRoyal,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            cyclic
                ? AppLocalizations.of(context).budgetUsageLinePeriod(
                    (currentUsage * 100).toStringAsFixed(0),
                    _usageDeltaLabel(AppLocalizations.of(context), usageDelta),
                  )
                : AppLocalizations.of(context).budgetUsageLine(
                    (currentUsage * 100).toStringAsFixed(0),
                    _usageDeltaLabel(AppLocalizations.of(context), usageDelta),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetMonthRow extends StatelessWidget {
  const _BudgetMonthRow({required this.snapshot, required this.onTap});

  final BudgetMonthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.budget <= 0
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58)
        : snapshot.overBudget
        ? veriExpense
        : veriIncome;
    final status = snapshot.budget <= 0
        ? AppLocalizations.of(context).notSetBudget
        : snapshot.overBudget
        ? AppLocalizations.of(
            context,
          ).overBy(formatAmount(snapshot.expense - snapshot.budget))
        : AppLocalizations.of(
            context,
          ).remainingAmount(formatAmount(snapshot.remaining));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: Icons.calendar_month_outlined,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).yearMonth(snapshot.month),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).budgetHistoryLine(
                        formatAmount(snapshot.budget),
                        formatExpenseAmount(snapshot.expense),
                        (snapshot.ratio * 100).toStringAsFixed(0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w600,
                      ),
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

class _BudgetCompareTile extends StatelessWidget {
  const _BudgetCompareTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.50),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.44),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetAlertCard extends StatelessWidget {
  const _CategoryBudgetAlertCard({
    required this.snapshot,
    required this.budgetedCategoryCount,
  });

  final CategoryBudgetSnapshot? snapshot;
  final int budgetedCategoryCount;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    final color = current == null
        ? veriIncome
        : current.overBudget
        ? veriExpense
        : veriWarning;
    final icon = current == null
        ? Icons.check_circle_outline
        : current.overBudget
        ? Icons.warning_amber_rounded
        : Icons.error_outline;
    final l10n = AppLocalizations.of(context);
    final title = current == null
        ? l10n.categoryBudgetOk
        : current.overBudget
        ? l10n.categoryOverspent(current.category.label)
        : l10n.categoryNearBudget(current.category.label);
    final description = current == null
        ? l10n.categoryBudgetOkDesc(budgetedCategoryCount)
        : current.overBudget
        ? l10n.categoryOverspentDesc(
            formatAmount(current.spent - current.budget),
            (current.ratio * 100).toStringAsFixed(0),
          )
        : l10n.categoryNearDesc(
            formatAmount(current.remaining),
            (current.ratio * 100).toStringAsFixed(0),
          );

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.snapshot,
    this.onTap,
    this.depth = 0,
    this.childCount = 0,
    this.collapsed = false,
    this.onToggle,
  });

  final CategoryBudgetSnapshot snapshot;

  /// 点击行的回调；null 表示只读（总览页只读，编辑默认预算在设置页）。
  final VoidCallback? onTap;

  /// 分类层级深度（0 为顶级），用于左侧缩进。
  final int depth;

  /// 子分类数量（>0 时父行显示展开/收起箭头）。
  final int childCount;
  final bool collapsed;

  /// 展开/收起子分类；无子分类时为 null（不显示折叠箭头）。
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.budget <= 0
        ? veriBlue
        : snapshot.spent > snapshot.budget
        ? veriExpense
        : veriRoyal;
    final l10n = AppLocalizations.of(context);
    final subtitle = snapshot.budget <= 0
        ? l10n.catNoBudgetLine(formatAmount(snapshot.spent))
        : snapshot.remaining >= 0
        ? l10n.catRemainLine(
            formatAmount(snapshot.remaining),
            (snapshot.ratio * 100).toStringAsFixed(0),
          )
        : l10n.catOverLine(
            formatAmount(snapshot.remaining.abs()),
            (snapshot.ratio * 100).toStringAsFixed(0),
          );
    final previousText = snapshot.previousSpent <= 0
        ? l10n.lastMonthNone
        : l10n.lastMonthAmount(formatAmount(snapshot.previousSpent));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(depth * 22.0, 8, 0, 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: onToggle == null
                    ? (depth > 0
                          ? Icon(
                              Icons.subdirectory_arrow_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            )
                          : null)
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 22,
                        onPressed: onToggle,
                        icon: Icon(
                          collapsed ? Icons.chevron_right : Icons.expand_more,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              CategoryIconBox(
                iconCode: snapshot.category.iconCode,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            snapshot.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          snapshot.budget <= 0
                              ? (onTap == null
                                    ? '—'
                                    : AppLocalizations.of(context).setLabel)
                              : formatAmount(snapshot.budget),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: snapshot.budget <= 0
                                    ? Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.52)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (onTap != null) ...<Widget>[
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 17,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.36),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previousText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: snapshot.progress,
                        minHeight: 4,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.50),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
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

class _BudgetInsightCard extends StatelessWidget {
  const _BudgetInsightCard({
    required this.budget,
    required this.expense,
    required this.remaining,
    required this.ratio,
    required this.remainingDays,
  });

  final double budget;
  final double expense;
  final double remaining;
  final double ratio;
  final int remainingDays;

  @override
  Widget build(BuildContext context) {
    final color = budgetProgressColor(budget, remaining, ratio);
    final (title, description, icon) = _budgetInsight(
      l10n: AppLocalizations.of(context),
      budget: budget,
      expense: expense,
      remaining: remaining,
      ratio: ratio,
      remainingDays: remainingDays,
    );

    return VeriCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 月预算来源状态 chip（总览页只读，点击进入单月覆盖弹窗）：
/// 区分「本月单独设置」「沿用默认 ¥X」「未设 · 点此设置」三态。
class _MonthBudgetStatusChip extends StatelessWidget {
  const _MonthBudgetStatusChip({
    required this.isOverride,
    required this.defaultBudget,
    required this.onTap,
  });

  final bool isOverride;
  final double defaultBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (IconData icon, String label, Color color) = isOverride
        ? (Icons.edit_calendar_outlined, l10n.budgetOverrideChip, veriRoyal)
        : defaultBudget > 0
        ? (
            Icons.event_repeat_outlined,
            l10n.budgetInheritChip(formatAmount(defaultBudget)),
            theme.colorScheme.onSurface.withValues(alpha: 0.62),
          )
        : (Icons.add_circle_outline, l10n.budgetSetChip, veriRoyal);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color budgetProgressColor(double budget, double remaining, double ratio) {
  if (budget <= 0) {
    return veriLine;
  }
  if (remaining < 0 || ratio >= 1) {
    return veriExpense;
  }
  if (ratio >= 0.85) {
    return veriWarning;
  }
  return veriRoyal;
}
