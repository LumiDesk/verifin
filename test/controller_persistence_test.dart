import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';
import 'package:verifin/local_storage/local_storage.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  final opened = <AppDatabase>[];
  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
  });

  // ffi 会跨调用复用 :memory: 数据库，测试间必须关闭以隔离。
  Future<LedgerRepository> openRepo() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    opened.add(db);
    return SqliteLedgerRepository(db);
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

  test('账本/账户/分组写入 SQLite 并被新控制器读回', () async {
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    // 全新数据库首启动已播种默认账本（默认账户为空，用户新增后才有）。
    expect(await repo.loadBooks(), isNotEmpty);

    controller.addLedgerBook('旅行账本');
    controller.addAccountGroup('出行');
    await controller.waitForPendingWrites();

    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    expect(reloaded.ledgerBooks.any((b) => b.name == '旅行账本'), isTrue);
    // addLedgerBook 会切换活动账本，分组落在新账本下。
    reloaded.switchLedgerBook(
      reloaded.ledgerBooks.firstWhere((b) => b.name == '旅行账本').id,
    );
    expect(reloaded.accountGroups.any((g) => g.name == '出行'), isTrue);
  });

  test('新增账户后新控制器能读回', () async {
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    controller.addAccount(
      const Account(
        id: 'my-cash',
        bookId: defaultLedgerBookId,
        name: '钱包',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 66,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
        cardLast4: '',
      ),
    );
    await controller.waitForPendingWrites();

    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    final restored = reloaded.accounts.firstWhere((a) => a.id == 'my-cash');
    expect(restored.name, '钱包');
    expect(restored.initialBalance, 66);
  });

  test('分类与预算写入 SQLite 并被新控制器读回', () async {
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    final month = DateTime(2026, 6);
    controller.addCategory(
      type: EntryType.expense,
      label: '宠物',
      iconCode: 'pets',
    );
    controller.setMonthlyBudget(month, 2000);
    final petCategory = controller
        .categoriesForType(EntryType.expense)
        .firstWhere((c) => c.label == '宠物');
    controller.setCategoryBudget(month, petCategory.id, 500);
    await controller.waitForPendingWrites();

    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    expect(
      reloaded.categoriesForType(EntryType.expense).any((c) => c.label == '宠物'),
      isTrue,
    );
    expect(reloaded.monthlyBudget(month), 2000);
    expect(reloaded.categoryBudget(month, petCategory.id), 500);
  });

  test('导入备份写入 SQLite 并被新控制器读回', () async {
    final rawJson = File(
      'docs/dev/verifin-sample-backup.json',
    ).readAsStringSync();
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    controller.importDataJson(rawJson);
    await controller.waitForPendingWrites();

    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    expect(reloaded.accounts.length, greaterThanOrEqualTo(8));
    expect(reloaded.entries.length, greaterThanOrEqualTo(20));
    expect(reloaded.categories.any((c) => c.id == 'coffee'), isTrue);
    // 导出应能从 SQLite 恢复出的内存状态重建等价备份。
    final reExported = jsonDecode(reloaded.exportDataJson()) as Map;
    expect((reExported['data'] as Map)['entries'], isNotEmpty);
  });

  test('重置数据会清空 SQLite', () async {
    final repo = await openRepo();
    final controller = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    controller.addEntry(entry('4'));
    await controller.waitForPendingWrites();
    expect(await repo.loadEntries(), isNotEmpty);

    controller.resetAllData();
    await controller.waitForPendingWrites();
    expect(await repo.loadEntries(), isEmpty);

    final reloaded = await VeriFinController.create(
      LocalKeyValueStore(),
      repository: repo,
    );
    expect(reloaded.entries, isEmpty);
  });
}
