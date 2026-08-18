import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/report_analysis.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'transactions_pages.dart';

/// 排行分组维度：顶级分类 / 子分类（按记账所选分类）/ 标签。
enum _ReportGrouping { topCategory, subCategory, tag }

/// 统计分析页：支持本月 / 本年 / 自定义时间范围，支出与收入两个维度，
/// 展示收支汇总、趋势曲线与分类 / 子分类 / 标签排行。（阶段 4.1）
class ReportAnalysisPage extends StatefulWidget {
  const ReportAnalysisPage({super.key});

  @override
  State<ReportAnalysisPage> createState() => _ReportAnalysisPageState();
}

class _ReportAnalysisPageState extends State<ReportAnalysisPage> {
  late ReportRange _range = ReportRange.month(DateTime.now());
  EntryType _dimension = EntryType.expense;
  _ReportGrouping _grouping = _ReportGrouping.topCategory;

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
      helpText: AppLocalizations.of(context).pickTimeRange,
      saveText: AppLocalizations.of(context).okLabel,
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
    final categories = controller.categories;
    final summary = reportSummary(entries);
    final trend = reportTrend(entries, _range, _dimension);
    final categoryStats = _grouping == _ReportGrouping.subCategory
        ? reportCategoryStatsByOwn(entries, categories, _dimension)
        : reportCategoryStats(entries, categories, _dimension);
    final tagStats = reportTagStats(entries, controller.tags, _dimension);
    final dimensionColor = _dimension == EntryType.expense
        ? veriExpense
        : veriIncome;
    final dimensionTotal = _dimension == EntryType.expense
        ? summary.expense
        : summary.income;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).statAnalysisTitle,
                subtitle:
                    '${_range.label(AppLocalizations.of(context))} · ${controller.activeBook.baseCurrencyCode}',
                showBack: true,
              ),
              const SizedBox(height: 10),
              _RangeSelector(
                range: _range,
                onMonth: () =>
                    setState(() => _range = ReportRange.month(DateTime.now())),
                onYear: () => setState(
                  () => _range = ReportRange.year(DateTime.now().year),
                ),
                onCustom: _pickCustomRange,
              ),
              const SizedBox(height: 10),
              _SummaryCard(summary: summary),
              if (_range.mode == ReportRangeMode.month) ...<Widget>[
                const SizedBox(height: 10),
                _ComparisonCard(
                  comparison: reportMonthlyComparison(
                    controller.entries,
                    _range.start,
                  ),
                ),
              ],
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
              _GroupingSelector(
                grouping: _grouping,
                onChanged: (value) => setState(() => _grouping = value),
              ),
              const SizedBox(height: 10),
              if (_grouping == _ReportGrouping.tag)
                _TagRankCard(
                  stats: tagStats,
                  color: dimensionColor,
                  dimension: _dimension,
                )
              else
                _CategoryRankCard(
                  stats: categoryStats,
                  color: dimensionColor,
                  dimension: _dimension,
                  // 顶级分类模式点行下钻看子分类拆分；子分类模式点行直接跳到
                  // 按该分类筛选的交易列表（与分类管理「查看交易」同一路径，
                  // 「未分类」等也能一键定位到交易去批量归类，issue #16）。
                  onTapCategory: _grouping == _ReportGrouping.topCategory
                      ? (stat) => _showCategoryDrill(
                          context,
                          entries,
                          categories,
                          stat,
                        )
                      : (stat) => _openCategoryEntries(stat.categoryId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 跳到按 [categoryId]（含其子分类）筛选的交易列表——与分类管理「查看交易」
  /// 同一入口，便于从统计发现问题后直接去多选批量改分类。
  void _openCategoryEntries(String categoryId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsPage(initialCategoryId: categoryId),
      ),
    );
  }

  /// 顶级分类下钻：底部弹层展示该分类下按子分类（记账所选分类）的拆分，
  /// 子分类行与底部「查看交易」都可跳到对应交易列表。
  Future<void> _showCategoryDrill(
    BuildContext context,
    List<LedgerEntry> entries,
    List<Category> categories,
    ReportCategoryStat stat,
  ) {
    final children = reportCategoryChildStats(
      entries,
      categories,
      // 用聚合原始 key 而非 stat.category.id：后者在「已删除分类」占位时 id 不等于 key，
      // 会把下钻 scope 到错误的分类树（历史「幽灵餐饮」下钻显示错误子列表的成因）。
      stat.categoryId,
      _dimension,
    );
    final color = _dimension == EntryType.expense ? veriExpense : veriIncome;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
      ),
      // 命名为 sheetContext 与外层页面 context 区分：跳转前先 pop 弹层（用
      // sheetContext），再用页面 context push 交易列表。
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CategoryIconBox(
                        iconCode: stat.category.iconCode,
                        color: color,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(
                            sheetContext,
                          ).subCategoryOf(stat.category.label),
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        formatAmount(stat.amount),
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final child in children)
                          _CategoryRankTile(
                            stat: child,
                            color: color,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openCategoryEntries(child.categoryId);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(
                        AppLocalizations.of(sheetContext).viewCategoryEntries,
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openCategoryEntries(stat.categoryId);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          label: AppLocalizations.of(context).thisMonth,
          selected: range.mode == ReportRangeMode.month,
          onTap: onMonth,
        ),
        const SizedBox(width: 8),
        _RangeChip(
          label: AppLocalizations.of(context).timeYear,
          selected: range.mode == ReportRangeMode.year,
          onTap: onYear,
        ),
        const SizedBox(width: 8),
        _RangeChip(
          label: range.mode == ReportRangeMode.custom
              ? range.label(AppLocalizations.of(context))
              : AppLocalizations.of(context).customRange,
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
          SectionTitle(title: AppLocalizations.of(context).overviewTitle),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetric(
                  label: AppLocalizations.of(context).entryTypeIncome,
                  value: formatIncomeAmount(summary.income),
                  color: veriIncome,
                  count: summary.incomeCount,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: AppLocalizations.of(context).entryTypeExpense,
                  value: '-${formatAmount(summary.expense)}',
                  color: veriExpense,
                  count: summary.expenseCount,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: AppLocalizations.of(context).netLabel,
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
            AppLocalizations.of(context).entriesCount(count!),
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

/// 同比 / 环比对比卡：收入、支出、结余分别对上月（环比）与去年同月（同比）的变化。
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final ReportComparison comparison;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.48);
    Widget headerCell(String text) => Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: AppLocalizations.of(context).yoyMomTitle),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).yoyMomDesc,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Expanded(flex: 4, child: SizedBox.shrink()),
              headerCell(AppLocalizations.of(context).momLabel),
              headerCell(AppLocalizations.of(context).yoyLabel),
            ],
          ),
          const SizedBox(height: 4),
          _ComparisonRow(
            label: AppLocalizations.of(context).entryTypeIncome,
            current: comparison.current.income,
            momBase: comparison.previousMonth.income,
            yoyBase: comparison.sameMonthLastYear.income,
            higherIsGood: true,
          ),
          _ComparisonRow(
            label: AppLocalizations.of(context).entryTypeExpense,
            current: comparison.current.expense,
            momBase: comparison.previousMonth.expense,
            yoyBase: comparison.sameMonthLastYear.expense,
            higherIsGood: false,
          ),
          _ComparisonRow(
            label: AppLocalizations.of(context).netLabel,
            current: comparison.current.net,
            momBase: comparison.previousMonth.net,
            yoyBase: comparison.sameMonthLastYear.net,
            higherIsGood: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.momBase,
    required this.yoyBase,
    required this.higherIsGood,
  });

  final String label;
  final double current;
  final double momBase;
  final double yoyBase;

  /// 上升是否为「好」（收入/结余上升为好，支出上升为差），决定颜色。
  final bool higherIsGood;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  formatSignedAmount(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _ChangeCell(
            ratio: changeRatio(current, momBase),
            higherIsGood: higherIsGood,
          ),
          _ChangeCell(
            ratio: changeRatio(current, yoyBase),
            higherIsGood: higherIsGood,
          ),
        ],
      ),
    );
  }
}

