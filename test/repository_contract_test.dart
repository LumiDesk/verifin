import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/data/app_database.dart';
import 'package:verifin/data/ledger_repository.dart';

import 'support/in_memory_ledger_repository.dart';

/// 仓储契约测试：同一组行为断言对 InMemory 与 SQLite 两个实现各跑一遍，
/// 保证「widget 测试注入的内存实现」与「生产的 SQLite 实现」不会悄悄分叉
/// （分叉的后果是测试全绿、真机行为不同）。
///
/// 契约内容 = [LedgerRepository] 接口的语义承诺：saveX 落库后该表内容 ==
/// 传入列表；replaceAllLedgerData 多表整替且不破坏后续 saveX 的正确性。
/// 实现自由（差分还是整表覆盖）不在契约内，不作断言。
///
/// 约定内的前提（两实现都依赖、由 controller 保证）：entries 传入时已按
/// occurred_at 倒序；categories 无 (label,type,parentId) 重复。
void main() {
  setUpAll(sqfliteFfiInit);

  final opened = <AppDatabase>[];
  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
  });

  _runContract('InMemoryLedgerRepository', () async {
    return InMemoryLedgerRepository();
  });

  _runContract('SqliteLedgerRepository', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    opened.add(db);
    return SqliteLedgerRepository(db);
  });
}

LedgerEntry _entry(String id, DateTime occurredAt, {String note = ''}) {
  return LedgerEntry(
    id: id,
    bookId: 'default',
    type: EntryType.expense,
    amount: 10,
    categoryId: 'cat-1',
    accountId: 'acc-1',
    note: note,
    occurredAt: occurredAt,
  );
}

List<Map<String, Object?>> _jsonOf(Iterable<dynamic> items) => items
    .map((item) => (item as dynamic).toJson() as Map<String, Object?>)
    .toList();

