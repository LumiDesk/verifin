import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

double signedAmount(LedgerEntry entry) {
  switch (entry.type) {
    case EntryType.expense:
      // 退款/报销回款冲抵后的净支出。
      return -entry.netAmount;
    case EntryType.income:
      return entry.amount;
    case EntryType.transfer:
      return 0;
  }
}

double accountDeltaForEntry(LedgerEntry entry, String accountId) {
  switch (entry.type) {
    case EntryType.expense:
      // 退款回到原账户，账户净支出为「金额 − 已冲抵」。
      return entry.accountId == accountId ? -entry.netAmount : 0;
    case EntryType.income:
      return entry.accountId == accountId ? entry.amount : 0;
    case EntryType.transfer:
      if (entry.accountId == accountId) {
        // 转出账户额外扣除手续费。
        return -(entry.amount + entry.fee);
      }
      if (entry.toAccountId == accountId) {
        return entry.amount;
      }
      return 0;
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
    final count = end.difference(start).inDays + 1;
    return List<DateTime>.generate(
      count,
      (index) => start.add(Duration(days: index)),
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

DateWindow sevenDayWindowFor(DateTime date) {
  final startDay = ((date.day - 1) ~/ 7) * 7 + 1;
  final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
  final endDay = (startDay + 6).clamp(1, daysInMonth);
  return DateWindow(
    start: DateTime(date.year, date.month, startDay),
    end: DateTime(date.year, date.month, endDay),
  );
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
    return '0';
  }
  final text = value.toStringAsFixed(2);
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

String formatCompactAmount(num value) {
  final abs = value.abs();
  if (abs >= 10000) {
    final compact = value / 10000;
    return '${compact.toStringAsFixed(compact.abs() >= 10 ? 0 : 1)}万';
  }
  if (abs >= 1000) {
    return value.toStringAsFixed(0);
  }
  return formatAmount(value);
}

String formatDate(DateTime date) {
  return '${date.month}月${date.day}日';
}

String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
