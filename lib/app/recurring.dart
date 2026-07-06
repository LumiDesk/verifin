// 周期记账的纯函数：日期推进与到期日计算，便于单元测试，不依赖 Flutter。

import 'ledger_math.dart';
import 'models.dart';

/// 把日期按频率推进一个周期。月/年推进时若目标月没有目标日（如锚定 31 号遇 2 月），
/// 收敛到目标月最后一天。
///
/// [anchorDay] 是「用户设定的目标日」（通常为规则 `startDate.day`）。月/年推进必须以它
/// 为基准，而非以上一次已收缩的日：否则 1/31→2/28 后会永久锁死在 28 号，3 月本应回到
/// 31 号却退成 28 号，逐月漂移。省略时回落到 `date.day`（等价于旧行为，供无锚场景）。
DateTime advanceRecurring(
  DateTime date,
  RecurringFrequency frequency, {
  int? anchorDay,
}) {
  switch (frequency) {
    case RecurringFrequency.daily:
      return DateTime(date.year, date.month, date.day + 1);
    case RecurringFrequency.weekly:
      return DateTime(date.year, date.month, date.day + 7);
    case RecurringFrequency.monthly:
      return _addMonths(date, 1, anchorDay ?? date.day);
    case RecurringFrequency.yearly:
      return _addMonths(date, 12, anchorDay ?? date.day);
  }
}

DateTime _addMonths(DateTime date, int months, int anchorDay) {
  final total = date.month - 1 + months;
  final year = date.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = anchorDay <= lastDay ? anchorDay : lastDay;
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
  final anchorDay = rule.startDate.day;
  final result = <DateTime>[];
  var due = dateOnly(rule.nextRunDate);
  var guard = 0;
  while (!due.isAfter(today) && guard < maxCount) {
    result.add(due);
    due = advanceRecurring(due, rule.frequency, anchorDay: anchorDay);
    guard += 1;
  }
  return result;
}
