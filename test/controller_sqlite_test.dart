import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<LedgerRepository> openRepo() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    return LedgerRepository(db);
  }

  LedgerEntry entry(String id, {double amount = 10}) => LedgerEntry(
    id: id,
    bookId: defaultLedgerBookId,
    type: EntryType.expense,
    amount: amount,
    categoryId: 'dining',
    accountId: 'alipay',
    note: '',
    occurredAt: DateTime(2026, 5, int.parse(id)),
  );

  test('挂载仓储后新增的交易写入 SQLite 并可被新控制器读回', () async {
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    controller.addEntry(entry('1', amount: 25));
    await controller.waitForPendingWrites();

    expect((await repo.loadEntries()).single.amount, 25);

    // 共享同一数据库的新控制器应从库中恢复交易。
    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    expect(reloaded.entries.single.id, '1');
  });

  test('首启动把 KV 历史交易迁移进 SQLite', () async {
    final store = LocalKeyValueStore();
    store.write(
      'verifin.entries.v1',
      jsonEncode(<Map<String, Object?>>[
        entry('2', amount: 8).toJson(),
        entry('3', amount: 9).toJson(),
      ]),
    );
    final repo = await openRepo();
    final controller = await VeriFinController.create(store, repository: repo);

    expect(controller.entries.length, 2);
    expect((await repo.loadEntries()).length, 2);
    // 迁移标记落位，二次创建不重复导入。
    expect(store.read('verifin.migration.entries.v1'), 'true');

    controller.deleteEntry('2');
    await controller.waitForPendingWrites();
    final again = await VeriFinController.create(
      LocalKeyValueStore()..write('verifin.migration.entries.v1', 'true'),
      repository: repo,
    );
    expect(again.entries.single.id, '3');
  });
}
