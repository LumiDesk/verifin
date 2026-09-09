import 'package:flutter/material.dart';

import 'ledger_math.dart';
import 'currency_math.dart';
import 'models.dart';
import '../l10n/app_localizations.dart';

bool isInMonth(LedgerEntry entry, DateTime month) {
  return entry.occurredAt.year == month.year &&
      entry.occurredAt.month == month.month;
}

List<String> monthAxisLabels(DateTime month) {
  final days = DateUtils.getDaysInMonth(month.year, month.month);
  return <String>[
    '${month.month}.1',
    '${month.month}.${(days / 2).round()}',
    '${month.month}.$days',
  ];
}

List<String> reportAxisLabels(double maxValue) {
  final top = maxValue <= 0 ? 100 : maxValue;
  return <String>['0', _formatAxisAmount(top / 2), _formatAxisAmount(top)];
}

String _formatAxisAmount(num value, {String? currencyCode}) {
  final abs = value.abs();
  if (abs >= 10000) {
    final compact = value / 10000;
    final decimals = compact.abs() >= 10 || compact % 1 == 0 ? 0 : 1;
    return '${compact.toStringAsFixed(decimals)}w';
  }
  return currencyCode == null
      ? formatAmount(value)
      : formatCurrencyNumber(value, currencyCode);
}

String twoDigitYear(int year) => (year % 100).toString().padLeft(2, '0');

int isoWeekYear(DateTime date) {
  return addCalendarDays(date, 4 - date.weekday).year;
}

int isoWeekNumber(DateTime date) {
  final thursday = addCalendarDays(date, 4 - date.weekday);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final weekOne = addCalendarDays(firstThursday, 4 - firstThursday.weekday);
  return calendarDaysBetween(weekOne, thursday) ~/ 7 + 1;
}

/// 当月每日余额:基线包含本月之前的全部历史流水,余额保留正负号。

List<double> accountBalanceSeries(Account account, List<LedgerEntry> entries) {
  final now = DateTime.now();
  final days = DateUtils.getDaysInMonth(now.year, now.month);
  final monthStart = DateTime(now.year, now.month);
  var runningBalance = account.initialBalance;
  final dailyDeltas = List<double>.filled(days, 0);
  for (final entry in entries) {
    final delta = accountDeltaForEntry(entry, account.id);
    if (delta == 0) {
      continue;
    }
    final effectDate = accountEffectDate(entry);
    if (effectDate.isBefore(monthStart)) {
      runningBalance += delta;
    } else if (effectDate.year == now.year && effectDate.month == now.month) {
      dailyDeltas[effectDate.day - 1] += delta;
    }
  }
  final values = List<double>.filled(days, 0);
  for (var i = 0; i < days; i += 1) {
    runningBalance += dailyDeltas[i];
    values[i] = runningBalance;
  }
  return values;
}

/// 今年逐月月末余额:基线包含往年全部流水,余额保留正负号。

List<double> accountMonthlyBalanceSeries(
  Account account,
  List<LedgerEntry> entries,
) {
  return accountMonthlyBalanceSeriesBatch(<Account>[
    account,
  ], entries)[account.id]!;
}

/// 今年逐月月末余额(全部账户一次遍历):每个账户的 12 期结果必须与逐个账户调用
/// [accountMonthlyBalanceSeries] 完全一致——同样的往年基线、月份增量与输出口径。

Map<String, List<double>> accountMonthlyBalanceSeriesBatch(
  List<Account> accounts,
  List<LedgerEntry> entries,
) {
  final now = DateTime.now();
  final yearStart = DateTime(now.year);
  final baselines = <String, double>{
    for (final account in accounts) account.id: account.initialBalance,
  };
  final monthlyDeltas = <String, List<double>>{
    for (final account in accounts) account.id: List<double>.filled(12, 0),
  };
  for (final entry in entries) {
    final effectDate = accountEffectDate(entry);
    final beforeYear = effectDate.isBefore(yearStart);
    if (!beforeYear && effectDate.year != now.year) {
      continue;
    }
    final fromId = entry.accountId;
    final toId = entry.toAccountId;
    // 转出=转入只算一次:accountDeltaForEntry 已把两端净额合并,拆开会计重。
    for (final accountId in <String>[
      fromId,
      if (toId != null && toId != fromId) toId,
    ]) {
      final deltas = monthlyDeltas[accountId];
      if (deltas == null) {
        continue;
      }
      final delta = accountDeltaForEntry(entry, accountId);
      if (delta == 0) {
        continue;
      }
      if (beforeYear) {
        baselines[accountId] = baselines[accountId]! + delta;
      } else {
        deltas[effectDate.month - 1] += delta;
      }
    }
  }
  final result = <String, List<double>>{};
  for (final account in accounts) {
    final deltas = monthlyDeltas[account.id]!;
    var runningBalance = baselines[account.id]!;
    final values = List<double>.filled(12, 0);
    for (var month = 0; month < 12; month += 1) {
      runningBalance += deltas[month];
      values[month] = runningBalance;
    }
    result[account.id] = values;
  }
  return result;
}

