/// 偏好与界面配置模型：主题/语言/资产视图/FAB 行为枚举与页面面板配置。
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum ThemePreference {
  system,
  light,
  dark;

  String label(AppLocalizations l10n) {
    switch (this) {
      case ThemePreference.system:
        return l10n.themeSystem;
      case ThemePreference.light:
        return l10n.themeLight;
      case ThemePreference.dark:
        return l10n.themeDark;
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static ThemePreference fromStorage(String? value) {
    return ThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => ThemePreference.system,
    );
  }
}

/// 主题强调色来源。默认模式保留 Veri Fin 原有蓝色；系统模式在支持的平台
/// 使用 Android 动态颜色；自定义模式使用用户保存的不透明 ARGB 颜色。
enum ThemeColorMode {
  defaultColor,
  system,
  custom;

  static ThemeColorMode fromStorage(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeColorMode.defaultColor,
  );
}

/// 设备级主题色偏好。颜色不随亮/暗主题变化，两个主题分别从同一个 seed 生成。
@immutable
class ThemeColorPreference {
  const ThemeColorPreference({
    required this.mode,
    required this.customColorValue,
  });

  static const ThemeColorPreference defaultValue = ThemeColorPreference(
    mode: ThemeColorMode.defaultColor,
    customColorValue: 0xFF346EDB,
  );

  final ThemeColorMode mode;
  final int customColorValue;

  ThemeColorPreference copyWith({
    ThemeColorMode? mode,
    int? customColorValue,
  }) => ThemeColorPreference(
    mode: mode ?? this.mode,
    customColorValue: customColorValue ?? this.customColorValue,
  );

  String encode() => jsonEncode(<String, Object?>{
    'mode': mode.name,
    'color': customColorValue,
  });

  static ThemeColorPreference fromStorage(String? value) {
    if (value == null || value.isEmpty) return defaultValue;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return defaultValue;
      final rawColor = decoded['color'];
      final color = rawColor is num ? rawColor.toInt() : null;
      if (color == null || color < 0 || color > 0xFFFFFFFF) {
        return defaultValue;
      }
      return ThemeColorPreference(
        mode: ThemeColorMode.fromStorage(decoded['mode'] as String?),
        // Theme seeds are always opaque. Preserve the RGB channels if an old or
        // hand-edited value contains a transparent alpha.
        customColorValue: color | 0xFF000000,
      );
    } on Object {
      return defaultValue;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeColorPreference &&
      other.mode == mode &&
      other.customColorValue == customColorValue;

  @override
  int get hashCode => Object.hash(mode, customColorValue);
}

/// 应用语言偏好：跟随系统或固定某一语言。设备本地偏好（存 KV），
/// 不进 JSON 备份，初始化数据时保留。
enum LocalePreference {
  system,
  zh,
  en;

  /// 固定语言时返回对应 locale；跟随系统返回 null（交给系统解析）。
  Locale? get locale {
    switch (this) {
      case LocalePreference.system:
        return null;
      case LocalePreference.zh:
        return const Locale('zh');
      case LocalePreference.en:
        return const Locale('en');
    }
  }

  /// 语言选项显示名：具体语言恒用其母语名，跟随系统随当前语言。
  String label(AppLocalizations l10n) {
    switch (this) {
      case LocalePreference.system:
        return l10n.localeFollowSystem;
      case LocalePreference.zh:
        return '简体中文';
      case LocalePreference.en:
        return 'English';
    }
  }

  static LocalePreference fromStorage(String? value) {
    return LocalePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => LocalePreference.system,
    );
  }
}

/// 底部导航栏样式偏好：四个根目的地固定，只切换导航栏的呈现方式。
///
/// 枚举名即持久化标识，必须与 `VeriRootNavigationStyle.id` 一一对应
/// （`test/navigation_style_settings_test.dart` 会断言两者不许漂移）。
/// 设备本地偏好：不进 JSON 备份，初始化数据时保留。
enum NavigationStylePreference {
  docked,
  liquidGlass;

  static NavigationStylePreference fromStorage(String? value) {
    return NavigationStylePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => NavigationStylePreference.docked,
    );
  }
}

