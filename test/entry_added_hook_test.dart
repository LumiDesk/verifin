import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('CSV 导入触发 onEntryAdded（自动备份/小组件刷新）', () async {
    final controller = await makeController();
    var fired = 0;
    controller.onEntryAdded = () => fired++;

    controller.importTransactionsFromCsv(
      '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,23.5,餐饮,现金,,午饭',
    );

    expect(controller.entries.length, greaterThan(0));
    expect(fired, 1);
    controller.dispose();
  });

  test('余额调整触发 onEntryAdded', () async {
    final controller = await makeController();
    // 先经导入建一个「现金」账户。
    controller.importTransactionsFromCsv(
      '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,10,餐饮,现金,,x',
    );
    final account = controller.accounts.firstWhere((a) => a.name == '现金');
    var fired = 0;
    controller.onEntryAdded = () => fired++;

    controller.adjustAccountBalance(
      account,
      controller.accountBalance(account) + 100,
    );

    expect(fired, 1);
    controller.dispose();
  });
}
