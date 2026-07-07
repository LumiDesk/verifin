import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/recurring.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

RecurringRule _rule({
  required RecurringFrequency freq,
  required DateTime start,
  DateTime? next,
  bool active = true,
  EntryType type = EntryType.expense,
}) => RecurringRule(
  id: 'r1',
  bookId: defaultLedgerBookId,
  type: type,
  amount: 100,
  categoryId: 'dining',
  accountId: 'cash',
  note: '房租',
  frequency: freq,
  startDate: start,
  nextRunDate: next ?? start,
  active: active,
);

void main() {
  useTestDatabases();

  test('advanceRecurring 各频率', () {
    expect(
      advanceRecurring(DateTime(2026, 1, 31), RecurringFrequency.daily),
      DateTime(2026, 2, 1),
    );
    expect(
      advanceRecurring(DateTime(2026, 1, 1), RecurringFrequency.weekly),
      DateTime(2026, 1, 8),
    );
    // 月推进遇短月收敛到最后一天。
    expect(
      advanceRecurring(DateTime(2026, 1, 31), RecurringFrequency.monthly),
      DateTime(2026, 2, 28),
    );
    expect(
      advanceRecurring(DateTime(2026, 3, 15), RecurringFrequency.yearly),
      DateTime(2027, 3, 15),
    );
  });

  test('dueDatesFor 补齐到今天，停用规则不产出', () {
    final rule = _rule(
      freq: RecurringFrequency.monthly,
      start: DateTime(2026, 4, 10),
    );
    final due = dueDatesFor(rule, DateTime(2026, 7, 15));
    expect(due, <DateTime>[
      DateTime(2026, 4, 10),
      DateTime(2026, 5, 10),
      DateTime(2026, 6, 10),
      DateTime(2026, 7, 10),
    ]);

    final inactive = _rule(
      freq: RecurringFrequency.monthly,
      start: DateTime(2026, 4, 10),
      active: false,
    );
    expect(dueDatesFor(inactive, DateTime(2026, 7, 15)), isEmpty);
  });

  test('月末锚定：31 号规则不随短月永久漂移', () {
    // 锚定 1/31，逐月应为 1/31、2/28、3/31、4/30、5/31、6/30，而非锁死在 28。
    final rule = _rule(
      freq: RecurringFrequency.monthly,
      start: DateTime(2026, 1, 31),
    );
    final due = dueDatesFor(rule, DateTime(2026, 7, 15));
    expect(due, <DateTime>[
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 31),
      DateTime(2026, 6, 30),
    ]);
  });

  test('月末锚定：即使 nextRunDate 已被收缩到 28 也能回到 31', () {
    // 模拟历史遗留：nextRunDate 停在 2/28，但锚定日仍是 31。
    final rule = _rule(
      freq: RecurringFrequency.monthly,
      start: DateTime(2026, 1, 31),
      next: DateTime(2026, 2, 28),
    );
    final due = dueDatesFor(rule, DateTime(2026, 5, 1));
    expect(due, <DateTime>[
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
    ]);
  });

  test('年度锚定：2/29 规则闰年回到 29', () {
    final rule = _rule(
      freq: RecurringFrequency.yearly,
      start: DateTime(2024, 2, 29),
    );
    final due = dueDatesFor(rule, DateTime(2028, 3, 1));
    expect(due, <DateTime>[
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
      DateTime(2026, 2, 28),
      DateTime(2027, 2, 28),
      DateTime(2028, 2, 29),
    ]);
  });

  test('applyDueRecurring 补记交易并推进 nextRunDate', () async {
    final controller = await makeController();
    final now = DateTime(2026, 7, 15);
    controller.addRecurringRule(
      _rule(
        freq: RecurringFrequency.monthly,
        start: DateTime(2026, 5, 1),
      ).copyWith(),
    );
    // addRecurringRule 保存的是账本无关计数；用 activeBook 版本重建 bookId。
    final generated = controller.applyDueRecurring(now);
    // 5/1、6/1、7/1 三笔。
    expect(generated, 3);
    expect(controller.entries.length, 3);
    // 再次调用不应重复补记。
    expect(controller.applyDueRecurring(now), 0);
    expect(controller.recurringRules.single.nextRunDate, DateTime(2026, 8, 1));
    controller.dispose();
  });

  test('规则日期回拨后重新补记不重复生成同一天的交易', () async {
    final controller = await makeController();
    final now = DateTime(2026, 7, 15);
    controller.addRecurringRule(
      _rule(freq: RecurringFrequency.monthly, start: DateTime(2026, 7, 1)),
    );
    expect(controller.applyDueRecurring(now), 1); // 7/1 一笔
    expect(controller.entries.length, 1);
    // 用户把规则 nextRunDate 回拨到 7/1，重新触发补记。
    final rule = controller.recurringRules.single;
    controller.updateRecurringRule(
      rule.copyWith(nextRunDate: DateTime(2026, 7, 1)),
    );
    // 同一到期日 id 已存在，应跳过而非覆盖，交易数保持 1。
    expect(controller.applyDueRecurring(now), 0);
    expect(controller.entries.length, 1);
    controller.dispose();
  });

  test('周期规则随导出导入往返', () async {
    final source = await makeController();
    source.addRecurringRule(
      _rule(
        freq: RecurringFrequency.monthly,
        start: DateTime(2026, 5, 1),
      ).copyWith(),
    );
    final backup = source.exportDataJson();
    source.dispose();

    final target = await makeController();
    target.importDataJson(backup);
    expect(target.recurringRules.single.note, '房租');
    expect(target.recurringRules.single.frequency, RecurringFrequency.monthly);
    target.dispose();
  });
}
