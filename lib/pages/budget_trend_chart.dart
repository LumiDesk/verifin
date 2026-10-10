part of 'budget_pages.dart';

class _BudgetTrendCard extends StatelessWidget {
  const _BudgetTrendCard({required this.months});

  final List<BudgetMonthSnapshot> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 近 6 期都没有预算也没有支出时，画出来的是一条贴底的空网格。
    final hasData = months.any(
      (item) => item.budget > 0 || !isZeroAmount(item.expense),
    );
    final maxValue = months.fold<double>(
      0,
      (max, item) => math.max(max, math.max(item.expense, item.budget)),
    );
    return VeriCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).last6MonthsTrend,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (hasData)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ChartLegendDot(
                      color: Theme.of(context).colorScheme.primary,
                      label: AppLocalizations.of(context).budgetLegend,
                    ),
                    const SizedBox(width: 8),
                    _ChartLegendDot(
                      color: veriSemantic(context, veriExpense),
                      label: AppLocalizations.of(context).entryTypeExpense,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            EmptyState(
              icon: Icons.stacked_line_chart,
              title: l10n.noDimData(l10n.budgetLegend),
              description: l10n.noDimDesc(l10n.budgetLegend),
            )
          else
            SizedBox(
              height: 132,
              child: InteractiveComboChart(
                barValues: months
                    .map((item) => item.expense)
                    .toList(growable: false),
                lineValues: months
                    .map((item) => item.budget)
                    .toList(growable: false),
                xLabels: months
                    .map((item) => l10n.monthNumber(item.month.month))
                    .toList(growable: false),
                yLabels: reportAxisLabels(maxValue),
                barColor: veriSemantic(context, veriExpense),
                lineColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.50),
                tooltipOf: (index) {
                  final snapshot = months[index];
                  return ChartTooltip(
                    title: l10n.yearMonth(snapshot.month),
                    lines: <ChartTooltipLine>[
                      ChartTooltipLine(
                        text: l10n.budgetTotalLabel(
                          formatAmount(snapshot.budget),
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      ChartTooltipLine(
                        text: l10n.expenseAmountLabel(
                          formatExpenseAmount(snapshot.expense),
                        ),
                        color: veriSemantic(context, veriExpense),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
