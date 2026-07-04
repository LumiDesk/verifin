// 周期记账的纯函数：日期推进与到期日计算，便于单元测试，不依赖 Flutter。

import 'ledger_math.dart';
import 'models.dart';

/// 把日期按频率推进一个周期。月/年推进时若目标月没有该日（如 1/31 → 2/28），
/// 收敛到目标月最后一天。
DateTime advanceRecurring(DateTime date, RecurringFrequency frequency) {
  switch (frequency) {
    case RecurringFrequency.daily:
      return DateTime(date.year, date.month, date.day + 1);
    case RecurringFrequency.weekly:
      return DateTime(date.year, date.month, date.day + 7);
    case RecurringFrequency.monthly:
      return _addMonths(date, 1);
    case RecurringFrequency.yearly:
      return _addMonths(date, 12);
  }
}

DateTime _addMonths(DateTime date, int months) {
  final total = date.month - 1 + months;
  final year = date.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day <= lastDay ? date.day : lastDay;
  return DateTime(year, month, day);
}

/// 计算某规则从 [RecurringRule.nextRunDate] 起到 [now]（含当天）之间所有到期日。
/// 停用规则返回空；[maxCount] 防止异常数据导致无限循环。
List<DateTime> dueDatesFor(
  RecurringRule rule,
  DateTime now, {
  int maxCount = 400,
}) {
  if (!rule.active) {
    return const <DateTime>[];
  }
  final today = dateOnly(now);
  final result = <DateTime>[];
  var due = dateOnly(rule.nextRunDate);
  var guard = 0;
  while (!due.isAfter(today) && guard < maxCount) {
    result.add(due);
    due = advanceRecurring(due, rule.frequency);
    guard += 1;
  }
  return result;
}
