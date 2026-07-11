// 信用类账户（信用卡 / 信用账户）的纯函数：账单日/还款日推进、额度与本期账单。

import 'ledger_math.dart';
import 'models.dart';

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

/// 已用额度（当前欠款）：账户负余额的绝对值，非负；余额为正（存入/超额还款）时为 0。
double usedCredit(double balance) {
  return balance < 0 ? -balance : 0;
}

/// 可用额度 = 额度 − 已用。未设额度返回 null。可能因超额还款而接近或等于额度上限。
double? availableCredit(double? creditLimit, double balance) {
  if (creditLimit == null) {
    return null;
  }
  return creditLimit - usedCredit(balance);
}

/// 给定账单日（每月 1–28）和当前时间，返回下一个（含今天）账单日期。
DateTime nextStatementDate(int statementDay, DateTime now) {
  final today = dateOnly(now);
  final day = statementDay.clamp(1, 28);
  final thisMonth = DateTime(today.year, today.month, day);
  if (thisMonth.isBefore(today)) {
    return DateTime(today.year, today.month + 1, day);
  }
  return thisMonth;
}

/// 当前账单周期：上一个账单日次日 至 下一个（含今天）账单日当天（含首尾）。
/// 该窗口内的消费将在下个账单日出账。
DateWindow currentBillingCycle(int statementDay, DateTime now) {
  final nextStmt = nextStatementDate(statementDay, now);
  final day = statementDay.clamp(1, 28);
  final prevStmt = DateTime(nextStmt.year, nextStmt.month - 1, day);
  return DateWindow(
    start: DateTime(prevStmt.year, prevStmt.month, prevStmt.day + 1),
    end: nextStmt,
  );
}

/// 本期账单金额：本账单周期内、该账户支出的净额合计（退款冲抵后）。
/// 还款是转账、不计入支出，故不影响本值；本值与「当前欠款」是两个互不矛盾的口径。
double billingCycleExpense(
  Iterable<LedgerEntry> entries,
  String accountId,
  DateWindow cycle,
) {
  final start = dateOnly(cycle.start);
  final end = dateOnly(cycle.end);
  return entries
      .where(
        (entry) =>
            entry.type == EntryType.expense &&
            entry.accountId == accountId &&
            !dateOnly(entry.occurredAt).isBefore(start) &&
            !dateOnly(entry.occurredAt).isAfter(end),
      )
      .fold<double>(0, (sum, entry) => sum + entry.netAmount);
}
