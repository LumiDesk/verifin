import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/category_tree.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';

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
                title: '预算设置',
                subtitle: '${_month.year}年${_month.month}月',
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
                                    '已用',
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
                                remaining < 0 ? '本月已超支' : '本月可用预算',
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
                          label: '本月支出',
                          value: formatExpenseAmount(monthExpense),
                          icon: Icons.payments_outlined,
                          color: veriExpense,
                        ),
                        _BudgetMetricTile(
                          label: remaining < 0 ? '超出预算' : '剩余额度',
                          value: remaining < 0
                              ? formatExpenseAmount(remaining.abs())
                              : formatAmount(remaining),
                          icon: remaining < 0
                              ? Icons.warning_amber_rounded
                              : Icons.account_balance_wallet_outlined,
                          color: remaining < 0 ? veriExpense : veriIncome,
                        ),
                        _BudgetMetricTile(
                          label: '剩余日均',
                          value: formatAmount(dailyAvailable),
                          icon: Icons.today_outlined,
                          color: veriRoyal,
                        ),
                        _BudgetMetricTile(
                          label: '预算金额',
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
                            '分类预算',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '本月支出分类',
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
                            '还没有支出分类',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.48),
                                ),
                          ),
                        ),
                      )
                    else
                      for (final snapshot in categoryBudgetSnapshots)
                        _CategoryBudgetRow(
                          snapshot: snapshot,
                          onTap: () => _editCategoryBudget(snapshot.category),
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

  Future<void> _editMonthlyBudget() async {
    final controller = VeriFinScope.of(context);
    final currentBudget = controller.monthlyBudget(_month);
    final amountText = await showTextInputDialog(
      context: context,
      title: '设置本月预算',
      label: '月份预算金额',
      initialValue: currentBudget <= 0 ? '' : formatAmount(currentBudget),
      allowEmpty: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (amountText == null || !mounted) {
      return;
    }
    setState(() {
      controller.setMonthlyBudget(_month, double.tryParse(amountText) ?? 0);
    });
  }

  Future<void> _editCategoryBudget(Category category) async {
    final controller = VeriFinScope.of(context);
    final currentBudget = controller.categoryBudget(_month, category.id);
    final amountText = await showTextInputDialog(
      context: context,
      title: '设置${category.label}预算',
      label: '分类预算金额',
      initialValue: currentBudget <= 0 ? '' : formatAmount(currentBudget),
      allowEmpty: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (amountText == null || !mounted) {
      return;
    }
    controller.setCategoryBudget(
      _month,
      category.id,
      double.tryParse(amountText) ?? 0,
    );
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
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${month.year}年${month.month}月',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: '下个月',
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
              const VeriHeader(
                title: '预算历史',
                subtitle: '最近 12 个月',
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
                      '月份汇总',
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

class _BudgetTrendCard extends StatefulWidget {
  const _BudgetTrendCard({required this.months});

  final List<BudgetMonthSnapshot> months;

  @override
  State<_BudgetTrendCard> createState() => _BudgetTrendCardState();
}

class _BudgetTrendCardState extends State<_BudgetTrendCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _BudgetTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months.length != widget.months.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final maxValue = months.fold<double>(
      0,
      (max, item) => math.max(max, math.max(item.expense, item.budget)),
    );
    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '近 6 月趋势',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ChartLegendDot(color: veriRoyal, label: '预算'),
                  const SizedBox(width: 8),
                  _ChartLegendDot(color: veriExpense, label: '支出'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                Rect chartRect() =>
                    trendChartRect(size, hasXLabels: true, hasYLabels: true);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final index = chartSlotIndex(
                      details.localPosition,
                      chartRect(),
                      months.length,
                    );
                    setState(() {
                      _selectedIndex = index == _selectedIndex ? null : index;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    final index = chartSlotIndex(
                      details.localPosition,
                      chartRect(),
                      months.length,
                    );
                    if (index != null && index != _selectedIndex) {
                      setState(() => _selectedIndex = index);
                    }
                  },
                  child: CustomPaint(
                    painter: _BudgetTrendPainter(
                      months: months,
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.50),
                      yLabels: reportAxisLabels(maxValue),
                      selectedIndex: _selectedIndex,
                      tooltip: _selectedIndex == null
                          ? null
                          : _tooltipFor(months[_selectedIndex!]),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ChartTooltip _tooltipFor(BudgetMonthSnapshot snapshot) {
    return ChartTooltip(
      title: '${snapshot.month.year}年${snapshot.month.month}月',
      lines: <ChartTooltipLine>[
        ChartTooltipLine(
          text: '预算 ${formatAmount(snapshot.budget)}',
          color: veriRoyal,
        ),
        ChartTooltipLine(
          text: '支出 ${formatExpenseAmount(snapshot.expense)}',
          color: veriExpense,
        ),
      ],
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

class _BudgetTrendPainter extends CustomPainter {
  const _BudgetTrendPainter({
    required this.months,
    required this.labelColor,
    required this.yLabels,
    this.selectedIndex,
    this.tooltip,
  });

  final List<BudgetMonthSnapshot> months;
  final Color labelColor;
  final List<String> yLabels;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = trendChartRect(size, hasXLabels: true, hasYLabels: true);
    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i += 1) {
      final y = chartRect.bottom - chartRect.height * chartValueScale * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
    }

    final maxValue = math.max(
      months.fold<double>(
        0,
        (max, item) => math.max(max, math.max(item.expense, item.budget)),
      ),
      1,
    );
    final gap = chartRect.width / math.max(months.length, 1);
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          veriExpense.withValues(alpha: 0.82),
          veriExpense.withValues(alpha: 0.30),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    final linePaint = Paint()
      ..color = veriRoyal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = veriRoyal;
    final path = Path();

    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final barHeight =
          item.expense / maxValue * chartRect.height * chartValueScale;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - gap * 0.16,
          chartRect.bottom - barHeight,
          gap * 0.32,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, barPaint);

      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      if (i == 0) {
        path.moveTo(centerX, budgetY);
      } else {
        path.lineTo(centerX, budgetY);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      canvas.drawCircle(Offset(centerX, budgetY), 2.4, pointPaint);
    }

    _drawBudgetTrendLabels(canvas, chartRect);

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < months.length) {
      final item = months[selected];
      final centerX = chartRect.left + gap * selected + gap / 2;
      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      final barTop =
          chartRect.bottom -
          item.expense / maxValue * chartRect.height * chartValueScale;
      canvas.drawLine(
        Offset(centerX, chartRect.top),
        Offset(centerX, chartRect.bottom),
        Paint()
          ..color = labelColor.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(centerX, budgetY), 5, pointPaint);
      canvas.drawCircle(
        Offset(centerX, budgetY),
        2.3,
        Paint()..color = Colors.white,
      );
      if (tooltip != null) {
        drawChartTooltip(
          canvas,
          size,
          Offset(centerX, math.min(budgetY, barTop)),
          tooltip!,
        );
      }
    }
  }

  void _drawBudgetTrendLabels(Canvas canvas, Rect chartRect) {
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i < yLabels.length; i += 1) {
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: chartRect.left - 4);
      final y =
          chartRect.bottom -
          chartRect.height * chartValueScale * i / (yLabels.length - 1);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    if (months.isEmpty) {
      return;
    }
    final gap = chartRect.width / months.length;
    for (var i = 0; i < months.length; i += 1) {
      final label = '${months[i].month.month}月';
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: gap);
      final x = chartRect.left + gap * i + gap / 2 - painter.width / 2;
      painter.paint(canvas, Offset(x, chartRect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetTrendPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.tooltip != tooltip;
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
                  '历史对比',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onHistoryTap,
                icon: const Icon(Icons.history, size: 15),
                label: Text('${previousMonth.month}月 → ${currentMonth.month}月'),
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
                  label: '本月支出',
                  value: formatExpenseAmount(currentExpense),
                  detail: _expenseDeltaLabel(expenseDelta),
                  color: deltaColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BudgetCompareTile(
                  label: '上月支出',
                  value: formatExpenseAmount(previousExpense),
                  detail: previousExpense <= 0 ? '暂无支出' : '对比基准',
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
            '预算使用率 ${(currentUsage * 100).toStringAsFixed(0)}%，较上月 ${_usageDeltaLabel(usageDelta)}',
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
        ? '未设置预算'
        : snapshot.overBudget
        ? '超出 ${formatAmount(snapshot.expense - snapshot.budget)}'
        : '剩余 ${formatAmount(snapshot.remaining)}';

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
                            '${snapshot.month.year}年${snapshot.month.month}月',
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
                      '预算 ${formatAmount(snapshot.budget)} · 支出 ${formatExpenseAmount(snapshot.expense)} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%',
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
    final title = current == null
        ? '分类预算正常'
        : current.overBudget
        ? '${current.category.label}已超支'
        : '${current.category.label}接近预算';
    final description = current == null
        ? '已设置 $budgetedCategoryCount 个分类预算，当前没有临近超支的分类。'
        : current.overBudget
        ? '已超出 ${formatAmount(current.spent - current.budget)}，本月已用 ${(current.ratio * 100).toStringAsFixed(0)}%。'
        : '剩余 ${formatAmount(current.remaining)}，本月已用 ${(current.ratio * 100).toStringAsFixed(0)}%。';

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
  const _CategoryBudgetRow({required this.snapshot, required this.onTap});

  final CategoryBudgetSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.budget <= 0
        ? veriBlue
        : snapshot.spent > snapshot.budget
        ? veriExpense
        : veriRoyal;
    final subtitle = snapshot.budget <= 0
        ? '未设置预算 · 本月支出 ${formatAmount(snapshot.spent)}'
        : snapshot.remaining >= 0
        ? '剩余 ${formatAmount(snapshot.remaining)} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%'
        : '超出 ${formatAmount(snapshot.remaining.abs())} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%';
    final previousText = snapshot.previousSpent <= 0
        ? '上月无支出'
        : '上月 ${formatAmount(snapshot.previousSpent)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: iconForCode(snapshot.category.iconCode),
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
                              ? '设置'
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

String _budgetPeriodLabel(
  int remainingDays,
  bool isPastMonth,
  bool isCurrentMonth,
) {
  if (isPastMonth) {
    return '月份已结束';
  }
  if (isCurrentMonth) {
    return '含今天还剩 $remainingDays 天';
  }
  return '本月共 $remainingDays 天';
}

(String, String, IconData) _budgetInsight({
  required double budget,
  required double expense,
  required double remaining,
  required double ratio,
  required int remainingDays,
}) {
  if (budget <= 0) {
    return (
      '还没有设置预算',
      '设置本月预算后，首页和这里会同步展示预算进度、剩余额度和剩余日均。',
      Icons.flag_outlined,
    );
  }
  if (remaining < 0) {
    return (
      '预算已经超出',
      '本月支出已超过预算 ${formatAmount(remaining.abs())}，后续支出会继续计入本月统计。',
      Icons.warning_amber_rounded,
    );
  }
  if (ratio >= 0.85) {
    return (
      '预算接近用完',
      '本月预算已使用 ${(ratio * 100).toStringAsFixed(0)}%，剩余 ${formatAmount(remaining)}。',
      Icons.error_outline,
    );
  }
  if (remainingDays > 0) {
    return (
      '预算状态正常',
      '按当前预算，本月剩余每天约可支出 ${formatAmount(remaining / remainingDays)}。',
      Icons.check_circle_outline,
    );
  }
  return (
    '本月预算已结算',
    '这个月份已结束，可切换到其他月份继续查看或调整预算。',
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
    final entries = controller.entries
        .where((entry) => isInMonth(entry, month))
        .toList(growable: false);
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
          budget: controller.categoryBudget(month, category.id),
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

String _expenseDeltaLabel(double delta) {
  if (isZeroAmount(delta)) {
    return '与上月持平';
  }
  if (delta > 0) {
    return '比上月多 ${formatAmount(delta)}';
  }
  return '比上月少 ${formatAmount(delta.abs())}';
}

String _usageDeltaLabel(double delta) {
  final points = (delta.abs() * 100).toStringAsFixed(0);
  if (points == '0') {
    return '持平';
  }
  return delta > 0 ? '增加 $points 个点' : '降低 $points 个点';
}
