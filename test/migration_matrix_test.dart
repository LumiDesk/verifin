import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';

/// 迁移矩阵测试：从每一个历史版本起步升级到最新 schema，断言
/// ① 升级后的库结构与全新建库（onCreate）完全一致——抓「迁移段忘加列/表，
///    与 _schemaCurrent 漂移」这类只坑老用户的 bug；
/// ② v1 时代写入的数据完整幸存，新增列回落到预期默认值。
///
/// 中间版本库的构造方式：真实 v1 建表语句（下方冻结副本）+ 经
/// [AppDatabase.migrations] 逐段推进到目标版本——不在测试里手抄各版本 schema，
/// 避免测试自身与迁移代码漂移。
///
/// **v1 建表语句是历史事实的冻结副本（提交 65d14cd），永远不要改它**；
/// 新版本 schema 变更只体现在迁移段与 _schemaCurrent 里。
const List<String> _schemaV1 = <String>[
  '''
  CREATE TABLE ledger_books (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    is_default INTEGER NOT NULL,
    sort_order INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE entries (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    type TEXT NOT NULL,
    amount REAL NOT NULL,
    category_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    to_account_id TEXT,
    note TEXT NOT NULL,
    occurred_at INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_entries_book ON entries (book_id)',
  'CREATE INDEX idx_entries_occurred ON entries (occurred_at)',
  '''
  CREATE TABLE accounts (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    group_id TEXT,
    initial_balance REAL NOT NULL,
    icon_code TEXT NOT NULL,
    note TEXT NOT NULL,
    include_in_assets INTEGER NOT NULL,
    hidden INTEGER NOT NULL,
    card_last4 TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_accounts_book ON accounts (book_id)',
  '''
  CREATE TABLE account_groups (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    name TEXT NOT NULL,
    icon_code TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_account_groups_book ON account_groups (book_id)',
  '''
  CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    type TEXT NOT NULL,
    icon_code TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE monthly_budgets (
    scope_key TEXT PRIMARY KEY,
    amount REAL NOT NULL
  )
  ''',
  '''
  CREATE TABLE category_budgets (
    scope_key TEXT PRIMARY KEY,
    amount REAL NOT NULL
  )
  ''',
];

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late Map<String, Object?> freshSchema;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('verifin_migration_');
    // 全新建库的结构基线：迁移后的老库必须与它逐表逐列一致。
    final fresh = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    freshSchema = await _describeSchema(fresh.db);
    await fresh.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('迁移注册表覆盖 2..schemaVersion 的每个版本', () {
    for (var version = 2; version <= AppDatabase.schemaVersion; version++) {
      expect(
        AppDatabase.migrations.containsKey(version),
        isTrue,
        reason: '缺少升级到 v$version 的迁移段：提升 schemaVersion 时必须同步注册',
      );
    }
  });

  for (var start = 1; start < AppDatabase.schemaVersion; start++) {
    test('v$start 起步升级到最新：结构与全新库一致、数据完整幸存', () async {
      final path = '${tempDir.path}/from_v$start.db';

      // 1) 造真实 v1 库并写入代表性数据（只用 v1 时代存在的列）。
      final raw = await databaseFactoryFfi.openDatabase(path);
      for (final statement in _schemaV1) {
        await raw.execute(statement);
      }
      await _seedV1Data(raw);

      // 2) 经迁移注册表逐段推进到 start 版本，标记 user_version 供重开时续跑。
      for (var version = 2; version <= start; version++) {
        await AppDatabase.migrations[version]!(raw);
      }
      await raw.execute('PRAGMA user_version = $start');
      await raw.close();

      // 3) 正常打开：触发 start → schemaVersion 的剩余迁移。
      final app = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );

      // 4) 结构等价：表清单、每表列（名/类型/非空/主键）、索引清单。
      expect(await _describeSchema(app.db), freshSchema);

      // 5) 数据幸存 + 新增列回落默认值。
      final repo = SqliteLedgerRepository(app);

      final entries = await repo.loadEntries();
      expect(entries, hasLength(4));
      final lunch = entries.singleWhere((e) => e.id == 'e1');
      expect(lunch.amount, 25.5);
      expect(lunch.note, '午饭');
      expect(lunch.fee, 0);
      expect(lunch.reimbursable, isFalse);
      expect(lunch.refundedAmount, 0);
      expect(lunch.refundOf, isNull);
      expect(lunch.settledAt, isNull);
      expect(lunch.tagIds, isEmpty);
      expect(lunch.currencyCode, 'CNY');
      expect(lunch.accountAmount, 25.5);
      expect(lunch.toAccountAmount, isNull);
      expect(lunch.baseAmount, 25.5);
      expect(lunch.conversionSource, ConversionSource.legacy);
      final transfer = entries.singleWhere((entry) => entry.id == 'e4');
      expect(transfer.currencyCode, 'CNY');
      expect(transfer.accountAmount, 50);
      expect(transfer.toAccountAmount, 50);
      expect(transfer.baseAmount, 0);
      expect(transfer.conversionSource, ConversionSource.legacy);

      // v10 去重：两个「餐饮」合并为一个，引用它们的交易统一指向保留者。
      final categories = await repo.loadCategories();
      expect(categories, hasLength(2));
      final dinnerCategory = entries.singleWhere((e) => e.id == 'e2');
      expect(dinnerCategory.categoryId, lunch.categoryId);

      final account = (await repo.loadAccounts()).single;
      expect(account.cardNumber, '');
      // v12 迁移给旧账户默认「不跟随」，与全新账户的默认 true 有意不同。
      expect(account.cardLast4Follows, isFalse);
      expect(account.creditLimit, isNull);
      expect(account.statementDay, isNull);
      expect(account.dueDay, isNull);
      expect(account.currencyCode, 'CNY');

      final book = (await repo.loadBooks()).single;
      expect(book.name, '日常账本');
      expect(book.baseCurrencyCode, 'CNY');
      expect(book.currencySetupStatus, CurrencySetupStatus.legacyUnconfirmed);
      expect((await repo.loadAccountGroups()).single.name, '资金');
      final groupColumns = await app.db.rawQuery(
        'PRAGMA table_info(account_groups)',
      );
      expect(
        groupColumns.map((row) => row['name']),
        isNot(contains('icon_code')),
      );
      expect(await repo.loadMonthlyBudgets(), {'default:2026-01': 3000.0});
      expect(await repo.loadCategoryBudgets(), {'default:cat-a': 500.0});
      expect(await repo.loadDailyBudgets(), isEmpty);
      expect(await repo.loadTags(), isEmpty);
      expect(await repo.loadAttachments(), isEmpty);
      expect(await repo.loadRecurringRules(), isEmpty);
      expect(await repo.loadExchangeRates(), isEmpty);

      await app.close();
    });
  }

  test('v13 周期规则升级后补齐 CNY 金额模板与固定汇率策略', () async {
    final path = '${tempDir.path}/v13_recurring.db';
    final raw = await databaseFactoryFfi.openDatabase(path);
    for (final statement in _schemaV1) {
      await raw.execute(statement);
    }
    for (var version = 2; version <= 13; version++) {
      await AppDatabase.migrations[version]!(raw);
    }
    await raw.insert('recurring_rules', <String, Object?>{
      'id': 'rule-old',
      'book_id': 'default',
      'type': 'transfer',
      'amount': 66.6,
      'category_id': 'cat-a',
      'account_id': 'acc-1',
      'to_account_id': 'acc-2',
      'note': '旧转账规则',
      'frequency': 'monthly',
      'start_date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'next_run_date': DateTime(2026, 2, 1).millisecondsSinceEpoch,
      'active': 1,
      'sort_order': 0,
    });
    await raw.execute('PRAGMA user_version = 13');
    await raw.close();

    final app = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final rule = (await SqliteLedgerRepository(
      app,
    ).loadRecurringRules()).single;
    expect(rule.currencyCode, 'CNY');
    expect(rule.accountAmount, 66.6);
    expect(rule.toAccountAmount, 66.6);
    expect(rule.baseAmount, 0);
    expect(rule.ratePolicy, RecurringRatePolicy.fixedAmounts);
    await app.close();
  });
}

/// v1 时代的代表性数据：账本/账户/分组/分类（含一对重复「餐饮」，供 v10 去重
/// 迁移在真实链路上发挥）/四笔交易/两类预算。
Future<void> _seedV1Data(Database db) async {
  final when = DateTime(2026, 1, 10, 12).millisecondsSinceEpoch;
  await db.insert('ledger_books', <String, Object?>{
    'id': 'default',
    'name': '日常账本',
    'created_at': when,
    'is_default': 1,
    'sort_order': 0,
  });
  await db.insert('accounts', <String, Object?>{
    'id': 'acc-1',
    'book_id': 'default',
    'name': '支付宝',
    'type': 'onlinePayment',
    'group_id': null,
    'initial_balance': 100.0,
    'icon_code': 'alipay',
    'note': '',
    'include_in_assets': 1,
    'hidden': 0,
    'card_last4': '',
    'sort_order': 0,
  });
  await db.insert('account_groups', <String, Object?>{
    'id': 'grp-1',
    'book_id': 'default',
    'name': '资金',
    'icon_code': 'wallet',
    'sort_order': 0,
  });
  for (final (index, id) in const <String>['cat-a', 'cat-b'].indexed) {
    await db.insert('categories', <String, Object?>{
      'id': id,
      'label': '餐饮',
      'type': 'expense',
      'icon_code': 'dining',
      'sort_order': index,
    });
  }
  await db.insert('categories', <String, Object?>{
    'id': 'cat-c',
    'label': '工资',
    'type': 'income',
    'icon_code': 'salary',
    'sort_order': 2,
  });
  final entryRows = <(String, String, double, String, String)>[
    ('e1', 'expense', 25.5, 'cat-a', '午饭'),
    ('e2', 'expense', 30.0, 'cat-b', '晚饭'),
    ('e3', 'income', 100.0, 'cat-c', '红包'),
  ];
  for (final (id, type, amount, categoryId, note) in entryRows) {
    await db.insert('entries', <String, Object?>{
      'id': id,
      'book_id': 'default',
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'account_id': 'acc-1',
      'to_account_id': null,
      'note': note,
      'occurred_at': when,
    });
  }
  await db.insert('entries', <String, Object?>{
    'id': 'e4',
    'book_id': 'default',
    'type': 'transfer',
    'amount': 50.0,
    'category_id': 'cat-a',
    'account_id': 'acc-1',
    'to_account_id': 'acc-2',
    'note': '转账',
    'occurred_at': when,
  });
  await db.insert('monthly_budgets', <String, Object?>{
    'scope_key': 'default:2026-01',
    'amount': 3000.0,
  });
  await db.insert('category_budgets', <String, Object?>{
    'scope_key': 'default:cat-a',
    'amount': 500.0,
  });
}

/// 库结构描述：表 → { 列名 → "类型|notnull|pk" } + 索引名清单。
/// 有意不含列默认值（dflt_value）与列顺序：迁移库与全新库的列顺序必然不同
/// （ALTER 只能追加），card_last4_follows 的默认值也有意不同（老账户 0、新库 1，
/// 见 v12 迁移注释）；这两者不属于「结构漂移」。
Future<Map<String, Object?>> _describeSchema(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name",
  );
  final description = <String, Object?>{};
  for (final table in tables.map((row) => row['name'] as String)) {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    description[table] = <String, String>{
      for (final column in columns)
        column['name'] as String:
            '${column['type']}|notnull=${column['notnull']}|pk=${column['pk']}',
    };
  }
  final indexes = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='index' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  description['__indexes__'] = indexes
      .map((row) => row['name'] as String)
      .toList();
  return description;
}
