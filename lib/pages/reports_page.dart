import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/currency_math.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/report_analysis.dart';
import '../app/root_navigation.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import 'ai_chat_page.dart';
import 'budget_pages.dart';
import 'currency_rates_page.dart';
import 'panel_settings_page.dart';
import 'sheets.dart';
import 'transactions_pages.dart';
import '../l10n/app_localizations.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  /// 看板顶部统计口径 Tab。默认落在「日常」；不做持久化，每次进入都回到它。
  ReportPeriodTab _tab = ReportPeriodTab.daily;

  /// 月统计 / 年统计的焦点期间，默认本月 / 今年。
  ///
  /// 与当前 Tab 一样属于临时界面状态：不持久化、不进备份、不改动任何账目，
  /// 离开看板后下次进入回到默认期间。
  DateTime _monthFocus = DateTime.now();
  int _yearFocus = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = controller.entries;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final monthWindow = monthWindowFor(_monthFocus);
    final yearWindow = _yearWindow(_yearFocus);
    final isCurrentMonth = monthIndexOf(_monthFocus) == monthIndexOf(thisMonth);
    final isCurrentYear = _yearFocus == now.year;
    // 预算执行卡按预算周期取数（键月 + 周期窗口）；看板其余统计仍按自然月。
    // 「本月」取当前正在跑的那一期（自定义周期起始日时它可能落在上一个键月），
    // 选定某个过去月份则直接以该月为键月——用户点的是月份，不是日期。
    final budgetKeyMonth = isCurrentMonth
        ? controller.budgetKeyMonthFor(now)
        : _monthFocus;
    final budgetEntries = entriesInWindow(
      entries,
      controller.budgetWindow(budgetKeyMonth),
    );
    // 预算执行卡按预算口径取数：排除标记「不计入预算」的交易，看板其余统计
    // 仍按自然月、按实际发生（标记不影响收支统计）。
    final budgetExpense = budgetExpenseTotal(budgetEntries);
    final monthlyBudget = controller.monthlyBudget(budgetKeyMonth);
    final categoryBudgetSnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: budgetKeyMonth,
      monthEntries: budgetEntries,
    );
    final panelIds = controller.enabledPanelIds(_tab.panelPageKind);

    // 面板 id 对应的卡片,渲染顺序与开关由面板管理页配置。
    Widget panelFor(String id) {
      switch (id) {
        case 'recent_daily':
          return const _RecentDailyStatsPanel();
        case 'asset_summary':
          return const _AssetSummaryPanel();
        case 'summary':
          return _PeriodSummaryPanel(
            window: monthWindow,
            // 默认（本月）沿用「本月收支」；切到历史月份时标题直接写明那一期。
            title: isCurrentMonth
                ? l10n.panelSummaryLabel
                : l10n.yearMonth(_monthFocus),
            trailing: isCurrentMonth
                ? l10n.monthNumber(_monthFocus.month)
                : null,
            incomeLabel: isCurrentMonth
                ? l10n.metricMonthIncome
                : l10n.metricIncome,
            expenseLabel: isCurrentMonth
                ? l10n.metricMonthExpense
                : l10n.metricExpense,
            netLabel: isCurrentMonth ? l10n.metricMonthNet : l10n.metricNet,
          );
        case 'year_summary':
          return _PeriodSummaryPanel(
            window: yearWindow,
            // 看今年沿用「本年收支」；看历史年份时标题去掉「本」、把年份放到右上角
            // 角标——标题位置写一个光秃秃的「2025年」既不像卡片标题，也丢了「收支」。
            title: isCurrentYear
                ? l10n.panelYearSummaryLabel
                : l10n.panelYearSummaryPeriodLabel,
            trailing: isCurrentYear
                ? l10n.timeYear
                : l10n.yearNumber(DateTime(_yearFocus)),
            incomeLabel: isCurrentYear
                ? l10n.metricYearIncome
                : l10n.metricIncome,
            expenseLabel: isCurrentYear
                ? l10n.metricYearExpense
                : l10n.metricExpense,
            netLabel: isCurrentYear ? l10n.metricYearNet : l10n.metricNet,
          );
        case 'budget_execution':
          return _BudgetExecutionCard(
            budget: monthlyBudget,
            expense: budgetExpense,
            keyMonth: budgetKeyMonth,
            snapshots: categoryBudgetSnapshots,
          );
        case 'category_stats':
          return _CategoryStatsPanel(window: monthWindow);
        case 'ranking':
          return _RankingPanel(
            window: _tab == ReportPeriodTab.yearly ? yearWindow : monthWindow,
          );
        case 'year_trend':
          return _YearTrendPanel(
            year: _yearFocus,
            // 角标写当前看的年份：今年是「今年」，其余年份直接写年份。
            trailing: isCurrentYear
                ? l10n.thisYearLabel
                : l10n.yearNumber(DateTime(_yearFocus)),
          );
        case 'year_heatmap':
          return _YearHeatmapPanel(year: _yearFocus);
        case 'daily_trend':
          // 本月用累积展开窗口（1–7、1–14……只画到今天，不把未来日期塞进横轴）；
          // 看历史月份时那一个月已经走完，直接给整月窗口。
          final trendWindow = isCurrentMonth
              ? cumulativeWeekWindowFor(now)
              : monthWindow;
          final trendValues = valuesForTypeInWindow(
            entries,
            trendWindow,
            EntryType.expense,
          );
          final trendExpense = trendValues.fold<double>(
            0,
            (sum, value) => sum + value,
          );
          final trendMax = trendValues.fold<double>(
            0,
            (max, value) => value > max ? value : max,
          );
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: l10n.panelDailyTrendLabel,
                  trailing: formatExpenseAmount(trendExpense),
                ),
                const SizedBox(height: 16),
                if (isZeroAmount(trendExpense))
                  EmptyState(
                    icon: Icons.show_chart,
                    title: l10n.noDimData(l10n.entryTypeExpense),
                    description: l10n.noDimDesc(l10n.entryTypeExpense),
                  )
                else
                  SizedBox(
                    height: 138,
                    child: InteractiveTrendChart(
                      color: veriSemantic(context, veriExpense),
                      values: trendValues,
                      xLabels: sparseLabelsForWindow(trendWindow),
                      yLabels: reportAxisLabels(trendMax),
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.50),
                      tooltipOf: (index) {
                        final day = trendWindow.days[index];
                        return ChartTooltip(
                          title: l10n.dateMonthDay(day),
                          lines: <ChartTooltipLine>[
                            ChartTooltipLine(
                              text: l10n.expenseAmountLabel(
                                formatExpenseAmount(trendValues[index]),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return VeriPage(
      child: ListView(
        padding: veriRootPageListPadding(context),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabReports,
            subtitle: currencyUnitSubtitle(
              AppLocalizations.of(context),
              AppLocalizations.of(context).reportsSubtitle,
              controller.activeBook.baseCurrencyCode,
            ),
            trailing: HeaderAction(
              icon: Icons.smart_toy_outlined,
              tooltip: AppLocalizations.of(context).aiChatTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiChatPage()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          VeriSegmentedControl<ReportPeriodTab>(
            values: ReportPeriodTab.values,
            selected: _tab,
            semanticLabel: l10n.statRangeLabel,
            labelOf: (tab) => tab.label(l10n),
            // 与记账页 `entry_type_selected_*` 同一契约：Key 只挂在选中项上
            // （分段控件会把选中项多渲染一份用于滑动动画）。
            keyOf: (tab) =>
                tab == _tab ? Key('reports_tab_selected_${tab.name}') : null,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          // 期间栏只服务月统计与年统计：「日常」是当下快照，没有可切换的期间。
          if (_tab != ReportPeriodTab.daily) ...<Widget>[
            const SizedBox(height: 8),
            _buildPeriodBar(context, l10n),
          ],
          // 各 Tab 的面板清单互相独立，顺序与开关由面板管理页配置。
          // 没有面板的 Tab 只画 Tab 本体，不渲染占位文案。
          for (final id in panelIds) ...<Widget>[
            const SizedBox(height: 10),
            panelFor(id),
          ],
          if (panelIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            PanelSettingsEntry(kind: _tab.panelPageKind),
          ],
        ],
      ),
    );
  }

  /// 期间栏：`‹ 2026年9月 ›` 步进 + 点标签打开选择弹层 + 非本期时的「本月 / 今年」回跳。
  ///
  /// 范围由账本自己界定：下界是首笔记账，上界是本月的当前时刻，两头都不会翻到
  /// 未来或空白期间，到边界时箭头禁用。期间不写 Controller，也不进备份。
  Widget _buildPeriodBar(BuildContext context, AppLocalizations l10n) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final entries = VeriFinScope.of(context).entries;
    final firstDate = earliestEntryDate(entries) ?? thisMonth;
    final monthly = _tab == ReportPeriodTab.monthly;
    final atStart = monthly
        ? monthIndexOf(_monthFocus) <=
              monthIndexOf(DateTime(firstDate.year, firstDate.month))
        : _yearFocus <= firstDate.year;
    final atEnd = monthly
        ? monthIndexOf(_monthFocus) >= monthIndexOf(thisMonth)
        : _yearFocus >= now.year;
    return Row(
      children: <Widget>[
        MonthSwitcher(
          label: monthly
              ? l10n.yearMonth(_monthFocus)
              : l10n.yearNumber(DateTime(_yearFocus)),
          labelKey: const Key('reports_period_label'),
          labelTooltip: monthly
              ? l10n.periodPickMonthTitle
              : l10n.periodPickYearTitle,
          previousTooltip: monthly
              ? l10n.calendarPrevMonth
              : l10n.calendarPrevYear,
          nextTooltip: monthly ? l10n.calendarNextMonth : l10n.calendarNextYear,
          onPrevious: atStart ? null : () => setState(() => _shiftPeriod(-1)),
          onNext: atEnd ? null : () => setState(() => _shiftPeriod(1)),
          onLabelTap: () =>
              _pickPeriod(context, firstDate: firstDate, today: now),
        ),
        const Spacer(),
        // 回跳入口常显：在本期时置灰（Material 禁用态）而不是整块消失，否则右侧
        // 会空出一块，期间栏看起来像断了一截。
        _jumpToCurrent(
          monthly ? l10n.thisMonth : l10n.thisYearLabel,
          monthly
              ? (monthIndexOf(_monthFocus) == monthIndexOf(thisMonth)
                    ? null
                    : () => setState(() => _monthFocus = thisMonth))
              : (_yearFocus == now.year
                    ? null
                    : () => setState(() => _yearFocus = now.year)),
        ),
      ],
    );
  }

  /// 回跳按钮：回到本月 / 今年；已在本期时传 `onPressed: null`，按钮保持可见但禁用。
  Widget _jumpToCurrent(String label, VoidCallback? onPressed) {
    return TextButton(
      key: const Key('reports_period_jump'),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  /// 步进一期。月份用 `DateTime` 的溢出规则跨年（1 月往前是上一年 12 月）。
  void _shiftPeriod(int direction) {
    if (_tab == ReportPeriodTab.monthly) {
      _monthFocus = DateTime(_monthFocus.year, _monthFocus.month + direction);
    } else {
      _yearFocus += direction;
    }
  }

  Future<void> _pickPeriod(
    BuildContext context, {
    required DateTime firstDate,
    required DateTime today,
  }) async {
    if (_tab == ReportPeriodTab.monthly) {
      final picked = await showMonthPickerSheet(
        context: context,
        selected: _monthFocus,
        firstDate: firstDate,
        today: today,
      );
      if (picked != null && mounted) {
        setState(() => _monthFocus = picked);
      }
      return;
    }
    final picked = await showYearPickerSheet(
      context: context,
      selected: _yearFocus,
      firstDate: firstDate,
      today: today,
    );
    if (picked != null && mounted) {
      setState(() => _yearFocus = picked);
    }
  }
}

/// 资产汇总的口径：只统计余额为正的账户，或只统计余额为负的账户。
enum _AssetSide { positive, negative }

/// 日常 Tab 的资产汇总面板：环形图 + 图例，点中心在金额 / 占比之间切换。
///
/// 只统计**计入资产**且**未隐藏**的账户（与资产页净资产口径一致），否则环里
/// 各段加不出中心数字。任一账户缺汇率时整卡退化为缺率空态，不展示部分和。
class _AssetSummaryPanel extends StatefulWidget {
  const _AssetSummaryPanel();

  @override
  State<_AssetSummaryPanel> createState() => _AssetSummaryPanelState();
}

class _AssetSummaryPanelState extends State<_AssetSummaryPanel> {
  _AssetSide _side = _AssetSide.positive;
  bool _showShare = false;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final baseCurrency = controller.activeBook.baseCurrencyCode;
    final accounts = controller.accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .toList(growable: false);
    final valuation = controller.accountBalancesInBase(accounts: accounts);
    final sign = _side == _AssetSide.positive ? 1.0 : -1.0;
    final holdings = <({Account account, double amount})>[
      for (final account in accounts)
        if ((valuation.amountsByAccountId[account.id] ?? 0) * sign > 0)
          (
            account: account,
            // 保留原值符号：负资产侧要显示成负数，不能自动转正。
            amount: valuation.amountsByAccountId[account.id] ?? 0,
          ),
    ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    final total = normalizeAmount(
      holdings.fold<double>(0, (sum, holding) => sum + holding.amount),
    );

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: l10n.panelAssetSummaryLabel,
            trailingWidget: VeriSegmentedControl<_AssetSide>(
              compact: true,
              values: const <_AssetSide>[
                _AssetSide.positive,
                _AssetSide.negative,
              ],
              selected: _side,
              semanticLabel: l10n.panelAssetSummaryLabel,
              labelOf: (side) => side == _AssetSide.positive
                  ? l10n.assetPositive
                  : l10n.assetNegative,
              keyOf: (side) =>
                  side == _side ? Key('asset_summary_side_${side.name}') : null,
              onChanged: (side) => setState(() {
                _side = side;
              }),
            ),
          ),
          const SizedBox(height: 12),
          if (!valuation.isComplete)
            AssetMissingRateNotice(
              affectedAccountCount: valuation.affectedAccountIds.length,
              currencyCodes: valuation.missingCurrencyCodes,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CurrencyRatesPage(),
                ),
              ),
            )
          else if (holdings.isEmpty)
            EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.noDimData(
                _side == _AssetSide.positive
                    ? l10n.assetPositive
                    : l10n.assetNegative,
              ),
              description: l10n.panelAssetSummaryDesc,
            )
          else
            _AssetSummaryChart(
              holdings: holdings,
              total: total,
              baseCurrency: baseCurrency,
              showShare: _showShare,
              onToggleMode: () => setState(() => _showShare = !_showShare),
            ),
        ],
      ),
    );
  }
}

