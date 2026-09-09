/// 偏好与界面配置模型：主题/语言/资产视图/FAB 行为枚举与页面面板配置。
library;

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

/// 支持面板管理的主页面。
enum PanelPageKind {
  home,
  reports;

  String label(AppLocalizations l10n) {
    switch (this) {
      case PanelPageKind.home:
        return l10n.tabHome;
      case PanelPageKind.reports:
        return l10n.tabReports;
    }
  }

  List<PagePanelSpec> get specs {
    switch (this) {
      case PanelPageKind.home:
        return homePanelSpecs;
      case PanelPageKind.reports:
        return reportPanelSpecs;
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
      case 'category_ring':
        return l10n.panelCategoryRingLabel;
      case 'category_rank':
        return l10n.panelCategoryRankLabel;
      case 'tag_stats':
        return l10n.panelTagStatsLabel;
      case 'daily_trend':
        return l10n.panelDailyTrendLabel;
      case 'monthly_structure':
        // 该面板只有支出序列，标题与看板卡片保持一致，不写成「月度收支」。
        return l10n.monthlyTrendTitle;
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
      case 'category_ring':
        return l10n.panelCategoryRingDesc;
      case 'category_rank':
        return l10n.panelCategoryRankDesc;
      case 'tag_stats':
        return l10n.panelTagStatsDesc;
      case 'daily_trend':
        return l10n.panelDailyTrendDesc;
      case 'monthly_structure':
        return l10n.panelMonthlyStructureDesc;
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

const List<PagePanelSpec> reportPanelSpecs = <PagePanelSpec>[
  PagePanelSpec(id: 'budget_execution'),
  PagePanelSpec(id: 'category_ring'),
  PagePanelSpec(id: 'category_rank'),
  PagePanelSpec(id: 'tag_stats'),
  PagePanelSpec(id: 'daily_trend'),
  PagePanelSpec(id: 'monthly_structure'),
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