class _ChangeCell extends StatelessWidget {
  const _ChangeCell({required this.ratio, required this.higherIsGood});

  final double? ratio;
  final bool higherIsGood;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.44);
    Color color = muted;
    if (ratio != null && ratio!.abs() >= 0.0005) {
      final rising = ratio! > 0;
      final good = rising == higherIsGood;
      color = good ? veriIncome : veriExpense;
    }
    return Expanded(
      flex: 3,
      child: Text(
        formatChangeRatio(ratio),
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
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
          segment(
            AppLocalizations.of(context).entryTypeExpense,
            EntryType.expense,
            veriExpense,
          ),
          const SizedBox(width: 4),
          segment(
            AppLocalizations.of(context).entryTypeIncome,
            EntryType.income,
            veriIncome,
          ),
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
        ? AppLocalizations.of(context).monthlyTrendTitle
        : AppLocalizations.of(context).panelDailyTrendLabel;
    final dimLabel = dimension.label(AppLocalizations.of(context));
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
                  title: trend.granularity == ReportTrendGranularity.daily
                      ? AppLocalizations.of(context).dateMonthDay(point.date)
                      : AppLocalizations.of(context).yearMonth(point.date),
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

/// 排行分组维度选择器（分类 / 子分类 / 标签）。
class _GroupingSelector extends StatelessWidget {
  const _GroupingSelector({required this.grouping, required this.onChanged});

  final _ReportGrouping grouping;
  final ValueChanged<_ReportGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<_ReportGrouping>(
      showSelectedIcon: false,
      segments: <ButtonSegment<_ReportGrouping>>[
        ButtonSegment<_ReportGrouping>(
          value: _ReportGrouping.topCategory,
          label: Text(l10n.rankGroupCategory),
        ),
        ButtonSegment<_ReportGrouping>(
          value: _ReportGrouping.subCategory,
          label: Text(l10n.rankGroupSubCategory),
        ),
        ButtonSegment<_ReportGrouping>(
          value: _ReportGrouping.tag,
          label: Text(l10n.rankGroupTag),
        ),
      ],
      selected: <_ReportGrouping>{grouping},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _CategoryRankCard extends StatelessWidget {
  const _CategoryRankCard({
    required this.stats,
    required this.color,
    required this.dimension,
    this.onTapCategory,
  });

  final List<ReportCategoryStat> stats;
  final Color color;
  final EntryType dimension;

  /// 可点行下钻（仅顶级分类模式传入）；为空则行不可点。
  final ValueChanged<ReportCategoryStat>? onTapCategory;

  @override
  Widget build(BuildContext context) {
    final dimLabel = dimension.label(AppLocalizations.of(context));
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: AppLocalizations.of(context).categoryRank,
            trailing: dimLabel,
          ),
          const SizedBox(height: 8),
          if (stats.isEmpty)
            EmptyState(
              icon: Icons.donut_small_outlined,
              title: AppLocalizations.of(context).noDimData(dimLabel),
              description: AppLocalizations.of(context).noDimDesc(dimLabel),
            )
          else
            ...stats.map(
              (stat) => _CategoryRankTile(
                stat: stat,
                color: color,
                onTap: onTapCategory == null
                    ? null
                    : () => onTapCategory!(stat),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRankTile extends StatelessWidget {
  const _CategoryRankTile({
    required this.stat,
    required this.color,
    this.onTap,
  });

  final ReportCategoryStat stat;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _RankTile(
      leading: CategoryIconBox(
        iconCode: stat.category.iconCode,
        color: color,
        size: 30,
      ),
      label: stat.category.label,
      amount: stat.amount,
      percent: stat.percent,
      count: stat.count,
      color: color,
      onTap: onTap,
    );
  }
}

class _TagRankCard extends StatelessWidget {
  const _TagRankCard({
    required this.stats,
    required this.color,
    required this.dimension,
  });

  final List<ReportTagStat> stats;
  final Color color;
  final EntryType dimension;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dimLabel = dimension.label(l10n);
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: l10n.tagRank, trailing: dimLabel),
          const SizedBox(height: 8),
          if (stats.isEmpty)
            EmptyState(
              icon: Icons.label_outline,
              title: l10n.noTagData,
              description: l10n.noTagDesc,
            )
          else ...<Widget>[
            ...stats.map(
              (stat) => _RankTile(
                leading: VeriIconBox(
                  icon: Icons.label_outline,
                  color: color,
                  size: 30,
                ),
                label: stat.tag.label,
                amount: stat.amount,
                percent: stat.percent,
                count: stat.count,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tagRankOverlapNote,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.46),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 排行行：图标 + 名称 + 金额 + 进度条 + 占比/笔数。可选点按下钻。
class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.leading,
    required this.label,
    required this.amount,
    required this.percent,
    required this.count,
    required this.color,
    this.onTap,
  });

  final Widget leading;
  final String label;
  final double amount;
  final double percent;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatAmount(amount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (onTap != null) ...<Widget>[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percent.clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(percent * 100).toStringAsFixed(1)}% · ${AppLocalizations.of(context).entriesCount(count)}',
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
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: content,
    );
  }
}
