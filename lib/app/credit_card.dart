// 信用卡账单日/还款日的纯函数：计算下一个还款日与剩余天数。

import 'ledger_math.dart';

/// 给定还款日（每月 1–28）和当前时间，返回下一个还款日期。
/// 今天已过当月还款日则顺延到下月。
DateTime nextDueDate(int dueDay, DateTime now) {
  final today = dateOnly(now);
  final day = dueDay.clamp(1, 28);
  final thisMonth = DateTime(today.year, today.month, day);
  if (thisMonth.isBefore(today)) {
    return DateTime(today.year, today.month + 1, day);
  }
  return thisMonth;
}

/// 距离下一个还款日的天数（今天为 0）。
int daysUntilDue(int dueDay, DateTime now) {
  return nextDueDate(dueDay, now).difference(dateOnly(now)).inDays;
}
