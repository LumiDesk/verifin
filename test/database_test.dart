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
    expect(loadedBooks.map((b) => b.id).toList(), <String>['default', 'travel']);
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
    expect(loadedAccounts.map((a) => a.id).toList(), <String>['alipay', 'card']);
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
        id: 'salary',
        label: '工资',
        type: EntryType.income,
        iconCode: 'wallet',
      ),
    ];
    await repo.saveCategories(categories);
    final loadedCategories = await repo.loadCategories();
    expect(
      loadedCategories.map((c) => c.id).toList(),
      <String>['dining', 'salary'],
    );
    expect(loadedCategories[1].type, EntryType.income);
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