/// 今年逐月净资产:基线包含往年全部流水,净资产保留正负号。

List<double> monthlyNetAssetSeries(
  List<Account> accounts,
  List<LedgerEntry> entries,
) {
  final visibleAccounts = accounts
      .where((account) => account.includeInAssets && !account.hidden)
      .toList();
  if (visibleAccounts.isEmpty) {
    return List<double>.filled(12, 0);
  }
  final now = DateTime.now();
  final yearStart = DateTime(now.year);
  var baseline = visibleAccounts.fold<double>(
    0,
    (sum, account) => sum + account.initialBalance,
  );
  final monthlyDeltas = List<double>.filled(12, 0);
  for (final entry in entries) {
    var delta = 0.0;
    for (final account in visibleAccounts) {
      delta += accountDeltaForEntry(entry, account.id);
    }
    if (delta == 0) {
      continue;
    }
    final effectDate = accountEffectDate(entry);
    if (effectDate.isBefore(yearStart)) {
      baseline += delta;
    } else if (effectDate.year == now.year) {
      monthlyDeltas[effectDate.month - 1] += delta;
    }
  }
  final values = List<double>.filled(12, 0);
  var runningTotal = baseline;
  for (var month = 0; month < 12; month += 1) {
    runningTotal += monthlyDeltas[month];
    values[month] = runningTotal;
  }
  return values;
}

/// 余额类序列的纵轴刻度:范围取序列实际的 [min, max](含 0)。

List<String> balanceAxisLabels(List<double> values, String currencyCode) {
  var maxValue = 0.0;
  var minValue = 0.0;
  for (final value in values) {
    if (value > maxValue) {
      maxValue = value;
    }
    if (value < minValue) {
      minValue = value;
    }
  }
  if (maxValue - minValue <= 0) {
    return <String>[
      formatCurrencyNumber(0, currencyCode),
      formatCurrencyNumber(50, currencyCode),
      formatCurrencyNumber(100, currencyCode),
    ];
  }
  return <String>[
    _formatAxisAmount(minValue, currencyCode: currencyCode),
    _formatAxisAmount((minValue + maxValue) / 2, currencyCode: currencyCode),
    _formatAxisAmount(maxValue, currencyCode: currencyCode),
  ];
}

List<String> evenMonthAxisLabels() {
  return const <String>['2', '4', '6', '8', '10', '12'];
}

int bookkeepingDays(List<LedgerEntry> entries) {
  if (entries.isEmpty) {
    return 0;
  }
  final first = entries
      .map((entry) => entry.occurredAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return calendarDaysBetween(first, DateTime.now()) + 1;
}

/// 记账时长的展示文案:一年以内显示天数,超过一年显示 1.2、2 这样的年数。
(String, String) bookkeepingDurationStat(AppLocalizations l10n, int days) {
  if (days <= 365) {
    return ('$days', l10n.bookkeepingDays);
  }
  final years = days / 365;
  final text = years.toStringAsFixed(1);
  return (
    text.endsWith('.0') ? text.substring(0, text.length - 2) : text,
    l10n.bookkeepingYears,
  );
}

/// 每笔交易**生效后**其所属账户的余额（含账户初始余额）。
///
/// 供交易列表可选的「逐笔结余」使用。按 [accountEffectDate] 升序累加，同日按 id
/// 稳定排序；转账同时更新两端账户，退款按到账日计入到账账户；无账户的交易
/// （`accountId` 为空）不产生条目。返回 map 的键是交易 id。
Map<String, double> accountBalanceAfterEntry({
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
}) {
  final balances = <String, double>{
    for (final account in accounts) account.id: account.initialBalance,
  };
  final ordered = entries.toList()
    ..sort((a, b) {
      final byDate = accountEffectDate(a).compareTo(accountEffectDate(b));
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final result = <String, double>{};
  for (final entry in ordered) {
    final accountId = entry.accountId;
    final toAccountId = entry.toAccountId;
    if (accountId.isNotEmpty) {
      balances[accountId] =
          (balances[accountId] ?? 0) + accountDeltaForEntry(entry, accountId);
    }
    if (toAccountId != null && toAccountId.isNotEmpty) {
      balances[toAccountId] =
          (balances[toAccountId] ?? 0) +
          accountDeltaForEntry(entry, toAccountId);
    }
    if (accountId.isNotEmpty) {
      result[entry.id] = balances[accountId] ?? 0;
    }
  }
  return result;
}
