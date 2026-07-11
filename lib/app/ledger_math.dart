import 'package:flutter/material.dart';

import 'amount_format.dart';
import 'app_theme.dart';
import 'models.dart';
import '../l10n/app_localizations.dart';

double signedAmount(LedgerEntry entry) {
  switch (entry.type) {
    case EntryType.expense:
      // 退款/报销回款冲抵后的净支出。
      return -entry.netAmount;
    case EntryType.income:
      return entry.amount;
    case EntryType.transfer:
      return 0;
    case EntryType.refund:
      // 退款不计入收支：冲减已体现在原支出的净额（netAmount）里，若再计一次即重复。
      return 0;
  }
}

double accountDeltaForEntry(LedgerEntry entry, String accountId) {
  switch (entry.type) {
    case EntryType.expense:
      // 支出按「全额」扣原账户；退款的回款由独立的退款条目（refund）单独入到账账户，
      // 故此处不再扣净额——否则退款会被重复计（尤其退到不同账户时）。
      return entry.accountId == accountId ? -entry.amount : 0;
    case EntryType.income:
      return entry.accountId == accountId ? entry.amount : 0;
    case EntryType.transfer:
      var delta = 0.0;
      // 用累加而非 if/else return：兼容「转出=转入」的同账户转账（净额应为 −手续费，
      // 而非把入账吞掉）。
      if (entry.accountId == accountId) {
        delta -= entry.amount + entry.fee; // 转出账户额外扣手续费
      }
      if (entry.toAccountId == accountId) {
        delta += entry.amount;
      }
      return delta;
    case EntryType.refund:
      // 只有「已到账」退款影响余额，钱进到账账户（accountId）；待到账不动余额。
      if (entry.settledAt == null) return 0;
      return entry.accountId == accountId ? entry.amount : 0;
  }
}

bool entryTouchesAccount(LedgerEntry entry, String accountId) {
  return entry.accountId == accountId || entry.toAccountId == accountId;
}

Color colorForType(EntryType type) {
  switch (type) {
    case EntryType.expense:
      return veriExpense;
    case EntryType.income:
      return veriIncome;
    case EntryType.transfer:
      return veriRoyal;
    case EntryType.refund:
      // 退款是「钱回来」的正向流入，沿用收入的青绿色。
      return veriIncome;
  }
}

double sumByType(Iterable<LedgerEntry> entries, EntryType type) {
  return entries
      .where((entry) => entry.type == type)
      // 支出按净额（扣除退款/报销回款）统计。
      .fold<double>(0, (sum, entry) => sum + entry.netAmount);
}

bool isZeroAmount(num value) => value.abs() < 0.005;

class DateWindow {
  const DateWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  List<DateTime> get days {
    // 用「按日构造」而非 start.add(Duration(days:))，避免 DST 地区跨夏令时偏移一小时
    // 导致标签/边界落到相邻日；count 下限 0 防 end<start 时 List.generate 抛异常。
    final startDay = dateOnly(start);
    final count = (dateOnly(end).difference(startDay).inDays + 1).clamp(
      0,
      100000,
    );
    return List<DateTime>.generate(
      count,
      (index) => DateTime(startDay.year, startDay.month, startDay.day + index),
    );
  }

  String get label {
    if (start.year == end.year && start.month == end.month) {
      return '${start.month}.${start.day}-${end.month}.${end.day}';
    }
    return '${start.year}.${start.month}.${start.day}-${end.year}.${end.month}.${end.day}';
  }
}

DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// 累积展开的走势窗口：起点恒为当月 1 号，终点按 7 天为步长推进，直到覆盖整月。
/// 即 1–7 号显示 1–7、8 号起显示 1–14、15 号起显示 1–21…… 满月为止（不再往后）。
DateWindow cumulativeWeekWindowFor(DateTime date) {
  final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
  final endDay = ((((date.day - 1) ~/ 7) + 1) * 7).clamp(1, daysInMonth);
  return DateWindow(
    start: DateTime(date.year, date.month, 1),
    end: DateTime(date.year, date.month, endDay),
  );
}

/// 整月窗口（1 号至当月最后一天），用于按月查看的走势详情。
DateWindow monthWindowFor(DateTime date) {
  final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
  return DateWindow(
    start: DateTime(date.year, date.month, 1),
    end: DateTime(date.year, date.month, daysInMonth),
  );
}

/// 自然周窗口（周一至周日，含 [date] 所在周），用于按周查看的走势。
DateWindow weekWindowFor(DateTime date) {
  final day = dateOnly(date);
  // weekday: 周一=1 … 周日=7，回退到本周一。
  final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
  return DateWindow(
    start: monday,
    end: DateTime(monday.year, monday.month, monday.day + 6),
  );
}

/// 自然季窗口（季度首月 1 号至季度末月最后一天），用于按季查看的走势。
DateWindow quarterWindowFor(DateTime date) {
  final startMonth = ((date.month - 1) ~/ 3) * 3 + 1;
  final endMonth = startMonth + 2;
  return DateWindow(
    start: DateTime(date.year, startMonth, 1),
    end: DateTime(
      date.year,
      endMonth,
      DateUtils.getDaysInMonth(date.year, endMonth),
    ),
  );
}

