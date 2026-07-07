import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'ledger_math.dart';
import 'models.dart';

/// 首页走势卡片可展示的统计指标。每个指标自带周期口径（本月/今日/本周/本年/总）与
/// 展示风格（[homeMetricStyle]），计算见 [computeHomeMetric]。
enum HomeMetric {
  monthExpense,
  monthIncome,
  monthNet,
  dailyAvgExpense,
  dailyAvgIncome,
  todayExpense,
  todayIncome,
  todayNet,
  weekExpense,
  weekIncome,
  weekNet,
  yearExpense,
  yearIncome,
  totalExpense,
  totalIncome,
  totalNet,
  totalAssets,
  totalLiabilities,
  netAssets,
  reimbursablePending,
  reimbursed,
}

/// 指标的展示风格：决定取色与是否带正负号。
enum HomeMetricStyle {
  /// 支出类：红色、显示为负数（`-x`）。
  expense,

  /// 收入类：青绿、显示为正额（`x`）。
  income,

  /// 结余/净值类：按正负取色并带 `+/-` 号。
  signed,

  /// 中性数值（资产、待报销等）：蓝色、无符号。
  neutral,
}

/// 走势曲线可绘制的序列（唯一有逐日序列的三种）。
enum HomeTrendSeries { expense, income, net }

HomeMetricStyle homeMetricStyle(HomeMetric metric) {
  switch (metric) {
    case HomeMetric.monthExpense:
    case HomeMetric.dailyAvgExpense:
    case HomeMetric.todayExpense:
    case HomeMetric.weekExpense:
    case HomeMetric.yearExpense:
    case HomeMetric.totalExpense:
    case HomeMetric.totalLiabilities:
      return HomeMetricStyle.expense;
    case HomeMetric.monthIncome:
    case HomeMetric.dailyAvgIncome:
    case HomeMetric.todayIncome:
    case HomeMetric.weekIncome:
    case HomeMetric.yearIncome:
    case HomeMetric.totalIncome:
    case HomeMetric.reimbursed:
      return HomeMetricStyle.income;
    case HomeMetric.monthNet:
    case HomeMetric.todayNet:
    case HomeMetric.weekNet:
    case HomeMetric.totalNet:
    case HomeMetric.netAssets:
      return HomeMetricStyle.signed;
    case HomeMetric.totalAssets:
    case HomeMetric.reimbursablePending:
      return HomeMetricStyle.neutral;
  }
}

/// 指标的本地化名称。
String homeMetricLabel(AppLocalizations l10n, HomeMetric metric) {
  switch (metric) {
    case HomeMetric.monthExpense:
      return l10n.metricMonthExpense;
    case HomeMetric.monthIncome:
      return l10n.metricMonthIncome;
    case HomeMetric.monthNet:
      return l10n.metricMonthNet;
    case HomeMetric.dailyAvgExpense:
      return l10n.metricDailyAvgExpense;
    case HomeMetric.dailyAvgIncome:
      return l10n.metricDailyAvgIncome;
    case HomeMetric.todayExpense:
      return l10n.metricTodayExpense;
    case HomeMetric.todayIncome:
      return l10n.metricTodayIncome;
    case HomeMetric.todayNet:
      return l10n.metricTodayNet;
    case HomeMetric.weekExpense:
      return l10n.metricWeekExpense;
    case HomeMetric.weekIncome:
      return l10n.metricWeekIncome;
    case HomeMetric.weekNet:
      return l10n.metricWeekNet;
    case HomeMetric.yearExpense:
      return l10n.metricYearExpense;
    case HomeMetric.yearIncome:
      return l10n.metricYearIncome;
    case HomeMetric.totalExpense:
      return l10n.metricTotalExpense;
    case HomeMetric.totalIncome:
      return l10n.metricTotalIncome;
    case HomeMetric.totalNet:
      return l10n.metricTotalNet;
    case HomeMetric.totalAssets:
      return l10n.metricTotalAssets;
    case HomeMetric.totalLiabilities:
      return l10n.metricTotalLiabilities;
    case HomeMetric.netAssets:
      return l10n.metricNetAssets;
    case HomeMetric.reimbursablePending:
      return l10n.metricReimbursablePending;
    case HomeMetric.reimbursed:
      return l10n.metricReimbursed;
  }
}

