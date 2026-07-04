import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/report_analysis.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';

/// 统计分析页：支持本月 / 本年 / 自定义时间范围，支出与收入两个维度，
/// 展示收支汇总、趋势曲线与分类排行。（阶段 4.1）
class ReportAnalysisPage extends StatefulWidget {
  const ReportAnalysisPage({super.key});

  @override
  State<ReportAnalysisPage> createState() => _ReportAnalysisPageState();
}

class _ReportAnalysisPageState extends State<ReportAnalysisPage> {
  late ReportRange _range = ReportRange.month(DateTime.now());
  EntryType _dimension = EntryType.expense;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: _range.start,
      end: _range.end.isAfter(now) ? now : _range.end,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: '选择时间范围',
      saveText: '确定',
    );
    if (picked != null && mounted) {
      setState(() {
        _range = ReportRange.custom(picked.start, picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = entriesInWindow(controller.entries, _range.window);
    final summary = reportSummary(entries);
    final trend = reportTrend(entries, _range, _dimension);
    final stats = reportCategoryStats(
      entries,
      controller.categories,
      _dimension,
    );
    final dimensionColor = _dimension == EntryType.expense
        ? veriExpense
        : veriIncome;
    final dimensionTotal = _dimension == EntryType.expense
        ? summary.expense
        : summary.income;

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        children: <Widget>[
          VeriHeader(title: '统计分析', subtitle: _range.label, showBack: true),
          const SizedBox(height: 10),
          _RangeSelector(
            range: _range,
            onMonth: () =>
                setState(() => _range = ReportRange.month(DateTime.now())),
            onYear: () =>
                setState(() => _range = ReportRange.year(DateTime.now().year)),
            onCustom: _pickCustomRange,
          ),
          const SizedBox(height: 10),
          _SummaryCard(summary: summary),
          const SizedBox(height: 10),
          _DimensionToggle(
            dimension: _dimension,
            onChanged: (value) => setState(() => _dimension = value),
          ),
          const SizedBox(height: 10),
          _TrendCard(
            trend: trend,
            color: dimensionColor,
            total: dimensionTotal,
            dimension: _dimension,
          ),
          const SizedBox(height: 10),
          _CategoryRankCard(
            stats: stats,
            color: dimensionColor,
            dimension: _dimension,
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.range,
    required this.onMonth,
    required this.onYear,
    required this.onCustom,
  });

  final ReportRange range;
  final VoidCallback onMonth;
  final VoidCallback onYear;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _RangeChip(
          label: '本月',
          selected: range.mode == ReportRangeMode.month,
          onTap: onMonth,
        ),
        const SizedBox(width: 8),
        _RangeChip(
          label: '本年',
          selected: range.mode == ReportRangeMode.year,
          onTap: onYear,
        ),
        const SizedBox(width: 8),
        _RangeChip(
          label: range.mode == ReportRangeMode.custom ? range.label : '自定义',
          selected: range.mode == ReportRangeMode.custom,
          icon: Icons.date_range_outlined,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? veriRoyal
                : (isDark ? veriSurfaceAltDark : veriSurfaceLight),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? veriRoyal
                  : (isDark ? Colors.white.withValues(alpha: 0.10) : veriLine),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : scheme.onSurface.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : scheme.onSurface.withValues(alpha: 0.78),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionTitle(title: '收支概览'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetric(
                  label: '收入',
                  value: formatIncomeAmount(summary.income),
                  color: veriIncome,
                  count: summary.incomeCount,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '支出',
                  value: '-${formatAmount(summary.expense)}',
                  color: veriExpense,
                  count: summary.expenseCount,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '结余',
                  value: formatSignedAmount(summary.net),
                  color: summary.net >= 0 ? veriRoyal : veriExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    this.count,
  });

  final String label;
  final String value;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.48);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (count != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            '$count 笔',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _DimensionToggle extends StatelessWidget {
  const _DimensionToggle({required this.dimension, required this.onChanged});

  final EntryType dimension;
  final ValueChanged<EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget segment(String label, EntryType type, Color color) {
      final selected = dimension == type;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? veriSurfaceAltDark : veriSurfaceAltLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : veriLine,
        ),
      ),
      child: Row(
        children: <Widget>[
          segment('支出', EntryType.expense, veriExpense),
          const SizedBox(width: 4),
          segment('收入', EntryType.income, veriIncome),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.trend,
    required this.color,
    required this.total,
    required this.dimension,
  });

  final ReportTrend trend;
  final Color color;
  final double total;
  final EntryType dimension;

  @override
  Widget build(BuildContext context) {
    final isZero = isZeroAmount(total);
    final title = trend.granularity == ReportTrendGranularity.monthly
        ? '月度趋势'
        : '日趋势';
    final dimLabel = dimension == EntryType.expense ? '支出' : '收入';
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: title,
            trailing:
                '$dimLabel ${dimension == EntryType.expense ? formatExpenseAmount(total) : formatIncomeAmount(total)}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: InteractiveTrendChart(
              color: isZero
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42)
                  : color,
              values: trend.values,
              xLabels: _sampledLabels(trend.points),
              yLabels: reportAxisLabels(trend.maxValue),
              labelColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.50),
              tooltipOf: (index) {
                final point = trend.points[index];
                final amount = dimension == EntryType.expense
                    ? formatExpenseAmount(point.value)
                    : formatIncomeAmount(point.value);
                return ChartTooltip(
                  title: point.tooltipTitle,
                  lines: <ChartTooltipLine>[
                    ChartTooltipLine(text: '$dimLabel $amount'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 点位过多时抽样标签，避免坐标轴文字重叠。
  List<String> _sampledLabels(List<ReportTrendPoint> points) {
    if (points.length <= 12) {
      return points.map((point) => point.label).toList(growable: false);
    }
    final step = (points.length / 8).ceil();
    return <String>[
      for (var i = 0; i < points.length; i += 1)
        (i % step == 0 || i == points.length - 1) ? points[i].label : '',
    ];
  }
}

class _CategoryRankCard extends StatelessWidget {
  const _CategoryRankCard({
    required this.stats,
    required this.color,
    required this.dimension,
  });

  final List<ReportCategoryStat> stats;
  final Color color;
  final EntryType dimension;

  @override
  Widget build(BuildContext context) {
    final dimLabel = dimension == EntryType.expense ? '支出' : '收入';
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: '分类排行', trailing: dimLabel),
          const SizedBox(height: 8),
          if (stats.isEmpty)
            EmptyState(
              icon: Icons.donut_small_outlined,
              title: '暂无$dimLabel数据',
              description: '该时间范围内没有$dimLabel记录。',
            )
          else
            ...stats.map((stat) => _CategoryRankTile(stat: stat, color: color)),
        ],
      ),
    );
  }
}

class _CategoryRankTile extends StatelessWidget {
  const _CategoryRankTile({required this.stat, required this.color});

  final ReportCategoryStat stat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(
            icon: iconForCode(stat.category.iconCode),
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
                        stat.category.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatAmount(stat.amount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: stat.percent.clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(stat.percent * 100).toStringAsFixed(1)}% · ${stat.count}笔',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.46),
                    fontWeight: FontWeight.w700,
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