/// 环形图 + 图例；中心可点，用于在金额 / 占比之间切换。
class _AssetSummaryChart extends StatefulWidget {
  const _AssetSummaryChart({
    required this.holdings,
    required this.total,
    required this.baseCurrency,
    required this.showShare,
    required this.onToggleMode,
  });

  final List<({Account account, double amount})> holdings;
  final double total;
  final String baseCurrency;
  final bool showShare;
  final VoidCallback onToggleMode;

  @override
  State<_AssetSummaryChart> createState() => _AssetSummaryChartState();
}

class _AssetSummaryChartState extends State<_AssetSummaryChart> {
  int? _selectedIndex;

  /// 图例默认只列前 5 个账户；账户更多时提供「展开全部」，把选择权交给用户。
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final neutral = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final colors = veriChartPalette(context);
    final limit = _showAll ? widget.holdings.length : 5;
    final visible = widget.holdings.take(limit).toList();
    final hidden = widget.holdings.skip(limit).toList();
    final otherAmount = hidden.fold<double>(
      0,
      (sum, holding) => sum + holding.amount,
    );
    final legend = <({String label, double amount, Color color})>[
      for (final item in visible.indexed)
        (
          label: item.$2.account.name,
          amount: item.$2.amount,
          color: colors[item.$1 % colors.length],
        ),
      // 按绝对值判断：负资产侧的各项与合计都是负数，用 `> 0` 会让这里的
      // 「其他」永远不出现，第 6 个起的账户被静默丢掉。
      if (otherAmount.abs() > 0)
        (label: l10n.othersLabel, amount: otherAmount, color: neutral),
    ];
    final segments = <VeriDonutSegment>[
      for (final item in legend)
        VeriDonutSegment(
          label: item.label,
          // 环图分段按绝对值取长度，符号只体现在中心与图例的文本上。
          value: item.amount.abs(),
          color: item.color,
        ),
    ];
    final selected = _selectedIndex != null && _selectedIndex! < legend.length
        ? _selectedIndex
        : null;
    final total = widget.total;
    // 负资产侧 total 为负：占比按绝对值算，文本仍展示带符号的原值。
    final totalMagnitude = total.abs();
    final shareDenominator = totalMagnitude == 0 ? 1.0 : totalMagnitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 156,
            height: 156,
            child: VeriDonutChart(
              segments: segments,
              selectedIndex: selected,
              onSelected: (index) => setState(() => _selectedIndex = index),
              ringWidth: 30,
              showPercentTitles: true,
              onCenterTap: widget.onToggleMode,
              semanticsLabel: l10n.panelAssetSummaryLabel,
              // 固定大小的中心热区：点在环内空白处也应能切换口径，
              // 不能只有那两行文字可点（尺寸留在圆孔内，不压到环上）。
              center: SizedBox(
                width: 88,
                height: 88,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.showShare
                                ? l10n.assetSummaryShare
                                : l10n.assetSummaryAmount,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.56),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Icon(
                            Icons.swap_horiz,
                            size: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.56),
                          ),
                        ],
                      ),
                      Text(
                        formatUserMoney(total, widget.baseCurrency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in legend)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.showShare
                      ? '${(item.amount.abs() / shareDenominator * 100).toStringAsFixed(1)}%'
                      : formatUserMoney(item.amount, widget.baseCurrency),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (widget.holdings.length > 5)
          InkWell(
            key: const Key('asset_summary_expand_toggle'),
            borderRadius: BorderRadius.circular(veriRadiusSm),
            onTap: () => setState(() => _showAll = !_showAll),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _showAll
                        ? l10n.assetSummaryCollapse
                        : l10n.assetSummaryShowAll(widget.holdings.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    _showAll ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 近 7 日统计的时间范围：滚动 7 天，或自然周（周一至周日，含今天）。
enum _RecentDailyRange { last7Days, thisWeek }

/// 日常 Tab 的收支统计面板：柱状图 + 总额 / 日均（支出与收入同时给出）。
class _RecentDailyStatsPanel extends StatefulWidget {
  const _RecentDailyStatsPanel();

  @override
  State<_RecentDailyStatsPanel> createState() => _RecentDailyStatsPanelState();
}

class _RecentDailyStatsPanelState extends State<_RecentDailyStatsPanel> {
  _RecentDailyRange _range = _RecentDailyRange.last7Days;
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final today = dateOnly(DateTime.now());
    final window = _range == _RecentDailyRange.thisWeek
        ? weekWindowFor(today)
        : DateWindow(start: addCalendarDays(today, -6), end: today);
    final expenseValues = valuesForTypeInWindow(
      controller.entries,
      window,
      EntryType.expense,
    );
    final incomeValues = valuesForTypeInWindow(
      controller.entries,
      window,
      EntryType.income,
    );
    final expenseTotal = _sumValues(expenseValues);
    final incomeTotal = _sumValues(incomeValues);
    final expense = _type == EntryType.expense;
    final chartValues = expense ? expenseValues : incomeValues;
    final chartTotal = expense ? expenseTotal : incomeTotal;
    final maxValue = chartValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final dimLabel = _type.label(l10n);

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            // 标题跟着口径走（近7日统计 / 本周统计），旁边的小图标按钮切换口径。
            title: _range == _RecentDailyRange.last7Days
                ? l10n.panelRecentDailyLabel
                : l10n.panelThisWeekLabel,
            titleSuffix: Tooltip(
              message: l10n.statRangeLabel,
              child: InkWell(
                key: const Key('recent_daily_range_toggle'),
                borderRadius: BorderRadius.circular(veriRadiusSm),
                onTap: () => setState(
                  () => _range = _range == _RecentDailyRange.last7Days
                      ? _RecentDailyRange.thisWeek
                      : _RecentDailyRange.last7Days,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.swap_horiz,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ),
            ),
            // 右上角留给支出 / 收入切换，与资产汇总的口径切换同为紧凑档。
            trailingWidget: VeriEntryTypeToggle(
              compact: true,
              dimension: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
          ),
          const SizedBox(height: 16),
          if (isZeroAmount(chartTotal))
            EmptyState(
              icon: Icons.bar_chart_outlined,
              title: l10n.noDimData(dimLabel),
              description: l10n.noDimDesc(dimLabel),
            )
          else
            SizedBox(
              height: 138,
              child: InteractiveBarChart(
                values: chartValues,
                // 柱子颜色跟着口径走：支出语义红、收入语义青，方向不只靠标题。
                color: expense
                    ? veriSemantic(context, veriExpense)
                    : veriSemantic(context, veriIncome),
                xLabels: _range == _RecentDailyRange.thisWeek
                    ? window.days
                          .map((day) => _weekdayLabel(l10n, day))
                          .toList(growable: false)
                    : labelsForWindow(window),
                yLabels: reportAxisLabels(maxValue),
                labelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.50),
                tooltipOf: (index) => ChartTooltip(
                  title: l10n.dateMonthDay(window.days[index]),
                  lines: <ChartTooltipLine>[
                    ChartTooltipLine(
                      text: expense
                          ? l10n.expenseAmountLabel(
                              formatExpenseAmount(chartValues[index]),
                            )
                          : l10n.incomeAmountLabel(
                              formatIncomeAmount(chartValues[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _RecentStatLine(
                  label: l10n.recentTotalExpense,
                  value: formatExpenseAmount(expenseTotal),
                ),
              ),
              Expanded(
                child: _RecentStatLine(
                  label: l10n.recentDailyAvgExpense,
                  value: formatExpenseAmount(_dailyAverage(expenseTotal)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _RecentStatLine(
                  label: l10n.recentTotalIncome,
                  // 与支出侧一致：零值显示「0」，不带小数。
                  value: formatIncomeAmount(incomeTotal),
                ),
              ),
              Expanded(
                child: _RecentStatLine(
                  label: l10n.recentDailyAvgIncome,
                  value: formatIncomeAmount(_dailyAverage(incomeTotal)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 面板内的合计：规整到最小货币单位，避免浮点残差。
double _sumValues(List<double> values) =>
    normalizeAmount(values.fold<double>(0, (sum, value) => sum + value));

/// 日均固定按 7 天折算（滚动 7 日与自然周两种窗口都对齐）。
double _dailyAverage(double total) => normalizeAmount(total / 7);

String _weekdayLabel(AppLocalizations l10n, DateTime day) {
  switch (day.weekday) {
    case DateTime.monday:
      return l10n.weekdayMon;
    case DateTime.tuesday:
      return l10n.weekdayTue;
    case DateTime.wednesday:
      return l10n.weekdayWed;
    case DateTime.thursday:
      return l10n.weekdayThu;
    case DateTime.friday:
      return l10n.weekdayFri;
    case DateTime.saturday:
      return l10n.weekdaySat;
    default:
      return l10n.weekdaySun;
  }
}

/// 「标签：金额」一行的紧凑排布（近 7 日面板底部两列两行）。
class _RecentStatLine extends StatelessWidget {
  const _RecentStatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).recentStatLine(label, value),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// 整年窗口（1 月 1 日到 12 月 31 日），用于年统计 Tab。
DateWindow _yearWindow(int year) =>
    DateWindow(start: DateTime(year, 1, 1), end: DateTime(year, 12, 31));

/// 期间收支摘要面板：窗口内的收入 / 支出 / 结余（各带笔数）。
/// 月统计用整月窗口、年统计用整年窗口；原先是页面顶部无法关闭的固定条，
/// 现在与其它面板一样可开关、可排序。
class _PeriodSummaryPanel extends StatelessWidget {
  const _PeriodSummaryPanel({
    required this.window,
    required this.title,
    required this.trailing,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.netLabel,
  });

  final DateWindow window;
  final String title;
  final String? trailing;
  final String incomeLabel;
  final String expenseLabel;
  final String netLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = entriesInWindow(VeriFinScope.of(context).entries, window);
    final income = sumByType(entries, EntryType.income);
    final expense = sumByType(entries, EntryType.expense);
    final net = income - expense;
    final incomeCount = entries
        .where((entry) => entry.type == EntryType.income)
        .length;
    final expenseCount = entries
        .where((entry) => entry.type == EntryType.expense)
        .length;
    final zeroColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.48);
    return VeriCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: title, trailing: trailing),
          const SizedBox(height: 12),
          Row(
            // 指标列高度可能不同（收入/支出带笔数），顶部对齐才不会错位。
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SummaryMetric(
                label: incomeLabel,
                value: formatIncomeAmount(income),
                color: isZeroAmount(income)
                    ? zeroColor
                    : veriSemantic(context, veriIncome),
                detail: l10n.entriesCount(incomeCount),
              ),
              SummaryMetric(
                label: expenseLabel,
                value: formatExpenseAmount(expense),
                color: isZeroAmount(expense)
                    ? zeroColor
                    : veriSemantic(context, veriExpense),
                detail: l10n.entriesCount(expenseCount),
              ),
              SummaryMetric(
                label: netLabel,
                value: formatSignedAmount(net),
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetExecutionCard extends StatelessWidget {
  const _BudgetExecutionCard({
    required this.budget,
    required this.expense,
    required this.keyMonth,
    required this.snapshots,
  });

  final double budget;
  final double expense;

  /// 当期预算周期的键月（预算存储键）。角标据此展示所属周期。
  final DateTime keyMonth;

  final List<CategoryBudgetSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    // 自定义预算周期时角标展示周期日期范围，自然月展示「N月」。
    final periodBadge = controller.budgetCycleIsCustom
        ? AppLocalizations.of(context).budgetCycleRange(
            controller.budgetWindow(keyMonth).start,
            controller.budgetWindow(keyMonth).end,
          )
        : AppLocalizations.of(context).monthNumber(keyMonth.month);
    final ratio = budget <= 0 ? 0.0 : expense / budget;
    final remaining = budget - expense;
    final budgetedCount = snapshots
        .where((snapshot) => snapshot.hasBudget)
        .length;
    final overBudgetCount = snapshots
        .where((snapshot) => snapshot.overBudget)
        .length;
    final color = budget <= 0
        ? veriLine
        : remaining < 0
        ? veriSemantic(context, veriExpense)
        : ratio >= 0.85
        ? veriSemantic(context, veriWarning)
        : Theme.of(context).colorScheme.primary;

    return VeriCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // 首页预算面板可被用户在面板管理里关闭，此卡是关掉后进入预算总览的唯一入口。
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => BudgetOverviewPage(initialMonth: keyMonth),
        ),
      ),
      quietTap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 与其他面板共用 SectionTitle，保证「预算执行」标题与同页其它卡片同级。
          SectionTitle(
            title: AppLocalizations.of(context).panelBudgetExecutionLabel,
            trailing: periodBadge,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      budget <= 0
                          ? AppLocalizations.of(context).notSetBudget
                          : remaining < 0
                          ? AppLocalizations.of(context).overBudgetLabel
                          : AppLocalizations.of(context).remainingBudgetLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget <= 0
                          ? formatExpenseAmount(expense)
                          : remaining < 0
                          ? formatExpenseAmount(remaining)
                          : formatAmount(remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            // 无预算时这里展示实际支出，不能继承进度条的浅分隔线色。
                            color: budget <= 0
                                ? (isZeroAmount(expense)
                                      ? Theme.of(context).colorScheme.onSurface
                                      : colorForType(
                                          context,
                                          EntryType.expense,
                                        ))
                                : color,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                budget <= 0
                    ? AppLocalizations.of(context).expenseOnlyNote
                    : AppLocalizations.of(
                        context,
                      ).usedPercent((ratio * 100).toStringAsFixed(0)),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 0 : ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          // 与本页顶部的收支摘要卡共用 SummaryMetric，保证三块指标的标签/数值字号
          // 与同页其它卡片一致。
          Row(
            children: <Widget>[
              SummaryMetric(
                label: AppLocalizations.of(context).monthBudgetLabel,
                value: formatAmount(budget),
                color: scheme.onSurface,
              ),
              SummaryMetric(
                label: AppLocalizations.of(context).budgetMonthExpense,
                value: formatExpenseAmount(expense),
                color: veriSemantic(context, veriExpense),
              ),
              SummaryMetric(
                label: AppLocalizations.of(context).categoryBudgetTitle,
                value: AppLocalizations.of(context).countItems(budgetedCount),
                color: scheme.onSurface,
                // 未设分类预算时没有「执行情况」可判断，绿色「正常」会被误读为
                // 已设预算且执行良好。
                detail: overBudgetCount > 0
                    ? AppLocalizations.of(
                        context,
                      ).overCountLabel(overBudgetCount)
                    : budgetedCount == 0
                    ? AppLocalizations.of(context).notSet
                    : AppLocalizations.of(context).normalLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分类统计的展示范围：前 5 个分类 + 其他，或全部分类各自成段。
enum _CategoryStatsRange { top5, all }

const String _categoryStatsOtherKey = '__category_stats_other__';

/// 一个分类环图分段。`key` 用聚合原始 key（分类 id）而不是显示对象，避免
/// 「已删除分类」占位或分类排序变化后选中项指向别的分类。
class _CategoryStatsSlice {
  const _CategoryStatsSlice({
    required this.key,
    required this.label,
    required this.amount,
    required this.percent,
    this.isOther = false,
  });

  final String key;
  final String label;
  final double amount;
  final double percent;
  final bool isOther;
}

List<_CategoryStatsSlice> _categoryStatsSlices({
  required List<ReportCategoryStat> stats,
  required double total,
  required _CategoryStatsRange range,
  required AppLocalizations l10n,
}) {
  if (total <= 0) {
    return const <_CategoryStatsSlice>[];
  }
  _CategoryStatsSlice sliceOf(ReportCategoryStat stat) => _CategoryStatsSlice(
    key: stat.categoryId,
    label: stat.category.label,
    amount: stat.amount,
    percent: stat.amount / total,
  );
  if (range == _CategoryStatsRange.all || stats.length <= 5) {
    return <_CategoryStatsSlice>[for (final stat in stats) sliceOf(stat)];
  }
  final otherAmount = stats
      .skip(5)
      .fold<double>(0, (sum, stat) => sum + stat.amount);
  return <_CategoryStatsSlice>[
    for (final stat in stats.take(5)) sliceOf(stat),
    if (otherAmount > 0)
      _CategoryStatsSlice(
        key: _categoryStatsOtherKey,
        label: l10n.othersLabel,
        amount: otherAmount,
        percent: otherAmount / total,
        isOther: true,
      ),
  ];
}

/// 月统计的支出分类构成卡：默认前 5 个顶级分类 + 其他，右上角可切「前5 / 全部」。
///
/// 取数复用 `reportCategoryStats`：按顶级分类归总、使用已到账退款冲减后的净额，
/// 不读取 `excludedFromBudget`——本卡与排行、月收支摘要同属「实际支出」口径，
/// 预算执行卡才排除「不计入预算」的交易。
class _CategoryStatsPanel extends StatefulWidget {
  const _CategoryStatsPanel({required this.window});

  final DateWindow window;

  @override
  State<_CategoryStatsPanel> createState() => _CategoryStatsPanelState();
}

class _CategoryStatsPanelState extends State<_CategoryStatsPanel> {
  _CategoryStatsRange _range = _CategoryStatsRange.top5;
  String? _selectedKey;

  @override
  void didUpdateWidget(covariant _CategoryStatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换月份后旧分类可能已不在结果里；清掉选中，避免中心显示上个月的选择。
    if (oldWidget.window.start != widget.window.start ||
        oldWidget.window.end != widget.window.end) {
      _selectedKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = reportCategoryStats(
      entriesInWindow(controller.entries, widget.window),
      controller.categories,
      EntryType.expense,
    ).where((stat) => stat.amount > 0).toList(growable: false);
    final total = normalizeAmount(
      stats.fold<double>(0, (sum, stat) => sum + stat.amount),
    );
    final canToggle = stats.length > 5;
    final range = canToggle ? _range : _CategoryStatsRange.top5;
    final slices = _categoryStatsSlices(
      stats: stats,
      total: total,
      range: range,
      l10n: l10n,
    );
    final rawSelectedIndex = _selectedKey == null
        ? -1
        : slices.indexWhere((slice) => slice.key == _selectedKey);
    final selectedIndex = rawSelectedIndex >= 0 ? rawSelectedIndex : null;
    final selected = selectedIndex == null ? null : slices[selectedIndex];
    final palette = veriChartPalette(context);
    final neutral = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final segmentColors = <Color>[
      for (var i = 0; i < slices.length; i++)
        slices[i].isOther ? neutral : palette[i % palette.length],
    ];
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.56);

    return VeriCard(
      key: const Key('category_stats_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: l10n.panelCategoryStatsLabel,
            trailingWidget: canToggle
                ? VeriSegmentedControl<_CategoryStatsRange>(
                    compact: true,
                    values: const <_CategoryStatsRange>[
                      _CategoryStatsRange.top5,
                      _CategoryStatsRange.all,
                    ],
                    selected: range,
                    semanticLabel: l10n.categoryStatsModeLabel,
                    labelOf: (value) => value == _CategoryStatsRange.top5
                        ? l10n.categoryStatsModeTop5
                        : l10n.categoryStatsModeAll,
                    keyOf: (value) => value == range
                        ? Key('category_stats_range_${value.name}')
                        : null,
                    onChanged: (value) => setState(() {
                      _range = value;
                      _selectedKey = null;
                    }),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (isZeroAmount(total))
            EmptyState(
              icon: Icons.donut_small_outlined,
              title: l10n.noDimData(l10n.entryTypeExpense),
              description: l10n.noDimDesc(l10n.entryTypeExpense),
            )
          else ...<Widget>[
            Center(
              child: SizedBox(
                width: 156,
                height: 156,
                child: VeriDonutChart(
                  segments: <VeriDonutSegment>[
                    for (var i = 0; i < slices.length; i++)
                      VeriDonutSegment(
                        label: slices[i].label,
                        value: slices[i].amount,
                        color: segmentColors[i],
                      ),
                  ],
                  selectedIndex: selectedIndex,
                  onSelected: (index) => setState(() {
                    _selectedKey = index == null ? null : slices[index].key;
                  }),
                  onCenterTap: () => setState(() => _selectedKey = null),
                  ringWidth: 30,
                  showPercentTitles: true,
                  semanticsLabel: l10n.panelCategoryStatsLabel,
                  center: SizedBox(
                    width: 88,
                    height: 88,
                    child: Center(
                      child: selected == null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  l10n.entryTypeExpense,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  formatExpenseAmount(total),
                                  key: const Key('category_stats_center_total'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  selected.label,
                                  key: const Key('category_stats_center_label'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  formatExpenseAmount(selected.amount),
                                  key: const Key(
                                    'category_stats_center_amount',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${(selected.percent * 100).toStringAsFixed(1)}%',
                                  key: const Key(
                                    'category_stats_center_percent',
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < slices.length; i++)
              _CategoryStatsLegendRow(
                color: segmentColors[i],
                label: slices[i].label,
                amount: slices[i].amount,
              ),
          ],
        ],
      ),
    );
  }
}

/// 分类统计图例的一行：色点 + 名称 + 金额。金额与圆环同为本位币实际支出。
class _CategoryStatsLegendRow extends StatelessWidget {
  const _CategoryStatsLegendRow({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatExpenseAmount(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组口径：顶级分类（子分类金额并入父类）/ 记账所选子分类 / 标签。
enum _RankGrouping { topCategory, subCategory, tag }

/// 月统计的排行卡：分类 / 子分类 / 标签排行，点行可下钻到子分类拆分与交易列表。
/// 聚合口径来自 `report_analysis.dart` 的纯函数（与 AI 账目查询工具共用）。
class _RankingPanel extends StatefulWidget {
  const _RankingPanel({required this.window});

  /// 排行取数窗口：月统计传整月、年统计传整年。
  final DateWindow window;

  @override
  State<_RankingPanel> createState() => _RankingPanelState();
}

class _RankingPanelState extends State<_RankingPanel> {
  /// 卡片内最多展示的排行行数，避免单卡过长。
  static const int _maxRows = 8;

  _RankGrouping _grouping = _RankGrouping.topCategory;
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = entriesInWindow(controller.entries, widget.window);
    final color = _type == EntryType.expense
        ? veriSemantic(context, veriExpense)
        : veriSemantic(context, veriIncome);

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: l10n.panelRankingLabel,
            // 右上角是「看什么口径」（支出 / 收入），与其它卡片的右上角一致。
            trailingWidget: VeriEntryTypeToggle(
              compact: true,
              dimension: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
          ),
          const SizedBox(height: 10),
          // 分组维度（分类 / 子分类 / 标签）放在标题下方，同样是紧凑档。
          VeriSegmentedControl<_RankGrouping>(
            compact: true,
            values: _RankGrouping.values,
            selected: _grouping,
            semanticLabel: l10n.rankGroupingLabel,
            labelOf: (grouping) => switch (grouping) {
              _RankGrouping.topCategory => l10n.rankGroupCategory,
              _RankGrouping.subCategory => l10n.rankGroupSubCategory,
              _RankGrouping.tag => l10n.rankGroupTag,
            },
            // Key 只挂选中项：分段控件会把选中项多渲染一份用于滑动动画。
            keyOf: (grouping) => grouping == _grouping
                ? Key('ranking_group_${grouping.name}')
                : null,
            onChanged: (grouping) => setState(() {
              _grouping = grouping;
            }),
          ),
          const SizedBox(height: 8),
          _buildBody(context, entries, color),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<LedgerEntry> entries,
    Color color,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    switch (_grouping) {
      case _RankGrouping.topCategory:
      case _RankGrouping.subCategory:
        final stats =
            (_grouping == _RankGrouping.subCategory
                    ? reportCategoryStatsByOwn(
                        entries,
                        controller.categories,
                        _type,
                      )
                    : reportCategoryStats(
                        entries,
                        controller.categories,
                        _type,
                      ))
                .take(_maxRows);
        if (stats.isEmpty) {
          return _emptyState(context);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final stat in stats)
              _RankRow(
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
                // 顶级分类点行看子分类拆分；子分类点行直接去筛选后的交易列表。
                onTap: _grouping == _RankGrouping.topCategory
                    ? () => _showSubCategoryDrill(context, entries, stat)
                    : () => _openCategoryEntries(stat.categoryId),
              ),
          ],
        );
      case _RankGrouping.tag:
        final stats = reportTagStats(
          entries,
          controller.tags,
          _type,
        ).take(_maxRows).toList(growable: false);
        if (stats.isEmpty) {
          return _emptyState(context);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final stat in stats)
              // 标签没有对应的交易列表筛选入口，行不可点。
              _RankRow(
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
        );
    }
  }

  Widget _emptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dimLabel = _type.label(l10n);
    return EmptyState(
      icon: _grouping == _RankGrouping.tag
          ? Icons.label_outline
          : Icons.donut_small_outlined,
      title: l10n.noDimData(dimLabel),
      description: l10n.noDimDesc(dimLabel),
    );
  }

  void _openCategoryEntries(String categoryId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsPage(initialCategoryId: categoryId),
      ),
    );
  }

  /// 顶级分类下钻：底部弹层按子分类拆分，行与底部按钮都跳到该分类的交易列表。
  ///
  /// 下钻取数用聚合原始 key（`stat.categoryId`）而不是 `stat.category.id`：后者在
  /// 「已删除分类」占位时 id 不等于 key，会把下钻 scope 到错误的分类树。
  Future<void> _showSubCategoryDrill(
    BuildContext context,
    List<LedgerEntry> entries,
    ReportCategoryStat stat,
  ) {
    final l10n = AppLocalizations.of(context);
    final color = _type == EntryType.expense
        ? veriSemantic(context, veriExpense)
        : veriSemantic(context, veriIncome);
    final children = reportCategoryChildStats(
      entries,
      VeriFinScope.of(context).categories,
      stat.categoryId,
      _type,
    );
    return showVeriModalSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                          l10n.subCategoryOf(stat.category.label),
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
                          _RankRow(
                            leading: CategoryIconBox(
                              iconCode: child.category.iconCode,
                              color: color,
                              size: 30,
                            ),
                            label: child.category.label,
                            amount: child.amount,
                            percent: child.percent,
                            count: child.count,
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
                      label: Text(l10n.viewCategoryEntries),
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

/// 排行行：图标 + 名称 + 金额 + 占比进度条 + 占比/笔数。可选点按下钻。
class _RankRow extends StatelessWidget {
  const _RankRow({
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

/// 年统计的月度收支卡：本年 12 个月的收入 / 支出双柱对比。
class _YearTrendPanel extends StatelessWidget {
  const _YearTrendPanel({required this.year, this.trailing});

  final int year;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final income = monthlyNetValuesForType(
      controller.entries,
      year,
      EntryType.income,
    );
    final expense = monthlyNetValuesForType(
      controller.entries,
      year,
      EntryType.expense,
    );
    final maxValue = <double>[
      ...income,
      ...expense,
    ].fold<double>(0, (max, value) => value > max ? value : max);
    final incomeColor = veriSemantic(context, veriIncome);
    final expenseColor = veriSemantic(context, veriExpense);

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: l10n.panelYearTrendLabel, trailing: trailing),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _RankLegendDot(color: incomeColor, label: l10n.entryTypeIncome),
              const SizedBox(width: 12),
              _RankLegendDot(color: expenseColor, label: l10n.entryTypeExpense),
            ],
          ),
          const SizedBox(height: 12),
          if (maxValue <= 0)
            EmptyState(
              icon: Icons.bar_chart_outlined,
              title: l10n.noDimData(l10n.entryTypeExpense),
              description: l10n.noDimDesc(l10n.entryTypeExpense),
            )
          else
            SizedBox(
              height: 146,
              child: InteractiveBarChart(
                series: <VeriBarSeries>[
                  VeriBarSeries(values: income, color: incomeColor),
                  VeriBarSeries(values: expense, color: expenseColor),
                ],
                xLabels: const <String>[
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  '10',
                  '11',
                  '12',
                ],
                yLabels: reportAxisLabels(maxValue),
                labelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.50),
                tooltipOf: (index) => ChartTooltip(
                  title: l10n.monthNumber(index + 1),
                  lines: <ChartTooltipLine>[
                    ChartTooltipLine(
                      text: l10n.incomeAmountLabel(
                        formatIncomeAmount(income[index]),
                      ),
                      color: incomeColor,
                    ),
                    ChartTooltipLine(
                      text: l10n.expenseAmountLabel(
                        formatExpenseAmount(expense[index]),
                      ),
                      color: expenseColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 年统计的收支热力卡：12 个月各一张迷你日历，每天一个小方块，
/// 颜色深浅按当天金额占全年峰值的比例决定（无色表示当天没有记录）。
///
/// 这是「日历网格」而不是图表库图表：与 `CalendarPreview` 同一类做法，
/// 由普通 Widget 拼装，不引入自绘数据图表。
class _YearHeatmapPanel extends StatefulWidget {
  const _YearHeatmapPanel({required this.year});

  final int year;

  @override
  State<_YearHeatmapPanel> createState() => _YearHeatmapPanelState();
}

class _YearHeatmapPanelState extends State<_YearHeatmapPanel> {
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final window = DateWindow(
      start: DateTime(widget.year, 1, 1),
      end: DateTime(widget.year, 12, 31),
    );
    final values = valuesForTypeInWindow(controller.entries, window, _type);
    final peak = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final color = _type == EntryType.expense
        ? veriSemantic(context, veriExpense)
        : veriSemantic(context, veriIncome);
    final emptyColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: l10n.panelYearHeatmapLabel,
            trailingWidget: VeriEntryTypeToggle(
              compact: true,
              dimension: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
          ),
          const SizedBox(height: 12),
          // 一年都没有记录时不必铺一屏灰格子。
          if (peak <= 0)
            EmptyState(
              icon: Icons.grid_on_outlined,
              title: l10n.noDimData(_type.label(l10n)),
              description: l10n.noDimDesc(_type.label(l10n)),
            )
          else
            VeriCalendarHeatmap(
              year: widget.year,
              dailyValues: values,
              color: color,
              emptyColor: emptyColor,
              monthLabelOf: l10n.monthNumber,
            ),
        ],
      ),
    );
  }
}

/// 图表图例：色点 + 标签。
class _RankLegendDot extends StatelessWidget {
  const _RankLegendDot({required this.color, required this.label});

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
