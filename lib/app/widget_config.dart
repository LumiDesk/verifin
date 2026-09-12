import 'dart:convert';

import '../local_storage/local_storage.dart';

/// 小组件模板，决定卡片的默认布局与可用插槽。
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

enum WidgetAction { app, entry, budget, trend, assets, profile }

enum WidgetDateRange { sevenDays, thirtyDays, ninetyDays, budgetCycle, year }

String _enumName(Object value) => (value as Enum).name;

T _enumFromName<T extends Enum>(Iterable<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// 按 Android appWidgetId 保存的独立小组件配置。
class WidgetInstanceConfig {
  const WidgetInstanceConfig({
    required this.appWidgetId,
    required this.template,
    this.bookId,
    this.primaryMetric,
    this.secondaryMetrics = const <WidgetMetric>[],
    this.chartMetric,
    this.dateRange = WidgetDateRange.thirtyDays,
    this.accountId,
    this.categoryId,
    this.tagId,
    this.hideAmounts = false,
    this.action = WidgetAction.app,
  });

  final int appWidgetId;
  final WidgetTemplate template;

  /// null 表示跟随当前账本，否则固定到指定账本。
  final String? bookId;
  final WidgetMetric? primaryMetric;
  final List<WidgetMetric> secondaryMetrics;
  final WidgetChartMetric? chartMetric;
  final WidgetDateRange dateRange;
  final String? accountId;
  final String? categoryId;
  final String? tagId;
  final bool hideAmounts;
  final WidgetAction action;

  WidgetInstanceConfig copyWith({
    int? appWidgetId,
    WidgetTemplate? template,
    Object? bookId = _unset,
    Object? primaryMetric = _unset,
    List<WidgetMetric>? secondaryMetrics,
    Object? chartMetric = _unset,
    WidgetDateRange? dateRange,
    Object? accountId = _unset,
    Object? categoryId = _unset,
    Object? tagId = _unset,
    bool? hideAmounts,
    WidgetAction? action,
  }) {
    return WidgetInstanceConfig(
      appWidgetId: appWidgetId ?? this.appWidgetId,
      template: template ?? this.template,
      bookId: identical(bookId, _unset) ? this.bookId : bookId as String?,
      primaryMetric: identical(primaryMetric, _unset)
          ? this.primaryMetric
          : primaryMetric as WidgetMetric?,
      secondaryMetrics: secondaryMetrics ?? this.secondaryMetrics,
      chartMetric: identical(chartMetric, _unset)
          ? this.chartMetric
          : chartMetric as WidgetChartMetric?,
      dateRange: dateRange ?? this.dateRange,
      accountId: identical(accountId, _unset)
          ? this.accountId
          : accountId as String?,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      tagId: identical(tagId, _unset) ? this.tagId : tagId as String?,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      action: action ?? this.action,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'appWidgetId': appWidgetId,
    'template': _enumName(template),
    if (bookId != null) 'bookId': bookId,
    if (primaryMetric != null) 'primaryMetric': _enumName(primaryMetric!),
    'secondaryMetrics': secondaryMetrics.map(_enumName).toList(),
    if (chartMetric != null) 'chartMetric': _enumName(chartMetric!),
    'dateRange': _enumName(dateRange),
    if (accountId != null) 'accountId': accountId,
    if (categoryId != null) 'categoryId': categoryId,
    if (tagId != null) 'tagId': tagId,
    'hideAmounts': hideAmounts,
    'action': _enumName(action),
  };

  static WidgetInstanceConfig fromJson(Map<String, Object?> json) {
    final secondary = (json['secondaryMetrics'] as List<Object?>? ?? const [])
        .whereType<String>()
        .map(
          (name) => _enumFromName(
            WidgetMetric.values,
            name,
            WidgetMetric.periodExpense,
          ),
        )
        .toList();
    return WidgetInstanceConfig(
      appWidgetId: (json['appWidgetId'] as num?)?.toInt() ?? 0,
      template: _enumFromName(
        WidgetTemplate.values,
        json['template'] as String?,
        WidgetTemplate.quickEntry,
      ),
      bookId: json['bookId'] as String?,
      primaryMetric: json['primaryMetric'] == null
          ? null
          : _enumFromName(
              WidgetMetric.values,
              json['primaryMetric'] as String?,
              WidgetMetric.periodExpense,
            ),
      secondaryMetrics: secondary,
      chartMetric: json['chartMetric'] == null
          ? null
          : _enumFromName(
              WidgetChartMetric.values,
              json['chartMetric'] as String?,
              WidgetChartMetric.expense,
            ),
      dateRange: _enumFromName(
        WidgetDateRange.values,
        json['dateRange'] as String?,
        WidgetDateRange.thirtyDays,
      ),
      accountId: json['accountId'] as String?,
      categoryId: json['categoryId'] as String?,
      tagId: json['tagId'] as String?,
      hideAmounts: json['hideAmounts'] as bool? ?? false,
      action: _enumFromName(
        WidgetAction.values,
        json['action'] as String?,
        WidgetAction.app,
      ),
    );
  }
}

const Object _unset = Object();

/// 小组件配置的本地 KV 适配层。仅保存配置元数据，不保存账目数据。
class WidgetConfigStore {
  static const String storageKey = 'verifin.widget_instances.v1';

  static List<WidgetInstanceConfig> load(LocalKeyValueStore store) {
    final raw = store.read(storageKey);
    if (raw == null || raw.isEmpty) return const <WidgetInstanceConfig>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <WidgetInstanceConfig>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                WidgetInstanceConfig.fromJson(Map<String, Object?>.from(item)),
          )
          .where((item) => item.appWidgetId > 0)
          .toList(growable: false);
    } on Object {
      return const <WidgetInstanceConfig>[];
    }
  }

  static Future<void> save(
    LocalKeyValueStore store,
    Iterable<WidgetInstanceConfig> configs,
  ) async {
    final encoded = jsonEncode(configs.map((item) => item.toJson()).toList());
    await store.writeAndFlush(storageKey, encoded);
  }
}
