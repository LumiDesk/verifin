import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Account makeAccount(String id, String bookId, String name) => Account(
    id: id,
    bookId: bookId,
    name: name,
    type: AccountType.cash,
    groupId: null,
    initialBalance: 0,
    iconCode: 'cash',
    note: '',
    includeInAssets: true,
    hidden: false,
  );

  test('默认账户默认为空，设置后即返回', () async {
    final controller = await makeController();
    final cash = makeAccount('acc-cash', controller.activeBook.id, '现金');
    controller.addAccount(cash);
    expect(controller.defaultAccountId, isNull);

    controller.setDefaultAccountId(cash.id);
    expect(controller.defaultAccountId, cash.id);

    controller.setDefaultAccountId(null);
    expect(controller.defaultAccountId, isNull);
  });

  test('默认账户随重启持久化', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final cash = makeAccount('acc-cash', controller.activeBook.id, '现金');
    controller
      ..addAccount(cash)
      ..setDefaultAccountId(cash.id);

    // 相同 store 复用同一内存仓储，模拟同设备重启后重新载入。
    final reloaded = await makeController(store);
    expect(reloaded.defaultAccountId, cash.id);
  });

  test('账户删除后默认引用失效返回 null', () async {
    final controller = await makeController();
    final cash = makeAccount('acc-cash', controller.activeBook.id, '现金');
    controller
      ..addAccount(cash)
      ..setDefaultAccountId(cash.id);
    expect(controller.defaultAccountId, cash.id);

    await controller.deleteAccount(cash.id);
    expect(controller.defaultAccountId, isNull);
  });

  test('隐藏账户不作为有效默认', () async {
    final controller = await makeController();
    final cash = makeAccount('acc-cash', controller.activeBook.id, '现金');
    controller
      ..addAccount(cash)
      ..setDefaultAccountId(cash.id);
    expect(controller.defaultAccountId, cash.id);

    controller.updateAccount(cash.copyWith(hidden: true));
    expect(controller.defaultAccountId, isNull);
  });
}
