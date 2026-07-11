import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/home_metrics.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'budget_pages.dart';
import 'home_metrics_settings_page.dart';
import 'panel_settings_page.dart';
import 'sheets.dart';
import 'transactions_pages.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final now = DateTime.now();
    final monthEntries = entries
        .where(
          (entry) =>
              entry.occurredAt.year == now.year &&
              entry.occurredAt.month == now.month,
        )
        .toList();
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final trendWindow = cumulativeWeekWindowFor(now);
    final trendEntries = entriesInWindow(monthEntries, trendWindow);
    final trendConfig = controller.homeTrendConfig;
    final metricContext = HomeMetricContext(
      entries: entries,
      accounts: controller.accounts,
      balanceOf: controller.accountBalance,
      now: now,
    );
    final trendChartValues = trendSeriesValues(
      trendConfig.series,
      trendEntries,
      trendWindow,
    );
    // 退款条目在原支出上管理，不单独进时间线（净额已体现在支出行）。
    final recentEntries = entries
        .where((e) => e.type != EntryType.refund)
        .take(5)
        .toList();
    final monthlyBudget = controller.monthlyBudget(now);
    final categoryBudgetSnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: now,
      monthEntries: monthEntries,
    );
    final categoryBudgetRisk = topCategoryBudgetRisk(categoryBudgetSnapshots);
    final panelIds = controller.enabledPanelIds(PanelPageKind.home);

    // 面板 id 对应的卡片,渲染顺序与开关由面板管理页配置。
    Widget panelFor(String id) {
      switch (id) {
        case 'trend':
          return HomeTrendPanel(
            window: trendWindow,
            config: trendConfig,
            metricContext: metricContext,
            chartValues: trendChartValues,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const IncomeExpenseStatsPage(),
                ),
              );
            },
          );
        case 'recent':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeaderAction(
                  title: AppLocalizations.of(context).panelRecentLabel,
                  trailing: recentEntries.isEmpty
                      ? AppLocalizations.of(context).commonNone
                      : formatSignedAmount(
                          recentEntries.fold<double>(
                            0,
                            (sum, entry) => sum + signedAmount(entry),
                          ),
                        ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const TransactionsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (recentEntries.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: AppLocalizations.of(context).homeNoEntriesTitle,
                    description: AppLocalizations.of(context).homeNoEntriesDesc,
                  )
                else
                  for (final item in recentEntries.indexed) ...<Widget>[
                    TransactionTile(
                      item.$2,
                      accounts: controller.accounts,
                      categories: controller.categories,
                      onTap: () => openEntryDetail(context, item.$2),
                    ),
                    if (item.$1 != recentEntries.length - 1)
                      Divider(
                        indent: 19,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                  ],
              ],
            ),
          );
        case 'budget':
          return BudgetPanel(
            month: now,
            expense: monthExpense,
            budget: monthlyBudget,
            categoryRisk: categoryBudgetRisk,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => BudgetSettingsPage(initialMonth: now),
                ),
              );
            },
          );
        case 'calendar':
          return CalendarPreview(
            entries: entries,
            onDayTap: (date) {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => TransactionsPage(initialDate: date),
                ),
              );
            },
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabHome,
            // 副标题展示当前账本名（此前误为固定文案）。
            subtitle: controller.activeBook.name,
          ),
          for (final id in panelIds) ...<Widget>[
            const SizedBox(height: 10),
            panelFor(id),
          ],
          const SizedBox(height: 8),
          const PanelSettingsEntry(kind: PanelPageKind.home),
        ],
      ),
    );
  }
}

class SectionHeaderAction extends StatelessWidget {
  const SectionHeaderAction({
    super.key,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (trailing.isNotEmpty) ...<Widget>[
              Text(
                trailing,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const _CircleArrow(),
          ],
        ),
      ),
    );
  }
}

/// 走势曲线按所选序列取逐日值（结余=逐日收入−支出）。
List<double> trendSeriesValues(
  HomeTrendSeries series,
  List<LedgerEntry> entries,
  DateWindow window,
) {
  switch (series) {
    case HomeTrendSeries.expense:
      return valuesForTypeInWindow(entries, window, EntryType.expense);
    case HomeTrendSeries.income:
      return valuesForTypeInWindow(entries, window, EntryType.income);
    case HomeTrendSeries.net:
      final income = valuesForTypeInWindow(entries, window, EntryType.income);
      final expense = valuesForTypeInWindow(entries, window, EntryType.expense);
      return <double>[
        for (var i = 0; i < income.length; i++) income[i] - expense[i],
      ];
  }
}

