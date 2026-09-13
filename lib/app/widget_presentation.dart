import '../l10n/app_localizations.dart';
import 'currency_math.dart';
import 'ledger_math.dart';
import 'models.dart';
import 'widget_config.dart';

/// Immutable input for widget previews. Reading another book never switches the
/// active book or mutates the ledger.
class WidgetLedgerSnapshot {
  const WidgetLedgerSnapshot({
    required this.book,
    required this.entries,
    required this.accounts,
    required this.rates,
    required this.budgetWindow,
    required this.budget,
  });

  final LedgerBook book;
  final List<LedgerEntry> entries;
  final List<Account> accounts;
  final List<ExchangeRate> rates;
  final DateWindow budgetWindow;
  final double budget;
}

class WidgetMetricValue {
  const WidgetMetricValue(this.metric, this.value);
  final WidgetMetric metric;
  final double? value;

  String formatted(String currencyCode, {bool hidden = false}) {
    if (hidden) return '••••';
    final amount = value;
    if (amount == null) return '—';
    if (metric == WidgetMetric.transactionCount) {
      return amount.round().toString();
    }
    if (metric == WidgetMetric.budgetRate ||
        metric == WidgetMetric.savingsRate) {
      return '${(amount * 100).toStringAsFixed(0)}%';
    }
    return formatUserMoney(amount, currencyCode);
  }
}

class WidgetPresentation {
  const WidgetPresentation({
    required this.currencyCode,
    required this.primary,
    required this.secondary,
    required this.series,
    required this.hasChartData,
    required this.budgetUsage,
  });
  final String currencyCode;
  final WidgetMetricValue primary;
  final List<WidgetMetricValue> secondary;
  final List<double?> series;
  final bool hasChartData;
  final double? budgetUsage;
}

WidgetMetric defaultWidgetMetric(WidgetTemplate template) => switch (template) {
  WidgetTemplate.quickEntry => WidgetMetric.todayExpense,
  WidgetTemplate.budget => WidgetMetric.budgetRemaining,
  WidgetTemplate.trend => WidgetMetric.periodExpense,
  WidgetTemplate.netWorth => WidgetMetric.netWorth,
};

WidgetChartMetric? defaultWidgetChart(WidgetTemplate template) =>
    switch (template) {
      WidgetTemplate.quickEntry || WidgetTemplate.budget => null,
      WidgetTemplate.trend => WidgetChartMetric.expense,
      WidgetTemplate.netWorth => WidgetChartMetric.netWorth,
    };

