import 'package:flutter/material.dart';

import 'category_tree.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
import 'models.dart';

/// 报表分析的时间范围类型。
enum ReportRangeMode { month, year, custom }

/// 分析范围：按「天」的闭区间 [start, end]（都取 date-only，end 含当天）。
@immutable
class ReportRange {
  ReportRange({
    required this.mode,
    required DateTime start,
    required DateTime end,
  }) : start = dateOnly(start.isAfter(end) ? end : start),
       end = dateOnly(start.isAfter(end) ? start : end);

  final ReportRangeMode mode;
  final DateTime start;
  final DateTime end;

  /// 单月范围（自然月首日到末日）。
  factory ReportRange.month(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(
      month.year,
      month.month,
      DateUtils.getDaysInMonth(month.year, month.month),
    );
    return ReportRange(mode: ReportRangeMode.month, start: start, end: end);
  }

  /// 整年范围（1 月 1 日到 12 月 31 日）。
  factory ReportRange.year(int year) {
    return ReportRange(
      mode: ReportRangeMode.year,
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
  }

  /// 自定义范围。
  factory ReportRange.custom(DateTime start, DateTime end) {
    return ReportRange(mode: ReportRangeMode.custom, start: start, end: end);
  }

  DateWindow get window => DateWindow(start: start, end: end);

  /// 含起止的天数。
  int get dayCount => end.difference(start).inDays + 1;

  /// 展示用文案。
  String get label {
    switch (mode) {
      case ReportRangeMode.month:
        return '${start.year}年${start.month}月';
      case ReportRangeMode.year:
        return '${start.year}年';
      case ReportRangeMode.custom:
        final sameYear = start.year == end.year;
        final startText =
            '${start.year}.${_two(start.month)}.${_two(start.day)}';
        final endText = sameYear
            ? '${_two(end.month)}.${_two(end.day)}'
            : '${end.year}.${_two(end.month)}.${_two(end.day)}';
        return '$startText - $endText';
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// 范围内的收支汇总（转账不计）。
@immutable
class ReportSummary {
  const ReportSummary({
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
  });

  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;

  double get net => income - expense;
  int get entryCount => incomeCount + expenseCount;

  static const empty = ReportSummary(
    income: 0,
    expense: 0,
    incomeCount: 0,
    expenseCount: 0,
  );
}

/// 汇总一批交易的收入 / 支出净额与笔数（按 [LedgerEntry.netAmount]）。
ReportSummary reportSummary(Iterable<LedgerEntry> entries) {
  var income = 0.0;
  var expense = 0.0;
  var incomeCount = 0;
  var expenseCount = 0;
  for (final entry in entries) {
    switch (entry.type) {
      case EntryType.income:
        income += entry.netAmount;
        incomeCount += 1;
      case EntryType.expense:
        expense += entry.netAmount;
        expenseCount += 1;
      case EntryType.transfer:
        break;
    }
  }
  return ReportSummary(
    income: income,
    expense: expense,
    incomeCount: incomeCount,
    expenseCount: expenseCount,
  );
}

/// 某维度（支出 / 收入）的分类统计项，金额归总到顶级祖先分类。
@immutable
class ReportCategoryStat {
  const ReportCategoryStat({
    required this.category,
    required this.amount,
    required this.percent,
    required this.count,
  });

  final Category category;
  final double amount;
  final double percent;
  final int count;
}

/// 按顶级分类聚合指定类型的交易金额（净额），降序返回。[type] 只支持支出 / 收入。
List<ReportCategoryStat> reportCategoryStats(
  Iterable<LedgerEntry> entries,
  List<Category> categories,
  EntryType type,
) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    if (entry.type != type) {
      continue;
    }
    final rootId = rootIdOf(categories, entry.categoryId);
    totals.update(
      rootId,
      (value) => value + entry.netAmount,
      ifAbsent: () => entry.netAmount,
    );
    counts.update(rootId, (value) => value + 1, ifAbsent: () => 1);
  }
  final total = totals.values.fold<double>(0, (sum, value) => sum + value);
  final stats =
      totals.entries
          .map(
            (entry) => ReportCategoryStat(
              category: categoryByIdFrom(categories, entry.key),
              amount: entry.value,
              percent: total <= 0 ? 0 : entry.value / total,
              count: counts[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return stats;
}

/// 趋势颗粒度：短范围按天，长范围（跨多月/整年）按月。
enum ReportTrendGranularity { daily, monthly }

@immutable
class ReportTrendPoint {
  const ReportTrendPoint({
    required this.date,
    required this.value,
    required this.label,
    required this.tooltipTitle,
  });

  final DateTime date;
  final double value;

  /// 坐标轴短标签。
  final String label;

  /// 数据气泡标题。
  final String tooltipTitle;
}

@immutable
class ReportTrend {
  const ReportTrend({required this.granularity, required this.points});

  final ReportTrendGranularity granularity;
  final List<ReportTrendPoint> points;

  List<double> get values =>
      points.map((point) => point.value).toList(growable: false);

  double get maxValue => points.fold<double>(
    0,
    (max, point) => point.value > max ? point.value : max,
  );
}

/// 超过该天数的范围按月聚合，否则按天。
const int _trendDailyDayLimit = 62;

/// 计算范围内指定类型的趋势序列。整年或跨多月按月，短范围按天。
ReportTrend reportTrend(
  Iterable<LedgerEntry> entries,
  ReportRange range,
  EntryType type,
) {
  final useMonthly =
      range.mode == ReportRangeMode.year ||
      range.dayCount > _trendDailyDayLimit;
  return useMonthly
      ? _monthlyTrend(entries, range, type)
      : _dailyTrend(entries, range, type);
}

ReportTrend _dailyTrend(
  Iterable<LedgerEntry> entries,
  ReportRange range,
  EntryType type,
) {
  final days = range.window.days;
  final values = List<double>.filled(days.length, 0);
  final index = <int, int>{};
  for (var i = 0; i < days.length; i += 1) {
    final day = days[i];
    index[_dayKey(day.year, day.month, day.day)] = i;
  }
  for (final entry in entries) {
    if (entry.type != type) {
      continue;
    }
    final date = entry.occurredAt;
    final slot = index[_dayKey(date.year, date.month, date.day)];
    if (slot != null) {
      values[slot] += entry.netAmount;
    }
  }
  final points = <ReportTrendPoint>[
    for (var i = 0; i < days.length; i += 1)
      ReportTrendPoint(
        date: days[i],
        value: values[i],
        label: '${days[i].month}.${days[i].day}',
        tooltipTitle: '${days[i].month}月${days[i].day}日',
      ),
  ];
  return ReportTrend(granularity: ReportTrendGranularity.daily, points: points);
}

ReportTrend _monthlyTrend(
  Iterable<LedgerEntry> entries,
  ReportRange range,
  EntryType type,
) {
  // 生成从 start 月到 end 月（含）的连续月份桶。
  final months = <DateTime>[];
  var cursor = DateTime(range.start.year, range.start.month, 1);
  final last = DateTime(range.end.year, range.end.month, 1);
  var guard = 0;
  while (!cursor.isAfter(last) && guard < 600) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
    guard += 1;
  }
  final values = List<double>.filled(months.length, 0);
  final index = <int, int>{};
  for (var i = 0; i < months.length; i += 1) {
    index[_monthKey(months[i].year, months[i].month)] = i;
  }
  final startDay = range.start;
  final endExclusive = range.end.add(const Duration(days: 1));
  for (final entry in entries) {
    if (entry.type != type) {
      continue;
    }
    final date = entry.occurredAt;
    if (date.isBefore(startDay) || !date.isBefore(endExclusive)) {
      continue;
    }
    final slot = index[_monthKey(date.year, date.month)];
    if (slot != null) {
      values[slot] += entry.netAmount;
    }
  }
  final singleYear = months.every((month) => month.year == range.start.year);
  final points = <ReportTrendPoint>[
    for (var i = 0; i < months.length; i += 1)
      ReportTrendPoint(
        date: months[i],
        value: values[i],
        label: singleYear
            ? '${months[i].month}'
            : '${months[i].year % 100}.${months[i].month}',
        tooltipTitle: '${months[i].year}年${months[i].month}月',
      ),
  ];
  return ReportTrend(
    granularity: ReportTrendGranularity.monthly,
    points: points,
  );
}

int _dayKey(int year, int month, int day) => (year * 100 + month) * 100 + day;

int _monthKey(int year, int month) => year * 100 + month;