enum AssetAccountViewMode {
  group,
  type;

  String label(AppLocalizations l10n) {
    switch (this) {
      case AssetAccountViewMode.group:
        return l10n.assetViewGroup;
      case AssetAccountViewMode.type:
        return l10n.assetViewType;
    }
  }

  String toggleLabel(AppLocalizations l10n) {
    switch (this) {
      case AssetAccountViewMode.group:
        return l10n.assetViewToggleToType;
      case AssetAccountViewMode.type:
        return l10n.assetViewToggleToGroup;
    }
  }

  static AssetAccountViewMode fromStorage(String? value) {
    return AssetAccountViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetAccountViewMode.type,
    );
  }
}

/// 首页 FAB（记一笔）点击后的行为：手动记账（默认）、AI 对话记账，或点击手动、
/// 长按 AI。
enum FabActionMode {
  manual,
  ai,
  manualTapAiLongPress;

  String label(AppLocalizations l10n) {
    switch (this) {
      case FabActionMode.manual:
        return l10n.fabModeManual;
      case FabActionMode.ai:
        return l10n.fabModeAi;
      case FabActionMode.manualTapAiLongPress:
        return l10n.fabModeManualTapAiLongPress;
    }
  }

  static FabActionMode fromStorage(String? value) {
    return FabActionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => FabActionMode.manual,
    );
  }
}

/// 金额数字键盘的数字排列。标准布局保留当前的计算器顺序，电话布局使用
/// Android/电话拨号盘常见的从上到下递增顺序。
enum NumberPadLayout {
  standard,
  phone;

  String label(AppLocalizations l10n) {
    switch (this) {
      case NumberPadLayout.standard:
        return l10n.numberPadLayoutStandard;
      case NumberPadLayout.phone:
        return l10n.numberPadLayoutPhone;
    }
  }

  static NumberPadLayout fromStorage(String? value) {
    return NumberPadLayout.values.firstWhere(
      (layout) => layout.name == value,
      orElse: () => NumberPadLayout.standard,
    );
  }
}

/// 支持面板管理的页面。看板按统计口径拆成「日常 / 月统计 / 年统计」三个 Tab，
/// 每个 Tab 各自持有一份面板清单；首页单独一份。
enum PanelPageKind {
  home,
  reportsDaily,
  reportsMonthly,
  reportsYearly;

  String label(AppLocalizations l10n) {
    switch (this) {
      case PanelPageKind.home:
        return l10n.tabHome;
      case PanelPageKind.reportsDaily:
        return l10n.reportTabDaily;
      case PanelPageKind.reportsMonthly:
        return l10n.reportTabMonthly;
      case PanelPageKind.reportsYearly:
        return l10n.reportTabYearly;
    }
  }

  List<PagePanelSpec> get specs {
    switch (this) {
      case PanelPageKind.home:
        return homePanelSpecs;
      case PanelPageKind.reportsDaily:
        return reportDailyPanelSpecs;
      case PanelPageKind.reportsMonthly:
        return reportMonthlyPanelSpecs;
      case PanelPageKind.reportsYearly:
        return reportYearlyPanelSpecs;
    }
  }
}

/// 看板顶部的统计口径 Tab。顺序即展示顺序；每个 Tab 对应一份独立的面板清单
/// （见 [PanelPageKind]），当前 Tab 不做持久化，每次进入都回到默认项。
enum ReportPeriodTab {
  daily,
  monthly,
  yearly;

  String label(AppLocalizations l10n) {
    switch (this) {
      case ReportPeriodTab.daily:
        return l10n.reportTabDaily;
      case ReportPeriodTab.monthly:
        return l10n.reportTabMonthly;
      case ReportPeriodTab.yearly:
        return l10n.reportTabYearly;
    }
  }

  /// 该口径对应的面板清单。
  PanelPageKind get panelPageKind {
    switch (this) {
      case ReportPeriodTab.daily:
        return PanelPageKind.reportsDaily;
      case ReportPeriodTab.monthly:
        return PanelPageKind.reportsMonthly;
      case ReportPeriodTab.yearly:
        return PanelPageKind.reportsYearly;
    }
  }
}

