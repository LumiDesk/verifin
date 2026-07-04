import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/credit_card.dart';

void main() {
  test('nextDueDate 当月未过取当月，已过顺延下月', () {
    // 今天 7/10，还款日 25 → 当月 7/25。
    expect(nextDueDate(25, DateTime(2026, 7, 10)), DateTime(2026, 7, 25));
    // 今天 7/26，还款日 25 → 下月 8/25。
    expect(nextDueDate(25, DateTime(2026, 7, 26)), DateTime(2026, 8, 25));
    // 当天即还款日 → 取当天。
    expect(nextDueDate(10, DateTime(2026, 7, 10)), DateTime(2026, 7, 10));
    // 12 月顺延跨年。
    expect(nextDueDate(5, DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
  });

  test('daysUntilDue 计算剩余天数', () {
    expect(daysUntilDue(25, DateTime(2026, 7, 10)), 15);
    expect(daysUntilDue(10, DateTime(2026, 7, 10)), 0);
    expect(daysUntilDue(25, DateTime(2026, 7, 26)), 30);
  });
}
