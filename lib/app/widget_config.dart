/// Metric vocabulary shared by the Flutter projection and the native Glance
/// renderer. Per-instance configuration lives in home_widget storage keyed by
/// Android's appWidgetId; it is deliberately not part of the app's KV backup.
enum WidgetTemplate { quickEntry, budget, trend, netWorth }

enum WidgetMetric {
  todayExpense,
  periodExpense,
  periodIncome,
  budgetRemaining,
  budgetUsed,
  budgetRate,
  netWorth,
  totalAssets,
  totalLiabilities,
  balance,
  transactionCount,
  savingsRate,
}

enum WidgetChartMetric { expense, income, net, budgetUsage, netWorth }

enum WidgetDateRange { sevenDays, thirtyDays, ninetyDays, budgetCycle, year }