void _runContract(String name, Future<LedgerRepository> Function() openRepo) {
  group('仓储契约 · $name', () {
    test('新库为空且 hasAnyData=false', () async {
      final repo = await openRepo();
      expect(await repo.hasAnyData(), isFalse);
      expect(await repo.loadEntries(), isEmpty);
      expect(await repo.loadBooks(), isEmpty);
      expect(await repo.loadAccounts(), isEmpty);
      expect(await repo.loadAccountGroups(), isEmpty);
      expect(await repo.loadCategories(), isEmpty);
      expect(await repo.loadTags(), isEmpty);
      expect(await repo.loadAttachments(), isEmpty);
      expect(await repo.loadRecurringRules(), isEmpty);
      expect(await repo.loadMonthlyBudgets(), isEmpty);
      expect(await repo.loadCategoryBudgets(), isEmpty);
      expect(await repo.loadDailyBudgets(), isEmpty);
    });

    test('各表 save 后 load 内容与顺序原样读回', () async {
      final repo = await openRepo();
      final entries = <LedgerEntry>[
        _entry('e2', DateTime(2026, 2, 1, 9), note: '较新'),
        _entry('e1', DateTime(2026, 1, 1, 8), note: '较旧'),
      ];
      final books = <LedgerBook>[
        LedgerBook(
          id: 'default',
          name: '日常账本',
          createdAt: DateTime(2026, 1, 1),
          isDefault: true,
        ),
        LedgerBook(
          id: 'travel',
          name: '旅行账本',
          createdAt: DateTime(2026, 2, 1),
          isDefault: false,
        ),
      ];
      const accounts = <Account>[
        Account(
          id: 'acc-1',
          bookId: 'default',
          name: '现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      ];
      const groups = <AccountGroup>[
        AccountGroup(
          id: 'grp-1',
          bookId: 'default',
          name: '资金',
          iconCode: 'wallet',
          sortOrder: 0,
        ),
      ];
      const categories = <Category>[
        Category(
          id: 'cat-1',
          label: '餐饮',
          type: EntryType.expense,
          iconCode: 'dining',
        ),
        Category(
          id: 'cat-2',
          label: '早餐',
          type: EntryType.expense,
          iconCode: 'dining',
          parentId: 'cat-1',
        ),
      ];
      const tags = <Tag>[Tag(id: 'tag-1', label: '出差')];
      const attachments = <Attachment>[
        Attachment(
          id: 'att-1',
          entryId: 'e1',
          dataUrl: 'data:image/jpeg;base64,QUJD',
        ),
      ];
      final rules = <RecurringRule>[
        RecurringRule(
          id: 'rule-1',
          bookId: 'default',
          type: EntryType.expense,
          amount: 30,
          categoryId: 'cat-1',
          accountId: 'acc-1',
          note: '房租',
          frequency: RecurringFrequency.monthly,
          startDate: DateTime(2026, 1, 1),
          nextRunDate: DateTime(2026, 2, 1),
        ),
      ];

      await repo.saveEntries(entries);
      await repo.saveBooks(books);
      await repo.saveAccounts(accounts);
      await repo.saveAccountGroups(groups);
      await repo.saveCategories(categories);
      await repo.saveTags(tags);
      await repo.saveAttachments(attachments);
      await repo.saveRecurringRules(rules);

      expect(_jsonOf(await repo.loadEntries()), _jsonOf(entries));
      expect(_jsonOf(await repo.loadBooks()), _jsonOf(books));
      expect(_jsonOf(await repo.loadAccounts()), _jsonOf(accounts));
      expect(_jsonOf(await repo.loadAccountGroups()), _jsonOf(groups));
      expect(_jsonOf(await repo.loadCategories()), _jsonOf(categories));
      expect(_jsonOf(await repo.loadTags()), _jsonOf(tags));
      expect(_jsonOf(await repo.loadAttachments()), _jsonOf(attachments));
      expect(_jsonOf(await repo.loadRecurringRules()), _jsonOf(rules));
      expect(await repo.hasAnyData(), isTrue);
    });

    test('save 是整表覆盖语义：后一次保存完全取代前一次', () async {
      final repo = await openRepo();
      await repo.saveEntries(<LedgerEntry>[
        _entry('a', DateTime(2026, 3, 2)),
        _entry('b', DateTime(2026, 3, 1)),
      ]);
      await repo.saveEntries(<LedgerEntry>[_entry('c', DateTime(2026, 3, 3))]);
      expect((await repo.loadEntries()).map((e) => e.id).toList(), <String>[
        'c',
      ]);

      await repo.saveTags(const <Tag>[Tag(id: 't1', label: '一')]);
      await repo.saveTags(const <Tag>[Tag(id: 't2', label: '二')]);
      expect((await repo.loadTags()).map((t) => t.id).toList(), <String>['t2']);
    });

    test('已载入基线后的增删改保存，load 反映最新内容', () async {
      final repo = await openRepo();
      await repo.saveEntries(<LedgerEntry>[
        _entry('e2', DateTime(2026, 2, 1), note: '原注'),
        _entry('e1', DateTime(2026, 1, 1)),
      ]);
      // 载入建立基线（SQLite 实现以此为差分起点；契约只关心后续语义不变）。
      await repo.loadEntries();
      await repo.saveEntries(<LedgerEntry>[
        _entry('e3', DateTime(2026, 3, 1), note: '新增'),
        _entry('e2', DateTime(2026, 2, 1), note: '改注'),
        // e1 删除
      ]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.id).toList(), <String>['e3', 'e2']);
      expect(loaded.last.note, '改注');
    });

    test('预算键值对保存读回与整体覆盖', () async {
      final repo = await openRepo();
      await repo.saveMonthlyBudgets(<String, double>{'default:2026-01': 3000});
      await repo.saveCategoryBudgets(<String, double>{'default:cat-1': 500});
      await repo.saveDailyBudgets(<String, double>{'default': 100});
      expect(await repo.loadMonthlyBudgets(), {'default:2026-01': 3000.0});
      expect(await repo.loadCategoryBudgets(), {'default:cat-1': 500.0});
      expect(await repo.loadDailyBudgets(), {'default': 100.0});

      await repo.saveMonthlyBudgets(<String, double>{'default:2026-02': 3500});
      expect(await repo.loadMonthlyBudgets(), {'default:2026-02': 3500.0});
    });

    test('仅有预算数据时 hasAnyData 仍为 false', () async {
      final repo = await openRepo();
      await repo.saveMonthlyBudgets(<String, double>{'default:2026-01': 1});
      expect(await repo.hasAnyData(), isFalse);
    });

    test('replaceAllLedgerData 整替后 load 反映快照，且后续 saveX 语义不受影响', () async {
      final repo = await openRepo();
      // 旧数据 + 载入建立基线，模拟「用过一段时间再导入备份」。
      await repo.saveEntries(<LedgerEntry>[
        _entry('old', DateTime(2025, 1, 1)),
      ]);
      await repo.saveTags(const <Tag>[Tag(id: 'old-tag', label: '旧')]);
      await repo.loadEntries();
      await repo.loadTags();

      final snapshot = LedgerDataSnapshot(
        books: <LedgerBook>[
          LedgerBook(
            id: 'default',
            name: '恢复账本',
            createdAt: DateTime(2026, 1, 1),
            isDefault: true,
          ),
        ],
        accounts: const <Account>[],
        accountGroups: const <AccountGroup>[],
        categories: const <Category>[
          Category(
            id: 'cat-1',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'dining',
          ),
        ],
        tags: const <Tag>[Tag(id: 'new-tag', label: '新')],
        attachments: const <Attachment>[],
        entries: <LedgerEntry>[
          _entry('n2', DateTime(2026, 2, 1)),
          _entry('n1', DateTime(2026, 1, 1)),
        ],
        recurringRules: const <RecurringRule>[],
        monthlyBudgets: const <String, double>{'default:2026-01': 800},
        categoryBudgets: const <String, double>{},
        dailyBudgets: const <String, double>{},
      );
      await repo.replaceAllLedgerData(snapshot);

      expect((await repo.loadEntries()).map((e) => e.id).toList(), <String>[
        'n2',
        'n1',
      ]);
      expect((await repo.loadTags()).single.id, 'new-tag');
      expect((await repo.loadBooks()).single.name, '恢复账本');
      expect(await repo.loadMonthlyBudgets(), {'default:2026-01': 800.0});

      // 整替后再做单表保存：内容必须精确等于传入列表——锁住「整替后差分基线
      // 未重建、拿导入前旧快照去 diff 导致误删/漏写」这类回归。
      await repo.saveEntries(<LedgerEntry>[
        _entry('n3', DateTime(2026, 3, 1), note: '整替后新增'),
        _entry('n2', DateTime(2026, 2, 1), note: '整替后改动'),
        // n1 删除
      ]);
      final after = await repo.loadEntries();
      expect(after.map((e) => e.id).toList(), <String>['n3', 'n2']);
      expect(after.first.note, '整替后新增');
      expect(after.last.note, '整替后改动');
    });
  });
}
