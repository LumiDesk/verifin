import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';

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
        iconCode: 'folder',
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