Color _trendSeriesColor(HomeTrendSeries series) {
  switch (series) {
    case HomeTrendSeries.expense:
      return veriExpense;
    case HomeTrendSeries.income:
      return veriIncome;
    case HomeTrendSeries.net:
      return veriBlue;
  }
}

/// 走势气泡里单日数值的文案：支出显示为负（`-x`）、收入为正（`+x`）、结余带正负号。
String _trendSeriesValueText(HomeTrendSeries series, double value) {
  switch (series) {
    case HomeTrendSeries.expense:
      return formatExpenseAmount(value);
    case HomeTrendSeries.income:
      return isZeroAmount(value) ? '0' : '+${formatIncomeAmount(value)}';
    case HomeTrendSeries.net:
      return formatSignedAmount(value);
  }
}

class HomeTrendPanel extends StatelessWidget {
  const HomeTrendPanel({
    super.key,
    required this.window,
    required this.config,
    required this.metricContext,
    required this.chartValues,
    required this.onTap,
  });

  final DateWindow window;
  final HomeTrendConfig config;
  final HomeMetricContext metricContext;
  final List<double> chartValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: isDark ? 0.62 : 0.52);

    final bigValue = computeHomeMetric(config.big, metricContext);
    final bigColor = homeMetricColor(config.big, bigValue, mutedColor);
    final pillValue = computeHomeMetric(config.pill, metricContext);
    final pillColor = homeMetricColor(config.pill, pillValue, mutedColor);

    final title = config.title.isEmpty ? l10n.trendDefaultTitle : config.title;
    final seriesColor = isZeroAmount(chartValues.fold<double>(0, math.max))
        ? mutedColor
        : _trendSeriesColor(config.series);
    final seriesLabel = homeTrendSeriesLabel(l10n, config.series);

    return VeriCard(
      onTap: onTap,
      quietTap: true,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        window.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const _CircleArrow(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        homeMetricLabel(l10n, config.big),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatHomeMetric(config.big, bigValue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: bigColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${homeMetricLabel(l10n, config.pill)} '
                    '${formatHomeMetric(config.pill, pillValue)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: pillColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricTile(
                    metric: config.card1,
                    metricContext: metricContext,
                    dark: isDark,
                    mutedColor: mutedColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    metric: config.card2,
                    metricContext: metricContext,
                    dark: isDark,
                    mutedColor: mutedColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    metric: config.card3,
                    metricContext: metricContext,
                    dark: isDark,
                    mutedColor: mutedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 138,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                // 图表区域自行响应点击展示数据,不触发卡片跳转。
                child: InteractiveTrendChart(
                  color: seriesColor,
                  values: chartValues,
                  xLabels: sparseLabelsForWindow(window),
                  yLabels: reportAxisLabels(
                    chartValues.map((v) => v.abs()).fold(0, math.max),
                  ),
                  labelColor: mutedColor,
                  glow: isDark,
                  tooltipOf: (index) {
                    final day = window.days[index];
                    return ChartTooltip(
                      title: l10n.dateMonthDay(day),
                      lines: <ChartTooltipLine>[
                        ChartTooltipLine(
                          text:
                              '$seriesLabel ${_trendSeriesValueText(config.series, chartValues[index])}',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 走势卡片里的一个可自定义小卡片：展示某个指标的名称与数值。
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.metric,
    required this.metricContext,
    required this.dark,
    required this.mutedColor,
  });

  final HomeMetric metric;
  final HomeMetricContext metricContext;
  final bool dark;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final value = computeHomeMetric(metric, metricContext);
    final color = homeMetricColor(metric, value, mutedColor);
    return _TrendMetric(
      label: homeMetricLabel(AppLocalizations.of(context), metric),
      value: formatHomeMetric(metric, value),
      color: color,
      dark: dark,
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.dark,
  });

  final String label;
  final String value;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(
          color: dark
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.08),
        ),
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
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: dark ? Colors.white.withValues(alpha: 0.86) : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetPanel extends StatelessWidget {
  const BudgetPanel({
    super.key,
    required this.month,
    required this.expense,
    required this.budget,
    required this.categoryRisk,
    required this.onTap,
  });

  final DateTime month;
  final double expense;
  final double budget;
  final CategoryBudgetSnapshot? categoryRisk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 未设预算（budget<=0）显示 0；设了预算则超支时显示负数（与预算页口径一致）。
    final remaining = budget <= 0 ? 0.0 : budget - expense;
    final overspent = remaining < 0;
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
    final remainingDays = (daysInMonth - DateTime.now().day + 1).clamp(
      1,
      daysInMonth,
    );
    final ratio = budget <= 0 ? 0.0 : (expense / budget).clamp(0, 1).toDouble();

    return VeriCard(
      onTap: onTap,
      quietTap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).monthBudgetTitle(month),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _CircleArrow(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: BudgetSideStat(
                  label: AppLocalizations.of(context).entryTypeExpense,
                  value: formatExpenseAmount(expense),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: CustomPaint(
                        painter: BudgetRingPainter(
                          value: ratio,
                          trackColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.48),
                          progressColor: budgetProgressColor(
                            budget,
                            budget - expense,
                            ratio,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          AppLocalizations.of(context).budgetRemaining,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                        Text(
                          formatAmount(remaining),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: overspent ? veriExpense : null,
                              ),
                        ),
                        Text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BudgetSideStat(
                  label: AppLocalizations.of(context).budgetDailyRemaining,
                  // 超支时可分配日均为 0（负的日均无实际意义）。
                  value: formatAmount(
                    (remaining < 0 ? 0.0 : remaining) / remainingDays,
                  ),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              AppLocalizations.of(
                context,
              ).budgetTotalLabel(formatAmount(budget)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.44),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (categoryRisk != null) ...<Widget>[
            const SizedBox(height: 8),
            _HomeBudgetRiskBanner(snapshot: categoryRisk!),
          ],
        ],
      ),
    );
  }
}

class _CircleArrow extends StatelessWidget {
  const _CircleArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: veriRoyal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Icon(Icons.chevron_right, size: 17, color: veriRoyal),
    );
  }
}

class IncomeExpenseStatsPage extends StatefulWidget {
  const IncomeExpenseStatsPage({super.key});

  @override
  State<IncomeExpenseStatsPage> createState() => _IncomeExpenseStatsPageState();
}

/// 收支统计的视图档位：周 / 月 / 季按天描点，年按 12 个月描点。
enum _StatPeriod { week, month, quarter, year }

class _IncomeExpenseStatsPageState extends State<IncomeExpenseStatsPage> {
  DateTime _focusDate = DateTime.now();
  EntryType _type = EntryType.expense;
  _StatPeriod _period = _StatPeriod.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final isYear = _period == _StatPeriod.year;
    // 年视图无「按天」窗口，用 12 个月聚合；其余按天窗口。
    final window = isYear ? null : _windowForPeriod();
    final scopedByType = controller.entries
        .where((entry) => entry.type == _type)
        .toList();

    final List<LedgerEntry> rangeEntries;
    final List<double> chartValues;
    final List<String> chartXLabels;
    if (isYear) {
      rangeEntries = scopedByType
          .where((entry) => entry.occurredAt.year == _focusDate.year)
          .toList();
      chartValues = monthlyNetValuesForType(
        scopedByType,
        _focusDate.year,
        _type,
      );
      chartXLabels = List<String>.generate(12, (i) => '${i + 1}');
    } else {
      rangeEntries = entriesInWindow(scopedByType, window!);
      chartValues = valuesForTypeInWindow(rangeEntries, window, _type);
      chartXLabels = _period == _StatPeriod.week
          ? labelsForWindow(window)
          : sparseLabelsForWindow(window);
    }

    final total = rangeEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final statRows = isYear
        ? _monthlyStatRows(rangeEntries, _focusDate.year, total)
        : _periodDayRows(rangeEntries, window!, total);
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.52);
    final totalColor = isZeroAmount(total) ? mutedColor : colorForType(_type);
    final totalText = switch (_type) {
      EntryType.expense => formatExpenseAmount(total),
      EntryType.income => formatIncomeAmount(total),
      EntryType.transfer => formatAmount(total),
      EntryType.refund => formatIncomeAmount(total),
    };

    String amountTextOf(double value) => switch (_type) {
      EntryType.expense => formatExpenseAmount(value),
      EntryType.income => '+${formatIncomeAmount(value)}',
      EntryType.transfer => formatAmount(value),
      EntryType.refund => '+${formatIncomeAmount(value)}',
    };

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.incomeExpenseTitle,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    key: const Key('trend_customize'),
                    icon: Icons.edit_outlined,
                    tooltip: l10n.trendCustomizeEntry,
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => const HomeMetricsSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<_StatPeriod>(
                showSelectedIcon: false,
                segments: <ButtonSegment<_StatPeriod>>[
                  ButtonSegment<_StatPeriod>(
                    value: _StatPeriod.week,
                    label: Text(l10n.statPeriodWeek),
                  ),
                  ButtonSegment<_StatPeriod>(
                    value: _StatPeriod.month,
                    label: Text(l10n.statPeriodMonth),
                  ),
                  ButtonSegment<_StatPeriod>(
                    value: _StatPeriod.quarter,
                    label: Text(l10n.statPeriodQuarter),
                  ),
                  ButtonSegment<_StatPeriod>(
                    value: _StatPeriod.year,
                    label: Text(l10n.statPeriodYear),
                  ),
                ],
                selected: <_StatPeriod>{_period},
                onSelectionChanged: (selection) {
                  setState(() => _period = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  MonthSwitcher(
                    label: _rangeLabel(l10n, window),
                    onPrevious: () => _shiftFocus(-1),
                    onNext: () => _shiftFocus(1),
                  ),
                  const Spacer(),
                  FilterPill(label: _type.label(l10n), onTap: _pickEntryType),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_rangeLabel(l10n, window)} ${_type.label(l10n)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: totalColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: InteractiveTrendChart(
                        color: totalColor,
                        values: chartValues,
                        xLabels: chartXLabels,
                        yLabels: reportAxisLabels(
                          chartValues.fold(0, math.max),
                        ),
                        labelColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        tooltipOf: (index) {
                          final value = chartValues[index];
                          final title = isYear
                              ? l10n.monthNumber(index + 1)
                              : l10n.dateMonthDay(window!.days[index]);
                          return ChartTooltip(
                            title: title,
                            lines: <ChartTooltipLine>[
                              ChartTooltipLine(
                                text:
                                    '${_type.label(l10n)} ${amountTextOf(value)}',
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    if (statRows.isEmpty)
                      EmptyState(
                        icon: Icons.bar_chart_outlined,
                        title: l10n.homeNoStatsTitle,
                        description: l10n.homeNoStatsDesc,
                      )
                    else
                      for (final row in statRows.indexed) ...<Widget>[
                        _DailyStatTile(
                          row: row.$2,
                          type: _type,
                          onTap: () => _openStatRow(row.$2),
                        ),
                        if (row.$1 != statRows.length - 1) const Divider(),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateWindow _windowForPeriod() => switch (_period) {
    _StatPeriod.week => weekWindowFor(_focusDate),
    _StatPeriod.quarter => quarterWindowFor(_focusDate),
    _StatPeriod.year => monthWindowFor(_focusDate), // 年视图不用此窗口
    _StatPeriod.month => monthWindowFor(_focusDate),
  };

  /// 顶部前后翻页：按当前档位步进（周±7 天、月±1 月、季±3 月、年±1 年）。
  void _shiftFocus(int direction) {
    setState(() {
      _focusDate = switch (_period) {
        _StatPeriod.week => DateTime(
          _focusDate.year,
          _focusDate.month,
          _focusDate.day + direction * 7,
        ),
        _StatPeriod.month => DateTime(
          _focusDate.year,
          _focusDate.month + direction,
        ),
        _StatPeriod.quarter => DateTime(
          _focusDate.year,
          _focusDate.month + direction * 3,
        ),
        _StatPeriod.year => DateTime(
          _focusDate.year + direction,
          _focusDate.month,
        ),
      };
    });
  }

  String _rangeLabel(AppLocalizations l10n, DateWindow? window) =>
      switch (_period) {
        _StatPeriod.week => window!.label,
        _StatPeriod.month => l10n.yearMonth(_focusDate),
        _StatPeriod.quarter => l10n.statQuarterRange(
          _focusDate.year,
          quarterOfMonth(_focusDate.month),
        ),
        _StatPeriod.year => l10n.yearLabel(_focusDate.year),
      };

  /// 点统计行：按天视图点某天进当天交易明细；按月（年视图）点某月下钻到该月视图。
  void _openStatRow(_DailyStatRow row) {
    if (row.monthly) {
      setState(() {
        _period = _StatPeriod.month;
        _focusDate = DateTime(row.date.year, row.date.month);
      });
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => TransactionsPage(initialDate: row.date),
      ),
    );
  }

  Future<void> _pickEntryType() async {
    final selected = await showOptionSheet<EntryType>(
      context: context,
      title: AppLocalizations.of(context).statTypeTitle,
      values: EntryType.userSelectable,
      selected: _type,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      setState(() => _type = selected);
    }
  }
}

class _HomeBudgetRiskBanner extends StatelessWidget {
  const _HomeBudgetRiskBanner({required this.snapshot});

  final CategoryBudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.overBudget ? veriExpense : veriWarning;
    final l10n = AppLocalizations.of(context);
    final text = snapshot.overBudget
        ? l10n.budgetCatOver(
            snapshot.category.label,
            formatAmount(snapshot.spent - snapshot.budget),
          )
        : l10n.budgetCatUsed(
            snapshot.category.label,
            (snapshot.ratio * 100).toStringAsFixed(0),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            snapshot.overBudget
                ? Icons.warning_amber_rounded
                : Icons.error_outline,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyStatRow {
  const _DailyStatRow({
    required this.date,
    required this.amount,
    required this.percent,
    required this.count,
    this.monthly = false,
  });

  final DateTime date;
  final double amount;
  final double percent;
  final int count;

  /// true 为「按月」行（年视图），标题显示月份、点击下钻到该月；false 为「按天」行。
  final bool monthly;
}

class _DailyStatTile extends StatelessWidget {
  const _DailyStatTile({required this.row, required this.type, this.onTap});

  final _DailyStatRow row;
  final EntryType type;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = colorForType(type);
    final amountText = switch (type) {
      EntryType.expense => formatExpenseAmount(row.amount),
      EntryType.income => '+${formatIncomeAmount(row.amount)}',
      EntryType.transfer => formatAmount(row.amount),
      EntryType.refund => '+${formatIncomeAmount(row.amount)}',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            VeriIconBox(
              icon: Icons.calendar_today_outlined,
              color: amountColor,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.monthly
                        ? AppLocalizations.of(
                            context,
                          ).monthNumber(row.date.month)
                        : '${row.date.month.toString().padLeft(2, '0')}.${row.date.day.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${(row.percent * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  amountText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).entriesCount(row.count),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 按天统计行（周/月/季视图）：遍历窗口内每一天，聚合当天该类型的交易。
List<_DailyStatRow> _periodDayRows(
  List<LedgerEntry> entries,
  DateWindow window,
  double total,
) {
  final rows = <_DailyStatRow>[];
  for (final day in window.days) {
    final dayEntries = entries
        .where((entry) => DateUtils.isSameDay(entry.occurredAt, day))
        .toList();
    if (dayEntries.isEmpty) {
      continue;
    }
    final amount = dayEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    rows.add(
      _DailyStatRow(
        date: day,
        amount: amount,
        percent: total <= 0 ? 0 : amount / total,
        count: dayEntries.length,
      ),
    );
  }
  return rows..sort((a, b) => b.date.compareTo(a.date));
}

/// 按月统计行（年视图）：聚合某年 12 个月里有记录的月份。
List<_DailyStatRow> _monthlyStatRows(
  List<LedgerEntry> entries,
  int year,
  double total,
) {
  final rows = <_DailyStatRow>[];
  for (var month = 1; month <= 12; month += 1) {
    final monthEntries = entries
        .where((entry) => entry.occurredAt.month == month)
        .toList();
    if (monthEntries.isEmpty) {
      continue;
    }
    final amount = monthEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    rows.add(
      _DailyStatRow(
        date: DateTime(year, month, 1),
        amount: amount,
        percent: total <= 0 ? 0 : amount / total,
        count: monthEntries.length,
        monthly: true,
      ),
    );
  }
  return rows..sort((a, b) => b.date.compareTo(a.date));
}