/// 指标选择列表里的一组（按周期/类别归类，带小标题）。
class HomeMetricGroup {
  const HomeMetricGroup({required this.label, required this.metrics});

  final String label;
  final List<HomeMetric> metrics;
}

/// 指标按类别分组，供选择列表加小标题展示。
List<HomeMetricGroup> homeMetricGroups(AppLocalizations l10n) {
  return <HomeMetricGroup>[
    HomeMetricGroup(
      label: l10n.metricGroupMonth,
      metrics: const <HomeMetric>[
        HomeMetric.monthExpense,
        HomeMetric.monthIncome,
        HomeMetric.monthNet,
        HomeMetric.dailyAvgExpense,
        HomeMetric.dailyAvgIncome,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupToday,
      metrics: const <HomeMetric>[
        HomeMetric.todayExpense,
        HomeMetric.todayIncome,
        HomeMetric.todayNet,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupWeek,
      metrics: const <HomeMetric>[
        HomeMetric.weekExpense,
        HomeMetric.weekIncome,
        HomeMetric.weekNet,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupYear,
      metrics: const <HomeMetric>[
        HomeMetric.yearExpense,
        HomeMetric.yearIncome,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupTotal,
      metrics: const <HomeMetric>[
        HomeMetric.totalExpense,
        HomeMetric.totalIncome,
        HomeMetric.totalNet,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupAssets,
      metrics: const <HomeMetric>[
        HomeMetric.totalAssets,
        HomeMetric.totalLiabilities,
        HomeMetric.netAssets,
      ],
    ),
    HomeMetricGroup(
      label: l10n.metricGroupReimburse,
      metrics: const <HomeMetric>[
        HomeMetric.reimbursablePending,
        HomeMetric.reimbursed,
      ],
    ),
  ];
}

/// 曲线序列的本地化名称。
String homeTrendSeriesLabel(AppLocalizations l10n, HomeTrendSeries series) {
  switch (series) {
    case HomeTrendSeries.expense:
      return l10n.entryTypeExpense;
    case HomeTrendSeries.income:
      return l10n.entryTypeIncome;
    case HomeTrendSeries.net:
      return l10n.metricSeriesNet;
  }
}

/// 指标计算所需的数据快照（当前账本口径）。纯数据，便于纯函数计算与单测。
class HomeMetricContext {
  const HomeMetricContext({
    required this.entries,
    required this.accounts,
    required this.balanceOf,
    required this.now,
  });

  final List<LedgerEntry> entries;
  final List<Account> accounts;

  /// 账户当前余额（由 controller.accountBalance 注入，兼容未落库账户）。
  final double Function(Account) balanceOf;
  final DateTime now;
}

bool _inMonth(LedgerEntry entry, DateTime now) =>
    entry.occurredAt.year == now.year && entry.occurredAt.month == now.month;

bool _inYear(LedgerEntry entry, DateTime now) =>
    entry.occurredAt.year == now.year;

bool _inToday(LedgerEntry entry, DateTime now) =>
    DateUtils.isSameDay(entry.occurredAt, now);

bool _inWeek(LedgerEntry entry, DateTime now) {
  // 本周为周一至周日（含今天所在周）。weekday: 周一=1 … 周日=7。
  final start = dateOnly(now).subtract(Duration(days: now.weekday - 1));
  final endExclusive = start.add(const Duration(days: 7));
  final date = entry.occurredAt;
  return !date.isBefore(start) && date.isBefore(endExclusive);
}

double _sum(
  HomeMetricContext ctx,
  EntryType type,
  bool Function(LedgerEntry) inPeriod,
) {
  return sumByType(ctx.entries.where(inPeriod), type);
}

double _net(HomeMetricContext ctx, bool Function(LedgerEntry) inPeriod) {
  return _sum(ctx, EntryType.income, inPeriod) -
      _sum(ctx, EntryType.expense, inPeriod);
}

Iterable<double> _assetBalances(HomeMetricContext ctx) {
  return ctx.accounts
      .where((account) => account.includeInAssets && !account.hidden)
      .map(ctx.balanceOf);
}

/// 计算指定指标当前的数值（当前账本口径）。纯函数。
double computeHomeMetric(HomeMetric metric, HomeMetricContext ctx) {
  final now = ctx.now;
  switch (metric) {
    case HomeMetric.monthExpense:
      return _sum(ctx, EntryType.expense, (e) => _inMonth(e, now));
    case HomeMetric.monthIncome:
      return _sum(ctx, EntryType.income, (e) => _inMonth(e, now));
    case HomeMetric.monthNet:
      return _net(ctx, (e) => _inMonth(e, now));
    case HomeMetric.dailyAvgExpense:
      // 本月已过天数（含今天）为分母，反映当前的日均节奏。
      return _sum(ctx, EntryType.expense, (e) => _inMonth(e, now)) / now.day;
    case HomeMetric.dailyAvgIncome:
      return _sum(ctx, EntryType.income, (e) => _inMonth(e, now)) / now.day;
    case HomeMetric.todayExpense:
      return _sum(ctx, EntryType.expense, (e) => _inToday(e, now));
    case HomeMetric.todayIncome:
      return _sum(ctx, EntryType.income, (e) => _inToday(e, now));
    case HomeMetric.todayNet:
      return _net(ctx, (e) => _inToday(e, now));
    case HomeMetric.weekExpense:
      return _sum(ctx, EntryType.expense, (e) => _inWeek(e, now));
    case HomeMetric.weekIncome:
      return _sum(ctx, EntryType.income, (e) => _inWeek(e, now));
    case HomeMetric.weekNet:
      return _net(ctx, (e) => _inWeek(e, now));
    case HomeMetric.yearExpense:
      return _sum(ctx, EntryType.expense, (e) => _inYear(e, now));
    case HomeMetric.yearIncome:
      return _sum(ctx, EntryType.income, (e) => _inYear(e, now));
    case HomeMetric.totalExpense:
      return _sum(ctx, EntryType.expense, (_) => true);
    case HomeMetric.totalIncome:
      return _sum(ctx, EntryType.income, (_) => true);
    case HomeMetric.totalNet:
      return _net(ctx, (_) => true);
    case HomeMetric.totalAssets:
      return _assetBalances(
        ctx,
      ).where((b) => b > 0).fold<double>(0, (sum, b) => sum + b);
    case HomeMetric.totalLiabilities:
      // 负债以正数（绝对值）展示。
      return _assetBalances(
        ctx,
      ).where((b) => b < 0).fold<double>(0, (sum, b) => sum + b).abs();
    case HomeMetric.netAssets:
      return _assetBalances(ctx).fold<double>(0, (sum, b) => sum + b);
    case HomeMetric.reimbursablePending:
      // 待报销：标记为待报销的支出中尚未被冲抵的部分之和。
      return ctx.entries
          .where((e) => e.type == EntryType.expense && e.reimbursable)
          .fold<double>(
            0,
            (sum, e) => sum + (e.amount - e.refundedAmount).clamp(0, e.amount),
          );
    case HomeMetric.reimbursed:
      // 已报销：待报销支出里已经回款/冲抵的金额之和。
      return ctx.entries
          .where((e) => e.type == EntryType.expense && e.reimbursable)
          .fold<double>(0, (sum, e) => sum + e.refundedAmount);
  }
}

/// 指标按风格格式化为展示字符串（读全局金额小数位偏好）。
String formatHomeMetric(HomeMetric metric, double value) {
  switch (homeMetricStyle(metric)) {
    case HomeMetricStyle.expense:
      return formatExpenseAmount(value);
    case HomeMetricStyle.income:
      return formatIncomeAmount(value);
    case HomeMetricStyle.signed:
      return formatSignedAmount(value);
    case HomeMetricStyle.neutral:
      return formatAmount(value);
  }
}

/// 指标取色：零值用传入的弱化色，否则按风格（结余按正负）取色。
Color homeMetricColor(HomeMetric metric, double value, Color mutedColor) {
  if (isZeroAmount(value)) {
    return mutedColor;
  }
  switch (homeMetricStyle(metric)) {
    case HomeMetricStyle.expense:
      return veriExpense;
    case HomeMetricStyle.income:
      return veriIncome;
    case HomeMetricStyle.signed:
      return value > 0 ? veriIncome : veriExpense;
    case HomeMetricStyle.neutral:
      return veriBlue;
  }
}

/// 首页走势卡片的自定义配置：5 个标量槽 + 曲线序列 + 标题（空则回落默认「概览」）。
class HomeTrendConfig {
  const HomeTrendConfig({
    required this.title,
    required this.big,
    required this.pill,
    required this.card1,
    required this.card2,
    required this.card3,
    required this.series,
  });

  final String title;
  final HomeMetric big;
  final HomeMetric pill;
  final HomeMetric card1;
  final HomeMetric card2;
  final HomeMetric card3;
  final HomeTrendSeries series;

  /// 默认配置：贴近改版前的卡片（本月支出为大数字、本月结余胶囊、收入/日均/今日支出
  /// 三卡、支出曲线），标题留空（展示为「概览」）。
  static const HomeTrendConfig defaults = HomeTrendConfig(
    title: '',
    big: HomeMetric.monthExpense,
    pill: HomeMetric.monthNet,
    card1: HomeMetric.monthIncome,
    card2: HomeMetric.dailyAvgExpense,
    card3: HomeMetric.todayExpense,
    series: HomeTrendSeries.expense,
  );

  HomeTrendConfig copyWith({
    String? title,
    HomeMetric? big,
    HomeMetric? pill,
    HomeMetric? card1,
    HomeMetric? card2,
    HomeMetric? card3,
    HomeTrendSeries? series,
  }) {
    return HomeTrendConfig(
      title: title ?? this.title,
      big: big ?? this.big,
      pill: pill ?? this.pill,
      card1: card1 ?? this.card1,
      card2: card2 ?? this.card2,
      card3: card3 ?? this.card3,
      series: series ?? this.series,
    );
  }

  /// 按槽位序号（0=大数字,1=结余位,2..4=三卡）取指标，便于设置页统一处理。
  HomeMetric slotMetric(int slot) {
    switch (slot) {
      case 0:
        return big;
      case 1:
        return pill;
      case 2:
        return card1;
      case 3:
        return card2;
      default:
        return card3;
    }
  }

  HomeTrendConfig withSlot(int slot, HomeMetric metric) {
    switch (slot) {
      case 0:
        return copyWith(big: metric);
      case 1:
        return copyWith(pill: metric);
      case 2:
        return copyWith(card1: metric);
      case 3:
        return copyWith(card2: metric);
      default:
        return copyWith(card3: metric);
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'big': big.name,
    'pill': pill.name,
    'card1': card1.name,
    'card2': card2.name,
    'card3': card3.name,
    'series': series.name,
  };

  static HomeMetric _metric(Object? value, HomeMetric fallback) {
    return HomeMetric.values.firstWhere(
      (m) => m.name == value,
      orElse: () => fallback,
    );
  }

  static HomeTrendSeries _series(Object? value, HomeTrendSeries fallback) {
    return HomeTrendSeries.values.firstWhere(
      (s) => s.name == value,
      orElse: () => fallback,
    );
  }

  factory HomeTrendConfig.fromJson(Map<String, dynamic> json) {
    return HomeTrendConfig(
      title: (json['title'] as String?)?.trim() ?? '',
      big: _metric(json['big'], defaults.big),
      pill: _metric(json['pill'], defaults.pill),
      card1: _metric(json['card1'], defaults.card1),
      card2: _metric(json['card2'], defaults.card2),
      card3: _metric(json['card3'], defaults.card3),
      series: _series(json['series'], defaults.series),
    );
  }

  /// 从 KV 存储的 JSON 字符串解析；空/损坏回落默认。
  static HomeTrendConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return HomeTrendConfig.fromJson(decoded);
      }
    } catch (_) {
      // 忽略损坏数据，回落默认。
    }
    return defaults;
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    return other is HomeTrendConfig &&
        other.title == title &&
        other.big == big &&
        other.pill == pill &&
        other.card1 == card1 &&
        other.card2 == card2 &&
        other.card3 == card3 &&
        other.series == series;
  }

  @override
  int get hashCode =>
      Object.hash(title, big, pill, card1, card2, card3, series);
}