/// [date] 所在季度序号（1–4）。
int quarterOfMonth(int month) => ((month - 1) ~/ 3) + 1;

/// 某年 12 个月、指定类型的净额合计（按月聚合，用于按年查看的走势）。
/// 下标 0–11 对应 1–12 月，无数据的月为 0。
List<double> monthlyNetValuesForType(
  Iterable<LedgerEntry> entries,
  int year,
  EntryType type,
) {
  final values = List<double>.filled(12, 0);
  for (final entry in entries) {
    if (entry.type == type && entry.occurredAt.year == year) {
      values[entry.occurredAt.month - 1] += entry.netAmount;
    }
  }
  return values;
}

List<LedgerEntry> entriesInWindow(
  Iterable<LedgerEntry> entries,
  DateWindow window,
) {
  final start = dateOnly(window.start);
  final endExclusive = dateOnly(window.end).add(const Duration(days: 1));
  return entries.where((entry) {
    final date = entry.occurredAt;
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }).toList();
}

List<double> valuesForTypeInWindow(
  Iterable<LedgerEntry> entries,
  DateWindow window,
  EntryType type,
) {
  final days = window.days;
  final values = List<double>.filled(days.length, 0);
  for (final entry in entries) {
    if (entry.type != type) {
      continue;
    }
    for (var i = 0; i < days.length; i += 1) {
      if (DateUtils.isSameDay(entry.occurredAt, days[i])) {
        values[i] += entry.netAmount;
        break;
      }
    }
  }
  return values;
}

List<String> labelsForWindow(DateWindow window) {
  return window.days.map((date) => '${date.month}.${date.day}').toList();
}

/// 稀疏的日期标签：天数不多（≤8）时全部展示；否则只在 1 号与每 5 天（5/10/15…）
/// 标注，其余留空，避免整月日期挤成一团（滑动时数据气泡仍显示具体某天）。
List<String> sparseLabelsForWindow(DateWindow window) {
  final days = window.days;
  if (days.length <= 8) {
    return labelsForWindow(window);
  }
  return days
      .map(
        (date) => (date.day == 1 || date.day % 5 == 0)
            ? '${date.month}.${date.day}'
            : '',
      )
      .toList();
}

List<double> dailyExpenseValues(Iterable<LedgerEntry> entries, DateTime now) {
  final days = DateUtils.getDaysInMonth(now.year, now.month);
  final values = List<double>.filled(days, 0);
  for (final entry in entries) {
    if (entry.type == EntryType.expense &&
        entry.occurredAt.year == now.year &&
        entry.occurredAt.month == now.month) {
      values[entry.occurredAt.day - 1] += entry.netAmount;
    }
  }
  return values;
}

/// 指定日期当天的支出净额合计（用于桌面小组件「今日支出」）。
double dayExpenseTotal(Iterable<LedgerEntry> entries, DateTime day) {
  return entries
      .where(
        (entry) =>
            entry.type == EntryType.expense &&
            DateUtils.isSameDay(entry.occurredAt, day),
      )
      .fold<double>(0, (sum, entry) => sum + entry.netAmount);
}

List<double> monthlyExpenseValues(Iterable<LedgerEntry> entries) {
  final now = DateTime.now();
  final values = List<double>.filled(12, 0);
  for (final entry in entries) {
    if (entry.type == EntryType.expense && entry.occurredAt.year == now.year) {
      values[entry.occurredAt.month - 1] += entry.netAmount;
    }
  }
  return values;
}

String formatAmount(num value) {
  if (isZeroAmount(value)) {
    return amountForceTwoDecimals ? '0.00' : '0';
  }
  final text = value.toStringAsFixed(2);
  if (amountForceTwoDecimals) {
    return text;
  }
  return text.endsWith('.00')
      ? text.substring(0, text.length - 3)
      : text.replaceFirst(RegExp(r'0$'), '');
}

String formatExpenseAmount(num value) {
  if (isZeroAmount(value)) {
    return '0';
  }
  return '-${formatAmount(value.abs())}';
}

String formatIncomeAmount(num value) {
  if (isZeroAmount(value)) {
    return '0';
  }
  return formatAmount(value.abs());
}

String formatSignedAmount(double value) {
  if (isZeroAmount(value)) {
    return '0';
  }
  return value > 0
      ? '+${formatAmount(value)}'
      : '-${formatAmount(value.abs())}';
}

/// 紧凑金额（日历单元格等窄处）。中文以「万」为单位，其他语言以 k 为单位——
/// 两种语言的数量级习惯不同，无法用单一 ARB 键表达，故按 locale 分支。
String formatCompactAmount(AppLocalizations l10n, num value) {
  final abs = value.abs();
  if (l10n.localeName.startsWith('zh')) {
    if (abs >= 10000) {
      final compact = value / 10000;
      return '${compact.toStringAsFixed(compact.abs() >= 10 ? 0 : 1)}万';
    }
    if (abs >= 1000) {
      return value.toStringAsFixed(0);
    }
    return formatAmount(value);
  }
  if (abs >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact.abs() >= 10 ? 0 : 1)}k';
  }
  return formatAmount(value);
}

String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
