import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_math.dart';
import '../app/feedback.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_scope.dart';
import '../app/widget_config.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});
  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  @override
  Widget build(BuildContext context) {
    final c = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final base = c.activeBook.baseCurrencyCode;
    final today = formatUserMoney(
      dayExpenseTotal(c.entries, dateOnly(now)),
      base,
    );
    final month = c.budgetKeyMonthFor(now);
    final spent = sumByType(
      entriesInWindow(c.entries, c.budgetWindow(month)),
      EntryType.expense,
    );
    final remaining = c.monthlyBudget(month) - spent;
    final valuation = c.accountBalancesInBase(
      accounts: c.accounts.where((a) => a.includeInAssets && !a.hidden),
    );
    final netWorth = valuation.completeTotal == null
        ? '—'
        : formatUserMoney(valuation.completeTotal!, base);
    final specs = <_WidgetSpec>[
      _WidgetSpec(
        'quick_entry',
        l10n.widgetQuickEntryName,
        l10n.widgetQuickEntryDesc,
        l10n.widgetTodayExpense,
        today,
        true,
        WidgetTemplate.quickEntry,
      ),
      _WidgetSpec(
        'budget',
        l10n.widgetBudgetName,
        l10n.widgetBudgetDesc,
        remaining < 0 ? l10n.widgetBudgetOverspent : l10n.widgetBudgetAvailable,
        formatUserMoney(remaining.abs(), base),
        false,
        WidgetTemplate.budget,
      ),
      _WidgetSpec(
        'trend',
        l10n.widgetTrendName,
        l10n.widgetTrendDesc,
        l10n.widgetMetricPeriodExpense,
        formatUserMoney(spent, base),
        false,
        WidgetTemplate.trend,
      ),
      _WidgetSpec(
        'net_worth',
        l10n.widgetNetWorthName,
        l10n.widgetNetWorthDesc,
        l10n.widgetNetWorth,
        netWorth,
        false,
        WidgetTemplate.netWorth,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              VeriHeader(
                title: l10n.widgetGalleryTitle,
                subtitle: l10n.widgetGallerySubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              ...specs.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WidgetCard(
                    spec: s,
                    onConfigure: () => _openConfig(context, s),
                  ),
                ),
              ),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline,
                          size: 18,
                          color: veriRoyal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.widgetHowToAddTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.widgetHowToAddDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .6),
                        height: 1.5,
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

  Future<void> _openConfig(BuildContext context, _WidgetSpec spec) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WidgetConfigPage(template: spec.template),
      ),
    );
  }
}

class _WidgetSpec {
  const _WidgetSpec(
    this.widgetKey,
    this.name,
    this.description,
    this.previewLabel,
    this.previewValue,
    this.showEntryButton,
    this.template,
  );
  final String widgetKey, name, description, previewLabel, previewValue;
  final bool showEntryButton;
  final WidgetTemplate template;
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.spec, required this.onConfigure});
  final _WidgetSpec spec;
  final VoidCallback onConfigure;
  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await AppWidgetBridge.pinWidget(spec.widgetKey);
    if (!context.mounted) return;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: ok ? l10n.widgetPinRequested : l10n.widgetPinUnsupported,
        tone: ok ? VeriFeedbackTone.success : VeriFeedbackTone.warning,
        duration: ok
            ? VeriFeedbackDuration.standard
            : VeriFeedbackDuration.long,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VeriCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WidgetPreview(spec: spec),
        const SizedBox(height: 12),
        Text(
          spec.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          spec.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .6),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onConfigure,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(AppLocalizations.of(context).widgetConfigure),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_to_home_screen, size: 18),
              label: Text(AppLocalizations.of(context).widgetAddToHome),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.spec});
  final _WidgetSpec spec;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(veriRadiusLg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.previewLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spec.previewValue,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (spec.showEntryButton)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: veriRoyal,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
      ],
    ),
  );
}

class WidgetConfigPage extends StatefulWidget {
  const WidgetConfigPage({super.key, required this.template});
  final WidgetTemplate template;
  @override
  State<WidgetConfigPage> createState() => _WidgetConfigPageState();
}