/// 面板目录项:id 是持久化标识,名称与描述按 id 从 ARB 解析,用于面板管理页展示。
class PagePanelSpec {
  const PagePanelSpec({required this.id});

  final String id;

  String label(AppLocalizations l10n) {
    switch (id) {
      case 'trend':
        return l10n.panelTrendLabel;
      case 'recent':
        return l10n.panelRecentLabel;
      case 'budget':
        return l10n.panelBudgetLabel;
      case 'calendar':
        return l10n.calendarTitle;
      case 'budget_execution':
        return l10n.panelBudgetExecutionLabel;
      case 'category_stats':
        return l10n.panelCategoryStatsLabel;
      case 'summary':
        return l10n.panelSummaryLabel;
      case 'daily_trend':
        return l10n.panelDailyTrendLabel;
      case 'recent_daily':
        return l10n.panelRecentDailyLabel;
      case 'asset_summary':
        return l10n.panelAssetSummaryLabel;
      case 'ranking':
        return l10n.panelRankingLabel;
      case 'year_summary':
        return l10n.panelYearSummaryLabel;
      case 'year_trend':
        return l10n.panelYearTrendLabel;
      case 'year_heatmap':
        return l10n.panelYearHeatmapLabel;
    }
    return id;
  }

  String description(AppLocalizations l10n) {
    switch (id) {
      case 'trend':
        return l10n.panelTrendDesc;
      case 'recent':
        return l10n.panelRecentDesc;
      case 'budget':
        return l10n.panelBudgetDesc;
      case 'calendar':
        return l10n.panelCalendarDesc;
      case 'budget_execution':
        return l10n.panelBudgetExecutionDesc;
      case 'category_stats':
        return l10n.panelCategoryStatsDesc;
      case 'summary':
        return l10n.panelSummaryDesc;
      case 'daily_trend':
        return l10n.panelDailyTrendDesc;
      case 'recent_daily':
        return l10n.panelRecentDailyDesc;
      case 'asset_summary':
        return l10n.panelAssetSummaryDesc;
      case 'ranking':
        return l10n.panelRankingDesc;
      case 'year_summary':
        return l10n.panelYearSummaryDesc;
      case 'year_trend':
        return l10n.panelYearTrendDesc;
      case 'year_heatmap':
        return l10n.panelYearHeatmapDesc;
    }
    return '';
  }
}

const List<PagePanelSpec> homePanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'trend'),
  PagePanelSpec(id: 'recent'),
  PagePanelSpec(id: 'budget'),
  PagePanelSpec(id: 'calendar'),
];

/// 看板「月统计」Tab 的面板目录。顺序即默认渲染顺序，也是新增面板的插入位置依据
/// （见 `_normalizePanelSettings`）。
const List<PagePanelSpec> reportMonthlyPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'summary'),
  PagePanelSpec(id: 'budget_execution'),
  PagePanelSpec(id: 'category_stats'),
  PagePanelSpec(id: 'ranking'),
  PagePanelSpec(id: 'daily_trend'),
];

/// 看板「日常」Tab 的面板目录：近 7 日统计 + 资产汇总。
const List<PagePanelSpec> reportDailyPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'recent_daily'),
  PagePanelSpec(id: 'asset_summary'),
];

/// 看板「年统计」Tab：本年收支摘要、本年 12 个月收支双柱、全年收支热力、排行。
/// 排行复用月统计的 `ranking` 面板，只是取数窗口换成整年。
const List<PagePanelSpec> reportYearlyPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'year_summary'),
  PagePanelSpec(id: 'year_trend'),
  PagePanelSpec(id: 'year_heatmap'),
  PagePanelSpec(id: 'ranking'),
];

/// 页面面板的开关状态,列表顺序即页面渲染顺序。
class PagePanelSetting {
  const PagePanelSetting({required this.id, required this.enabled});

  final String id;
  final bool enabled;

  PagePanelSetting copyWith({bool? enabled}) {
    return PagePanelSetting(id: id, enabled: enabled ?? this.enabled);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'enabled': enabled};
  }

  static PagePanelSetting fromJson(Map<String, Object?> json) {
    return PagePanelSetting(
      id: json['id'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