String widgetMetricLabel(AppLocalizations l, WidgetMetric metric) =>
    switch (metric) {
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

WidgetPresentation buildWidgetPresentation({
  required UserWidgetDefinition definition,
  required WidgetLedgerSnapshot snapshot,
  required DateTime now,
}) {
  final today = dateOnly(now);
  final endExclusive = addCalendarDays(today, 1);
  final window = switch (definition.dateRange) {
    WidgetDateRange.sevenDays => DateWindow(
      start: addCalendarDays(today, -6),
      end: today,
    ),
    WidgetDateRange.thirtyDays => DateWindow(
      start: addCalendarDays(today, -29),
      end: today,
    ),
    WidgetDateRange.ninetyDays => DateWindow(
      start: addCalendarDays(today, -89),
      end: today,
    ),
    WidgetDateRange.budgetCycle => snapshot.budgetWindow,
    WidgetDateRange.year => DateWindow(start: DateTime(now.year), end: today),
  };
  final filtered = snapshot.entries
      .where(
        (entry) =>
            (definition.accountId == null ||
                entryTouchesAccount(entry, definition.accountId!)) &&
            (definition.categoryId == null ||
                entry.categoryId == definition.categoryId) &&
            (definition.tagId == null ||
                entry.tagIds.contains(definition.tagId)),
      )
      .toList();
  final period = entriesInWindow(filtered, window);
  final expense = sumByType(period, EntryType.expense);
  final income = sumByType(period, EntryType.income);
  final budgetSpent = sumByType(
    entriesInWindow(filtered, snapshot.budgetWindow),
    EntryType.expense,
  );

  final visibleAccounts = snapshot.accounts
      .where(
        (account) =>
            account.includeInAssets &&
            !account.hidden &&
            (definition.accountId == null ||
                account.id == definition.accountId),
      )
      .toList();
  double balanceAt(Account account, DateTime cutoff) =>
      account.initialBalance +
      snapshot.entries
          .where((entry) => accountEffectDate(entry).isBefore(cutoff))
          .fold<double>(
            0,
            (sum, entry) => sum + accountDeltaForEntry(entry, account.id),
          );
  ConvertedAccountBalances valuationAt(DateTime date) =>
      convertAccountBalancesToBase(
        accounts: visibleAccounts,
        balanceOf: (account) =>
            balanceAt(account, addCalendarDays(dateOnly(date), 1)),
        bookId: snapshot.book.id,
        baseCurrencyCode: snapshot.book.baseCurrencyCode,
        date: date,
        rates: snapshot.rates,
      );
  final valuation = valuationAt(today);
  final hasBudget = snapshot.budget > 0;
  double? metric(WidgetMetric metric) => switch (metric) {
    WidgetMetric.todayExpense => dayExpenseTotal(filtered, today),
    WidgetMetric.periodExpense => expense,
    WidgetMetric.periodIncome => income,
    WidgetMetric.budgetRemaining =>
      hasBudget ? snapshot.budget - budgetSpent : null,
    WidgetMetric.budgetUsed => budgetSpent,
    WidgetMetric.budgetRate => hasBudget ? budgetSpent / snapshot.budget : null,
    WidgetMetric.netWorth => valuation.completeTotal,
    WidgetMetric.totalAssets =>
      valuation.isComplete
          ? valuation.amountsByAccountId.values
                .where((value) => value > 0)
                .fold<double>(0, (a, b) => a + b)
          : null,
    WidgetMetric.totalLiabilities =>
      valuation.isComplete
          ? -valuation.amountsByAccountId.values
                .where((value) => value < 0)
                .fold<double>(0, (a, b) => a + b)
          : null,
    WidgetMetric.balance =>
      definition.accountId == null
          ? valuation.completeTotal
          : snapshot.accounts.where((a) => a.id == definition.accountId).isEmpty
          ? null
          : balanceAt(
              snapshot.accounts.firstWhere((a) => a.id == definition.accountId),
              endExclusive,
            ),
    WidgetMetric.transactionCount =>
      period.where((entry) => entry.type != EntryType.refund).length.toDouble(),
    WidgetMetric.savingsRate => income > 0 ? (income - expense) / income : null,
  };
  final mainMetric =
      definition.primaryMetric ?? defaultWidgetMetric(definition.template);
  final dates = definition.dateRange == WidgetDateRange.year
      ? List.generate(now.month, (index) => DateTime(now.year, index + 2, 0))
      : window.days.where((day) => !day.isAfter(today)).toList();
  var cumulative = 0.0;
  final series = <double?>[];
  for (final date in dates) {
    final bucket = definition.dateRange == WidgetDateRange.year
        ? entriesInWindow(filtered, monthWindowFor(date))
        : entriesInWindow(filtered, DateWindow(start: date, end: date));
    final spent = sumByType(bucket, EntryType.expense);
    final earned = sumByType(bucket, EntryType.income);
    cumulative += spent;
    series.add(switch (definition.chartMetric) {
      WidgetChartMetric.income => earned,
      WidgetChartMetric.net => earned - spent,
      WidgetChartMetric.budgetUsage => cumulative,
      WidgetChartMetric.netWorth => valuationAt(
        date.isAfter(today) ? today : date,
      ).completeTotal,
      WidgetChartMetric.expense || null => spent,
    });
  }
  return WidgetPresentation(
    currencyCode:
        mainMetric == WidgetMetric.balance && definition.accountId != null
        ? snapshot.accounts
                  .where((a) => a.id == definition.accountId)
                  .firstOrNull
                  ?.currencyCode ??
              snapshot.book.baseCurrencyCode
        : snapshot.book.baseCurrencyCode,
    primary: WidgetMetricValue(mainMetric, metric(mainMetric)),
    secondary: definition.secondaryMetrics
        .take(2)
        .map((m) => WidgetMetricValue(m, metric(m)))
        .toList(),
    series: series,
    hasChartData: definition.chartMetric == WidgetChartMetric.netWorth
        ? visibleAccounts.isNotEmpty && series.every((value) => value != null)
        : period.any(
            (entry) =>
                entry.type == EntryType.expense ||
                entry.type == EntryType.income,
          ),
    budgetUsage: hasBudget ? budgetSpent / snapshot.budget : null,
  );
}