class _WidgetConfigPageState extends State<WidgetConfigPage> {
  late WidgetTemplate _template = widget.template;
  String? _bookId;
  WidgetMetric _metric = WidgetMetric.periodExpense;
  WidgetChartMetric? _chart = WidgetChartMetric.expense;
  WidgetMetric? _secondary;
  WidgetDateRange _range = WidgetDateRange.thirtyDays;
  WidgetAction _action = WidgetAction.app;
  bool _hideAmounts = false;

  String _templateLabel(AppLocalizations l, WidgetTemplate t) => switch (t) {
    WidgetTemplate.quickEntry => l.widgetQuickEntryName,
    WidgetTemplate.budget => l.widgetBudgetName,
    WidgetTemplate.trend => l.widgetTrendName,
    WidgetTemplate.netWorth => l.widgetNetWorthName,
  };

  String _metricLabel(AppLocalizations l, WidgetMetric m) => switch (m) {
    WidgetMetric.todayExpense => l.widgetMetricTodayExpense,
    WidgetMetric.periodExpense => l.widgetMetricPeriodExpense,
    WidgetMetric.periodIncome => l.widgetMetricPeriodIncome,
    WidgetMetric.budgetRemaining => l.widgetMetricBudgetRemaining,
    WidgetMetric.budgetUsed => l.widgetMetricBudgetUsed,
    WidgetMetric.budgetRate => l.widgetMetricBudgetRate,
    WidgetMetric.netWorth => l.widgetMetricNetWorth,
    WidgetMetric.totalAssets => l.widgetMetricTotalAssets,
    WidgetMetric.totalLiabilities => l.widgetMetricTotalLiabilities,
    WidgetMetric.balance => l.widgetMetricBalance,
    WidgetMetric.transactionCount => l.widgetMetricTransactionCount,
    WidgetMetric.savingsRate => l.widgetMetricSavingsRate,
  };

  String _chartLabel(AppLocalizations l, WidgetChartMetric? m) => m == null
      ? l.widgetNoChart
      : switch (m) {
          WidgetChartMetric.expense => l.widgetChartExpense,
          WidgetChartMetric.income => l.widgetChartIncome,
          WidgetChartMetric.net => l.widgetChartNet,
          WidgetChartMetric.budgetUsage => l.widgetChartBudgetUsage,
          WidgetChartMetric.netWorth => l.widgetChartNetWorth,
        };

  String _rangeLabel(AppLocalizations l, WidgetDateRange r) => switch (r) {
    WidgetDateRange.sevenDays => l.widgetRange7d,
    WidgetDateRange.thirtyDays => l.widgetRange30d,
    WidgetDateRange.ninetyDays => l.widgetRange90d,
    WidgetDateRange.budgetCycle => l.widgetRangeCycle,
    WidgetDateRange.year => l.widgetRangeYear,
  };

