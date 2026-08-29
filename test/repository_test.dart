import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';

/// 旧版 accounts 表（无 statement_day/due_day）。迁移测试的桩库都需要它，
/// 因为 v7→v8 会 ALTER accounts。
const String _legacyAccountsTable = '''
  CREATE TABLE accounts (
    id TEXT PRIMARY KEY, book_id TEXT NOT NULL, name TEXT NOT NULL,
    type TEXT NOT NULL, group_id TEXT, initial_balance REAL NOT NULL,
    icon_code TEXT NOT NULL, note TEXT NOT NULL,
    include_in_assets INTEGER NOT NULL, hidden INTEGER NOT NULL,
    card_last4 TEXT NOT NULL, sort_order INTEGER NOT NULL
  )
''';

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

  test('新建数据库为空', () async {
    final repo = await openRepo();
    expect(await repo.hasAnyData(), isFalse);
    expect(await repo.loadEntries(), isEmpty);
    expect(await repo.loadAccounts(), isEmpty);
    expect(await repo.loadMonthlyBudgets(), isEmpty);
  });

  test('交易保存后可原样读回并按时间倒序', () async {
    final repo = await openRepo();
    final older = LedgerEntry(
      id: '1',
      bookId: defaultLedgerBookId,
      type: EntryType.expense,
      amount: 12.5,
      categoryId: 'dining',
      accountId: 'alipay',
      note: '午饭',
      occurredAt: DateTime(2026, 1, 1, 8),
    );
    final newer = LedgerEntry(
      id: '2',
      bookId: defaultLedgerBookId,
      type: EntryType.transfer,
      amount: 100,
      categoryId: 'transfer',
      accountId: 'alipay',
      toAccountId: 'wechat',
      note: '转账',
      occurredAt: DateTime(2026, 2, 1, 9),
    );
    await repo.saveEntries(<LedgerEntry>[older, newer]);

    final loaded = await repo.loadEntries();
    expect(loaded.map((e) => e.id).toList(), <String>['2', '1']);
    expect(loaded.first.type, EntryType.transfer);
    expect(loaded.first.toAccountId, 'wechat');
    expect(loaded.first.occurredAt, DateTime(2026, 2, 1, 9));
    expect(loaded.last.amount, 12.5);
    expect(await repo.hasAnyData(), isTrue);
  });

  test('saveEntries 整表覆盖而非追加', () async {
    final repo = await openRepo();
    LedgerEntry entry(String id) => LedgerEntry(
      id: id,
      bookId: defaultLedgerBookId,
      type: EntryType.income,
      amount: 1,
      categoryId: 'salary',
      accountId: 'alipay',
      note: '',
      occurredAt: DateTime(2026, 3, 1),
    );
    await repo.saveEntries(<LedgerEntry>[entry('a'), entry('b')]);
    await repo.saveEntries(<LedgerEntry>[entry('c')]);
    final loaded = await repo.loadEntries();
    expect(loaded.map((e) => e.id).toList(), <String>['c']);
  });

  test('增量写：未改动行不重写、改动行才写、删除行才删', () async {
    final repo = await openRepo();
    final db = opened.last.db;
    LedgerEntry entry(String id, String note) => LedgerEntry(
      id: id,
      bookId: defaultLedgerBookId,
      type: EntryType.expense,
      amount: 1,
      categoryId: 'dining',
      accountId: 'alipay',
      note: note,
      occurredAt: DateTime(2026, 4, 1),
    );

    // 直接查库读某行备注（不经 loadEntries，以免重置内存基线快照）。
    Future<String?> noteOf(String id) async {
      final rows = await db.query(
        'entries',
        columns: <String>['note'],
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
      return rows.isEmpty ? null : rows.first['note'] as String?;
    }

    // 首次保存建立内存基线快照 {a:a0, b:b0}。
    await repo.saveEntries(<LedgerEntry>[entry('a', 'a0'), entry('b', 'b0')]);
    // 绕过仓储直接改库里两行的备注为哨兵，代表这些行的「物理存储」。
    await db.update(
      'entries',
      <String, Object?>{'note': 'SENT_A'},
      where: 'id = ?',
      whereArgs: <Object>['a'],
    );
    await db.update(
      'entries',
      <String, Object?>{'note': 'SENT_B'},
      where: 'id = ?',
      whereArgs: <Object>['b'],
    );

    // 只把 a 改成新值、b 保持基线值再保存：差分应只重写 a，b 不被触碰。
    await repo.saveEntries(<LedgerEntry>[entry('a', 'a1'), entry('b', 'b0')]);
    expect(await noteOf('a'), 'a1', reason: 'a 有改动，应被写入（覆盖哨兵）');
    expect(await noteOf('b'), 'SENT_B', reason: 'b 未改动，不应被重写，物理哨兵值幸存');

    // 删除 a（b 仍传基线值，不变）：只应删掉 a，b 物理行仍在、未被重写。
    await repo.saveEntries(<LedgerEntry>[entry('b', 'b0')]);
    expect(await noteOf('a'), isNull, reason: 'a 被删除');
    expect(await noteOf('b'), 'SENT_B', reason: 'b 始终未被重写');
  });

  test('写队列中一次操作失败后，后续写入仍继续执行', () async {
    final repo = await openRepo();
    final db = opened.last.db;
    await db.execute('DROP TABLE categories');

    final failed = repo.saveCategories(const <Category>[
      Category(
        id: 'missing-table-category',
        label: '分类',
        type: EntryType.expense,
        iconCode: 'category',
      ),
    ]);
    final following = repo.saveEntries(<LedgerEntry>[
      LedgerEntry(
        id: 'after-failure',
        bookId: defaultLedgerBookId,
        type: EntryType.expense,
        amount: 1,
        categoryId: 'dining',
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(2026, 8, 27),
      ),
    ]);

    await expectLater(failed, throwsA(anything));
    await following;

    expect((await repo.loadEntries()).single.id, 'after-failure');
  });

  test('replaceAllLedgerData 一次性原子替换全部表', () async {
    final repo = await openRepo();
    // 先放入一批旧数据。
    await repo.saveEntries(<LedgerEntry>[
      LedgerEntry(
        id: 'old',
        bookId: defaultLedgerBookId,
        type: EntryType.expense,
        amount: 1,
        categoryId: 'dining',
        accountId: 'alipay',
        note: '',
        occurredAt: DateTime(2026, 1, 1),
      ),
    ]);
    await repo.saveAccounts(<Account>[
      const Account(
        id: 'alipay',
        bookId: defaultLedgerBookId,
        name: '旧账户',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
        cardLast4: '',
      ),
    ]);

    // 用快照整体替换。
    final snapshot = LedgerDataSnapshot(
      books: <LedgerBook>[
        LedgerBook(
          id: defaultLedgerBookId,
          name: '导入账本',
          createdAt: DateTime(2026, 2, 1),
          isDefault: true,
        ),
      ],
      accounts: <Account>[
        const Account(
          id: 'new_acc',
          bookId: defaultLedgerBookId,
          name: '新账户',
          type: AccountType.debitCard,
          groupId: null,
          initialBalance: 100,
          iconCode: 'card',
          note: '',
          includeInAssets: true,
          hidden: false,
          cardLast4: '',
        ),
      ],
      accountGroups: const <AccountGroup>[],
      categories: <Category>[
        Category(
          id: 'cat',
          label: '餐饮',
          type: EntryType.expense,
          iconCode: 'food',
        ),
      ],
      tags: const <Tag>[],
      attachments: const <Attachment>[],
      entries: <LedgerEntry>[
        LedgerEntry(
          id: 'new_entry',
          bookId: defaultLedgerBookId,
          type: EntryType.expense,
          amount: 20,
          categoryId: 'cat',
          accountId: 'new_acc',
          note: '',
          occurredAt: DateTime(2026, 2, 2),
        ),
      ],
      recurringRules: const <RecurringRule>[],
      monthlyBudgets: const <String, double>{
        '$defaultLedgerBookId:2026-02': 500,
      },
      categoryBudgets: const <String, double>{},
      dailyBudgets: const <String, double>{},
    );
    await repo.replaceAllLedgerData(snapshot);

    // 旧数据被整体替换、无残留、无孤儿引用。
    final entries = await repo.loadEntries();
    expect(entries.map((e) => e.id).toList(), <String>['new_entry']);
    final accounts = await repo.loadAccounts();
    expect(accounts.map((a) => a.id).toList(), <String>['new_acc']);
    expect(entries.single.accountId, accounts.single.id);
    expect(await repo.loadMonthlyBudgets(), <String, double>{
      '$defaultLedgerBookId:2026-02': 500,
    });
  });

  test('账户/分组/账本/分类保留顺序与字段', () async {
    final repo = await openRepo();
    final books = <LedgerBook>[
      LedgerBook(
        id: defaultLedgerBookId,
        name: '日常',
        createdAt: DateTime(2026, 1, 1),
        isDefault: true,
      ),
      LedgerBook(
        id: 'travel',
        name: '旅行',
        createdAt: DateTime(2026, 2, 1),
        isDefault: false,
      ),
    ];
    await repo.saveBooks(books);
    final loadedBooks = await repo.loadBooks();
    expect(loadedBooks.map((b) => b.id).toList(), <String>[
      'default',
      'travel',
    ]);
    expect(loadedBooks[1].isDefault, isFalse);

    final accounts = <Account>[
      const Account(
        id: 'alipay',
        bookId: defaultLedgerBookId,
        name: '支付宝',
        type: AccountType.onlinePayment,
        groupId: 'daily',
        initialBalance: 200,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
        cardLast4: '',
      ),
      const Account(
        id: 'card',
        bookId: defaultLedgerBookId,
        name: '储蓄卡',
        type: AccountType.debitCard,
        groupId: null,
        initialBalance: 1000,
        iconCode: 'card',
        note: '备注',
        includeInAssets: false,
        hidden: true,
        cardLast4: '8888',
      ),
    ];
    await repo.saveAccounts(accounts);
    final loadedAccounts = await repo.loadAccounts();
    expect(loadedAccounts.map((a) => a.id).toList(), <String>[
      'alipay',
      'card',
    ]);
    expect(loadedAccounts[1].hidden, isTrue);
    expect(loadedAccounts[1].includeInAssets, isFalse);
    expect(loadedAccounts[1].cardLast4, '8888');
    expect(loadedAccounts[1].groupId, isNull);

    final groups = <AccountGroup>[
      const AccountGroup(
        id: 'daily',
        bookId: defaultLedgerBookId,
        name: '日常',
        sortOrder: 0,
      ),
    ];
    await repo.saveAccountGroups(groups);
    expect((await repo.loadAccountGroups()).single.name, '日常');

    final categories = <Category>[
      const Category(
        id: 'dining',
        label: '餐饮',
        type: EntryType.expense,
        iconCode: 'food',
      ),
      const Category(
        id: 'coffee',
        label: '咖啡',
        type: EntryType.expense,
        iconCode: 'food',
        parentId: 'dining',
      ),
      const Category(
        id: 'salary',
        label: '工资',
        type: EntryType.income,
        iconCode: 'wallet',
      ),
    ];
    await repo.saveCategories(categories);
    final loadedCategories = await repo.loadCategories();
    expect(loadedCategories.map((c) => c.id).toList(), <String>[
      'dining',
      'coffee',
      'salary',
    ]);
    expect(loadedCategories[2].type, EntryType.income);
    // 多级分类的 parentId 应完整往返（顶级为 null，子分类指向父级）。
    expect(loadedCategories[0].parentId, isNull);
    expect(loadedCategories[1].parentId, 'dining');
  });

  test('v1 数据库升级到 v2 后 categories 具备 parent_id 列', () async {
    // 以旧版 v1 schema 建库（无 parent_id 列）并写入一条分类。
    final dir = await Directory.systemTemp.createTemp('verifin_mig');
    final path = '${dir.path}/mig.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              label TEXT NOT NULL,
              type TEXT NOT NULL,
              icon_code TEXT NOT NULL,
              sort_order INTEGER NOT NULL
            )
          ''');
          // 真实 v1 库总有 entries 表；后续 v3 迁移会 ALTER 它加 tag_ids。
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
              amount REAL NOT NULL, category_id TEXT NOT NULL,
              account_id TEXT NOT NULL, to_account_id TEXT, note TEXT NOT NULL,
              occurred_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    await v1.insert('categories', <String, Object?>{
      'id': 'dining',
      'label': '餐饮',
      'type': 'expense',
      'icon_code': 'food',
      'sort_order': 0,
    });
    await v1.close();

    // 通过 AppDatabase.open（当前 schemaVersion）触发 _onUpgrade 迁移。
    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final repo = SqliteLedgerRepository(db);
    final migrated = await repo.loadCategories();
    expect(migrated.single.id, 'dining');
    expect(migrated.single.parentId, isNull);

    // 迁移后可写入子分类并读回。
    await repo.saveCategories(<Category>[
      ...migrated,
      const Category(
        id: 'coffee',
        label: '咖啡',
        type: EntryType.expense,
        iconCode: 'food',
        parentId: 'dining',
      ),
    ]);
    final withChild = await repo.loadCategories();
    expect(withChild.map((c) => c.parentId).toList(), <String?>[
      null,
      'dining',
    ]);

    await db.close();
    await dir.delete(recursive: true);
  });

  test('交易标签 tag_ids 与 tags 表往返', () async {
    final repo = await openRepo();
    await repo.saveTags(<Tag>[
      const Tag(id: 'tag_food', label: '外食'),
      const Tag(id: 'tag_work', label: '工作'),
    ]);
    expect((await repo.loadTags()).map((t) => t.id).toList(), <String>[
      'tag_food',
      'tag_work',
    ]);

    final entry = LedgerEntry(
      id: 'e-tagged',
      bookId: defaultLedgerBookId,
      type: EntryType.expense,
      amount: 20,
      categoryId: 'dining',
      accountId: 'cash',
      note: '',
      occurredAt: DateTime(2026, 7, 4),
      tagIds: const <String>['tag_food', 'tag_work'],
    );
    final plain = entry.copyWith(id: 'e-plain', tagIds: const <String>[]);
    await repo.saveEntries(<LedgerEntry>[entry, plain]);
    final loaded = await repo.loadEntries();
    final tagged = loaded.firstWhere((e) => e.id == 'e-tagged');
    final untagged = loaded.firstWhere((e) => e.id == 'e-plain');
    expect(tagged.tagIds, <String>['tag_food', 'tag_work']);
    expect(untagged.tagIds, isEmpty);
  });

  test('信用卡账单日/还款日往返，v7→v8 迁移旧账户默认 null', () async {
    final repo = await openRepo();
    await repo.saveAccounts(<Account>[
      const Account(
        id: 'credit',
        bookId: defaultLedgerBookId,
        name: '信用卡',
        type: AccountType.creditCard,
        groupId: null,
        initialBalance: 0,
        iconCode: 'card',
        note: '',
        includeInAssets: true,
        hidden: false,
        statementDay: 5,
        dueDay: 25,
      ),
    ]);
    final loaded = await repo.loadAccounts().then((v) => v.single);
    expect(loaded.statementDay, 5);
    expect(loaded.dueDay, 25);

    // v7 库（accounts 无 statement_day/due_day）升级后旧账户为 null。
    final dir = await Directory.systemTemp.createTemp('verifin_mig8');
    final path = '${dir.path}/mig8.db';
    final v7 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
        },
      ),
    );
    await v7.insert('accounts', <String, Object?>{
      'id': 'a',
      'book_id': 'default',
      'name': '旧卡',
      'type': 'creditCard',
      'group_id': null,
      'initial_balance': 0,
      'icon_code': 'card',
      'note': '',
      'include_in_assets': 1,
      'hidden': 0,
      'card_last4': '',
      'sort_order': 0,
    });
    await v7.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final migrated = await SqliteLedgerRepository(db).loadAccounts();
    expect(migrated.single.statementDay, isNull);
    expect(migrated.single.dueDay, isNull);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('周期记账规则 recurring_rules 表往返', () async {
    final repo = await openRepo();
    await repo.saveRecurringRules(<RecurringRule>[
      RecurringRule(
        id: 'r1',
        bookId: defaultLedgerBookId,
        type: EntryType.expense,
        amount: 1500,
        categoryId: 'housing',
        accountId: 'cash',
        note: '房租',
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 5),
        nextRunDate: DateTime(2026, 8, 5),
      ),
    ]);
    final loaded = await repo.loadRecurringRules();
    expect(loaded.single.note, '房租');
    expect(loaded.single.frequency, RecurringFrequency.monthly);
    expect(loaded.single.nextRunDate, DateTime(2026, 8, 5));
  });

  test('v6 数据库升级到 v7 后有 recurring_rules 表', () async {
    final dir = await Directory.systemTemp.createTemp('verifin_mig7');
    final path = '${dir.path}/mig7.db';
    final v6 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
          // 一张占位表即可，迁移只新增 recurring_rules。
          await db.execute('CREATE TABLE placeholder (id TEXT PRIMARY KEY)');
        },
      ),
    );
    await v6.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final repo = SqliteLedgerRepository(db);
    expect(await repo.loadRecurringRules(), isEmpty);

    await db.close();
    await dir.delete(recursive: true);
  });

  test('转账手续费 fee 列往返', () async {
    final repo = await openRepo();
    final entry = LedgerEntry(
      id: 't1',
      bookId: defaultLedgerBookId,
      type: EntryType.transfer,
      amount: 100,
      categoryId: 'transfer_out',
      accountId: 'a',
      toAccountId: 'b',
      note: '',
      occurredAt: DateTime(2026, 7, 4),
      fee: 2.5,
    );
    await repo.saveEntries(<LedgerEntry>[entry]);
    expect((await repo.loadEntries()).single.fee, 2.5);
  });

  test('v4 数据库升级到 v5 后 entries 有 fee 列（旧行默认 0）', () async {
    final dir = await Directory.systemTemp.createTemp('verifin_mig5');
    final path = '${dir.path}/mig5.db';
    final v4 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
              amount REAL NOT NULL, category_id TEXT NOT NULL,
              account_id TEXT NOT NULL, to_account_id TEXT, note TEXT NOT NULL,
              occurred_at INTEGER NOT NULL, tag_ids TEXT
            )
          ''');
        },
      ),
    );
    await v4.insert('entries', <String, Object?>{
      'id': 'old',
      'book_id': 'default',
      'type': 'transfer',
      'amount': 50,
      'category_id': 'transfer_out',
      'account_id': 'a',
      'note': '',
      'occurred_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    await v4.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final repo = SqliteLedgerRepository(db);
    expect((await repo.loadEntries()).single.fee, 0);

    await db.close();
    await dir.delete(recursive: true);
  });

  test('图片附件 attachments 表往返', () async {
    final repo = await openRepo();
    await repo.saveAttachments(<Attachment>[
      const Attachment(
        id: 'att1',
        entryId: 'e1',
        dataUrl: 'data:image/jpeg;base64,AAAA',
      ),
      const Attachment(
        id: 'att2',
        entryId: 'e1',
        dataUrl: 'data:image/jpeg;base64,BBBB',
      ),
    ]);
    final loaded = await repo.loadAttachments();
    expect(loaded.map((a) => a.id).toList(), <String>['att1', 'att2']);
    expect(loaded.first.entryId, 'e1');
    expect(loaded.last.dataUrl, 'data:image/jpeg;base64,BBBB');
  });

  test('v3 数据库升级到 v4 后有 attachments 表', () async {
    final dir = await Directory.systemTemp.createTemp('verifin_mig4');
    final path = '${dir.path}/mig4.db';
    // v3 库：有 entries(含 tag_ids) 与 tags，但没有 attachments 表。
    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
              amount REAL NOT NULL, category_id TEXT NOT NULL,
              account_id TEXT NOT NULL, to_account_id TEXT, note TEXT NOT NULL,
              occurred_at INTEGER NOT NULL, tag_ids TEXT
            )
          ''');
          await db.execute(
            'CREATE TABLE tags (id TEXT PRIMARY KEY, label TEXT NOT NULL, sort_order INTEGER NOT NULL)',
          );
        },
      ),
    );
    await v3.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final repo = SqliteLedgerRepository(db);
    expect(await repo.loadAttachments(), isEmpty);
    await repo.saveAttachments(<Attachment>[
      const Attachment(
        id: 'a',
        entryId: 'e',
        dataUrl: 'data:image/jpeg;base64,X',
      ),
    ]);
    expect((await repo.loadAttachments()).single.id, 'a');

    await db.close();
    await dir.delete(recursive: true);
  });

  test('v2 数据库升级到 v3 后有 tags 表与 entries.tag_ids', () async {
    final dir = await Directory.systemTemp.createTemp('verifin_mig3');
    final path = '${dir.path}/mig3.db';
    // 建一个 v2 库（entries 无 tag_ids、无 tags 表）。
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(_legacyAccountsTable);
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
              amount REAL NOT NULL, category_id TEXT NOT NULL,
              account_id TEXT NOT NULL, to_account_id TEXT, note TEXT NOT NULL,
              occurred_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    await v2.insert('entries', <String, Object?>{
      'id': 'old',
      'book_id': 'default',
      'type': 'expense',
      'amount': 5,
      'category_id': 'dining',
      'account_id': 'cash',
      'note': '',
      'occurred_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    await v2.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final repo = SqliteLedgerRepository(db);
    final migrated = await repo.loadEntries();
    expect(migrated.single.id, 'old');
    expect(migrated.single.tagIds, isEmpty);
    // tags 表存在且可写。
    await repo.saveTags(<Tag>[const Tag(id: 't1', label: '标签')]);
    expect((await repo.loadTags()).single.label, '标签');

    await db.close();
    await dir.delete(recursive: true);
  });

  test('v9 数据库升级到 v10 合并重复同名分类并建唯一索引', () async {
    final dir = await Directory.systemTemp.createTemp('verifin_mig10');
    final path = '${dir.path}/mig10.db';
    // 建一个 v9 库：两个同名同类型顶级「餐饮」+ 各自被交易引用（模拟幽灵重复分类）。
    final v9 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY, label TEXT NOT NULL, type TEXT NOT NULL,
              icon_code TEXT NOT NULL, sort_order INTEGER NOT NULL,
              parent_id TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY, category_id TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await v9.insert('categories', <String, Object?>{
      'id': 'dining1',
      'label': '餐饮',
      'type': 'expense',
      'icon_code': 'restaurant',
      'sort_order': 0,
    });
    await v9.insert('categories', <String, Object?>{
      'id': 'dining2',
      'label': '餐饮',
      'type': 'expense',
      'icon_code': 'restaurant',
      'sort_order': 1,
    });
    await v9.insert('entries', <String, Object?>{
      'id': 'e1',
      'category_id': 'dining1',
    });
    await v9.insert('entries', <String, Object?>{
      'id': 'e2',
      'category_id': 'dining2',
    });
    await v9.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    // 重复「餐饮」已合并为一条。
    final cats = await db.db.rawQuery(
      "SELECT id FROM categories WHERE label='餐饮' AND type='expense'",
    );
    expect(cats, hasLength(1));
    final keptId = cats.single['id'] as String;
    // 两条交易都改指向保留者。
    final entries = await db.db.rawQuery('SELECT category_id FROM entries');
    expect(entries.every((r) => r['category_id'] == keptId), isTrue);
    // 唯一索引已建立。
    final index = await db.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' "
      "AND name='idx_categories_unique'",
    );
    expect(index, hasLength(1));

    await db.close();
    await dir.delete(recursive: true);
  });

  test('预算键值映射保存读回', () async {
    final repo = await openRepo();
    await repo.saveMonthlyBudgets(<String, double>{'default:2026-01': 800});
    await repo.saveCategoryBudgets(<String, double>{
      'default:2026-01:dining': 300,
    });
    expect(await repo.loadMonthlyBudgets(), <String, double>{
      'default:2026-01': 800,
    });
    expect(await repo.loadCategoryBudgets(), <String, double>{
      'default:2026-01:dining': 300,
    });
  });
}
