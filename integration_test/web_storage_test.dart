import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:verifin/app/build_config.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/database_factory.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';

// 使用正式 Web 构建的静态资源与真实插件注册；不走旧的 Flutter Chrome 单元测试宿主。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Web SQLite 和偏好真实持久化、事务回滚及重开', (tester) async {
    expect(await resolveDatabaseFactory(), same(databaseFactoryFfiWeb));
    expect(kSelfUpdateEnabled, isFalse);
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        indexedDbName: 'verifin-browser-test',
        sqlite3WasmUri: Uri.base.resolve('sqlite3.wasm'),
        sharedWorkerUri: Uri.base.resolve('sqflite_sw.js'),
      ),
    );
    final path = 'storage-${DateTime.now().microsecondsSinceEpoch}.db';
    var database = await AppDatabase.open(factory: factory, path: path);
    try {
      var repository = SqliteLedgerRepository(database);
      await repository.saveBooks([
        LedgerBook(
          id: 'web',
          name: 'Web test',
          createdAt: DateTime(2026, 9, 5),
          isDefault: true,
        ),
      ]);
      final entry = LedgerEntry(
        id: 'entry',
        bookId: 'web',
        type: EntryType.expense,
        amount: 12.34,
        categoryId: 'dining',
        accountId: '',
        note: '浏览器持久化',
        occurredAt: DateTime(2026, 9, 5),
      );
      await repository.saveEntries([entry]);
      await repository.saveMonthlyBudgets({'web:2026-09': 500});
      await expectLater(
        database.db.transaction((txn) async {
          await txn.delete('entries');
          throw StateError('intentional rollback');
        }),
        throwsStateError,
      );
      await database.close();
      database = await AppDatabase.open(factory: factory, path: path);
      repository = SqliteLedgerRepository(database);
      expect((await repository.loadEntries()).single.toJson(), entry.toJson());
      expect(await repository.loadMonthlyBudgets(), {'web:2026-09': 500});
      expect((await repository.loadBooks()).single.id, 'web');
      // 失败后继续写入，验证事务失败不会阻塞后续仓储写。
      await repository.saveEntries([]);
      expect(await repository.loadEntries(), isEmpty);
    } finally {
      await database.close();
      await factory.deleteDatabase(path);
    }

    final key = 'verifin.browser-test.${DateTime.now().microsecondsSinceEpoch}';
    final first = await LocalKeyValueStore.create();
    try {
      await first.writeAndFlush(key, '中文偏好');
      final second = await LocalKeyValueStore.create();
      expect(second.read(key), '中文偏好');
      await second.deleteAndFlush(key);
      final third = await LocalKeyValueStore.create();
      expect(third.read(key), isNull);
    } finally {
      await first.deleteAndFlush(key);
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Web storage PASS'))),
      ),
    );
  });
}