  String _actionLabel(AppLocalizations l, WidgetAction action) =>
      switch (action) {
        WidgetAction.app => l.widgetActionApp,
        WidgetAction.entry => l.widgetActionEntry,
        WidgetAction.budget => l.widgetActionBudget,
        WidgetAction.trend => l.widgetActionTrend,
        WidgetAction.assets => l.widgetActionAssets,
        WidgetAction.profile => l.widgetActionProfile,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = VeriFinScope.of(context);
    final bookName = _bookId == null
        ? l.widgetCurrentBook
        : c.ledgerBooks
              .firstWhere((b) => b.id == _bookId, orElse: () => c.activeBook)
              .name;
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              VeriHeader(
                title: l.widgetConfigTitle,
                showBack: true,
                actions: [
                  HeaderTextAction(label: l.widgetSaveConfig, onPressed: _save),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: [
                    SelectField(
                      label: l.widgetTemplate,
                      value: _templateLabel(l, _template),
                      icon: Icons.dashboard_outlined,
                      onTap: () async {
                        final v = await showOptionSheet(
                          context: context,
                          title: l.widgetTemplate,
                          values: WidgetTemplate.values,
                          selected: _template,
                          labelOf: (t) => _templateLabel(l, t),
                        );
                        if (v != null) setState(() => _template = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetSecondaryMetric,
                      value: _secondary == null
                          ? l.widgetNoSecondaryMetric
                          : _metricLabel(l, _secondary!),
                      icon: Icons.view_agenda_outlined,
                      onTap: () async {
                        final v = await showOptionSheet<WidgetMetric?>(
                          context: context,
                          title: l.widgetSecondaryMetric,
                          values: <WidgetMetric?>[null, ...WidgetMetric.values],
                          selected: _secondary,
                          labelOf: (m) => m == null
                              ? l.widgetNoSecondaryMetric
                              : _metricLabel(l, m),
                        );
                        setState(() => _secondary = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetBook,
                      value: bookName,
                      icon: Icons.book_outlined,
                      onTap: () async {
                        final v = await showOptionSheet(
                          context: context,
                          title: l.widgetBook,
                          values: <String?>[
                            null,
                            ...c.ledgerBooks.map((b) => b.id),
                          ],
                          selected: _bookId,
                          labelOf: (id) => id == null
                              ? l.widgetCurrentBook
                              : c.ledgerBooks
                                    .firstWhere((b) => b.id == id)
                                    .name,
                        );
                        if (v != null || _bookId != null) {
                          setState(() => _bookId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetPrimaryMetric,
                      value: _metricLabel(l, _metric),
                      icon: Icons.insights_outlined,
                      onTap: () async {
                        final v = await showOptionSheet(
                          context: context,
                          title: l.widgetPrimaryMetric,
                          values: WidgetMetric.values,
                          selected: _metric,
                          labelOf: (m) => _metricLabel(l, m),
                        );
                        if (v != null) setState(() => _metric = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetChart,
                      value: _chartLabel(l, _chart),
                      icon: Icons.show_chart,
                      onTap: () async {
                        final v = await showOptionSheet<WidgetChartMetric?>(
                          context: context,
                          title: l.widgetChart,
                          values: <WidgetChartMetric?>[
                            null,
                            ...WidgetChartMetric.values,
                          ],
                          selected: _chart,
                          labelOf: (m) => _chartLabel(l, m),
                        );
                        setState(() => _chart = v);
                      },
                    ),
                    if (_chart != null) ...[
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetDateRange,
                        value: _rangeLabel(l, _range),
                        icon: Icons.date_range,
                        onTap: () async {
                          final v = await showOptionSheet(
                            context: context,
                            title: l.widgetDateRange,
                            values: WidgetDateRange.values,
                            selected: _range,
                            labelOf: (r) => _rangeLabel(l, r),
                          );
                          if (v != null) setState(() => _range = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetTapAction,
                      value: _actionLabel(l, _action),
                      icon: Icons.touch_app_outlined,
                      onTap: () async {
                        final v = await showOptionSheet(
                          context: context,
                          title: l.widgetTapAction,
                          values: WidgetAction.values,
                          selected: _action,
                          labelOf: (a) => _actionLabel(l, a),
                        );
                        if (v != null) setState(() => _action = v);
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.widgetHideAmounts),
                      value: _hideAmounts,
                      onChanged: (v) => setState(() => _hideAmounts = v),
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

  Future<void> _save() async {
    final c = VeriFinScope.of(context);
    final existing = c.widgetInstanceConfigs;
    final id = DateTime.now().millisecondsSinceEpoch;
    final config = WidgetInstanceConfig(
      appWidgetId: id,
      template: _template,
      bookId: _bookId,
      primaryMetric: _metric,
      chartMetric: _chart,
      secondaryMetrics: _secondary == null ? const [] : [_secondary!],
      dateRange: _range,
      hideAmounts: _hideAmounts,
      action: _action,
    );
    await c.saveWidgetInstanceConfigs([
      ...existing.where((x) => x.appWidgetId != id),
      config,
    ]);
    if (!mounted) return;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: AppLocalizations.of(context).widgetConfigSaved,
        tone: VeriFeedbackTone.success,
      ),
    );
    Navigator.of(context).pop();
  }
}
