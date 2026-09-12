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

/// 桌面尺寸（Android 启动器以 cell 为单位）。
enum WidgetSize {
  oneByTwo,
  twoByTwo,
  twoByFour,
  oneByOne,
  fourByOne,
  fourByTwo,
}

/// Size labels are rows × columns: 1×2 is horizontal, 2×2 is square,
/// and 2×4 is the wide card. Legacy draft sizes normalize without data loss.
WidgetSize supportedWidgetSize(WidgetSize size) => switch (size) {
  WidgetSize.oneByOne || WidgetSize.fourByOne => WidgetSize.oneByTwo,
  WidgetSize.fourByTwo => WidgetSize.twoByFour,
  _ => size,
};

const supportedWidgetSizes = [
  WidgetSize.oneByTwo,
  WidgetSize.twoByTwo,
  WidgetSize.twoByFour,
];

double widgetSizeAspect(WidgetSize size) => switch (supportedWidgetSize(size)) {
  WidgetSize.twoByTwo => 1,
  _ => 2,
};

enum WidgetBackgroundKind { theme, solid, asset }

class WidgetBackground {
  const WidgetBackground({
    this.kind = WidgetBackgroundKind.theme,
    this.value,
    this.overlayOpacity = 0.0,
  });

  final WidgetBackgroundKind kind;

  /// theme 为主题 id，solid 为色值（#AARRGGBB），asset 为本地 asset id。
  final String? value;
  final double overlayOpacity;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': _enumName(kind),
    if (value != null) 'value': value,
    'overlayOpacity': overlayOpacity,
  };

  static WidgetBackground fromJson(Map<String, Object?> json) {
    final opacity = (json['overlayOpacity'] as num?)?.toDouble() ?? 0.0;
    return WidgetBackground(
      kind: _enumFromName(
        WidgetBackgroundKind.values,
        json['kind'] as String?,
        WidgetBackgroundKind.theme,
      ),
      value: json['value'] as String?,
      overlayOpacity: opacity.clamp(0.0, 1.0),
    );
  }
}

/// 用户保存的组件设计。它不包含 Android 的 appWidgetId，因此可跨设备备份。
class UserWidgetDefinition {
  const UserWidgetDefinition({
    required this.id,
    required this.name,
    required this.template,
    this.size = WidgetSize.twoByTwo,
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
    this.background = const WidgetBackground(),
  });

  final String id;
  final String name;
  final WidgetTemplate template;
  final WidgetSize size;
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
  final WidgetBackground background;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'template': _enumName(template),
    'size': _enumName(supportedWidgetSize(size)),
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
    'background': background.toJson(),
  };

  static UserWidgetDefinition fromJson(Map<String, Object?> json) {
    final secondary = (json['secondaryMetrics'] as List<Object?>? ?? const [])
        .whereType<String>()
        .map(
          (name) => _enumFromName(
            WidgetMetric.values,
            name,
            WidgetMetric.periodExpense,
          ),
        )
        .toList(growable: false);
    final rawBackground = json['background'];
    return UserWidgetDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '我的小组件',
      template: _enumFromName(
        WidgetTemplate.values,
        json['template'] as String?,
        WidgetTemplate.quickEntry,
      ),
      size: supportedWidgetSize(
        _enumFromName(
          WidgetSize.values,
          json['size'] as String?,
          WidgetSize.twoByTwo,
        ),
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
      background: rawBackground is Map
          ? WidgetBackground.fromJson(Map<String, Object?>.from(rawBackground))
          : const WidgetBackground(),
    );
  }

  factory UserWidgetDefinition.fromInstance(
    WidgetInstanceConfig config, {
    String? id,
    String? name,
  }) {
    return UserWidgetDefinition(
      id: id ?? 'legacy_${config.appWidgetId}',
      name: name ?? config.template.name,
      template: config.template,
      bookId: config.bookId,
      primaryMetric: config.primaryMetric,
      secondaryMetrics: config.secondaryMetrics,
      chartMetric: config.chartMetric,
      dateRange: config.dateRange,
      accountId: config.accountId,
      categoryId: config.categoryId,
      tagId: config.tagId,
      hideAmounts: config.hideAmounts,
      action: config.action,
    );
  }
}

class WidgetPlacement {
  const WidgetPlacement({
    required this.appWidgetId,
    required this.definitionId,
  });
  final int appWidgetId;
  final String definitionId;

  Map<String, Object?> toJson() => <String, Object?>{
    'appWidgetId': appWidgetId,
    'definitionId': definitionId,
  };

  static WidgetPlacement fromJson(Map<String, Object?> json) => WidgetPlacement(
    appWidgetId: (json['appWidgetId'] as num?)?.toInt() ?? 0,
    definitionId: json['definitionId'] as String? ?? '',
  );
}

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
  static const String definitionsKey = 'verifin.widget_definitions.v1';
  static const String placementsKey = 'verifin.widget_placements.v1';

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

  static List<UserWidgetDefinition> loadDefinitions(LocalKeyValueStore store) {
    final raw = store.read(definitionsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) => UserWidgetDefinition.fromJson(
                  Map<String, Object?>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false);
        }
      } on Object {
        // Fall through to migration below.
      }
    }
    final legacy = load(store);
    if (legacy.isEmpty) return const <UserWidgetDefinition>[];
    final migrated = legacy
        .map((item) => UserWidgetDefinition.fromInstance(item))
        .toList(growable: false);
    // 将旧 appWidgetId 配置一次性写入新设计键，后续读取不再依赖旧格式。
    saveDefinitionsSync(store, migrated);
    return migrated;
  }

  static List<WidgetPlacement> loadPlacements(LocalKeyValueStore store) {
    final raw = store.read(placementsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) =>
                    WidgetPlacement.fromJson(Map<String, Object?>.from(item)),
              )
              .where(
                (item) => item.appWidgetId > 0 && item.definitionId.isNotEmpty,
              )
              .toList(growable: false);
        }
      } on Object {
        // Ignore malformed local preference.
      }
    }
    final migrated = load(store)
        .where((item) => item.appWidgetId > 0)
        .map(
          (item) => WidgetPlacement(
            appWidgetId: item.appWidgetId,
            definitionId: 'legacy_${item.appWidgetId}',
          ),
        )
        .toList(growable: false);
    if (migrated.isNotEmpty) savePlacementsSync(store, migrated);
    return migrated;
  }

  static void saveDefinitionsSync(
    LocalKeyValueStore store,
    Iterable<UserWidgetDefinition> definitions,
  ) => store.write(
    definitionsKey,
    jsonEncode(definitions.map((item) => item.toJson()).toList()),
  );

  static Future<void> saveDefinitions(
    LocalKeyValueStore store,
    Iterable<UserWidgetDefinition> definitions,
  ) => store.writeAndFlush(
    definitionsKey,
    jsonEncode(definitions.map((item) => item.toJson()).toList()),
  );

  static void savePlacementsSync(
    LocalKeyValueStore store,
    Iterable<WidgetPlacement> placements,
  ) => store.write(
    placementsKey,
    jsonEncode(placements.map((item) => item.toJson()).toList()),
  );

  static Future<void> savePlacements(
    LocalKeyValueStore store,
    Iterable<WidgetPlacement> placements,
  ) => store.writeAndFlush(
    placementsKey,
    jsonEncode(placements.map((item) => item.toJson()).toList()),
  );
}
