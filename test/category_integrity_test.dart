// 「幽灵同名分类」相关的回归测试：覆盖显示层止血（悬空/孤儿分类不再冒名成同名分类）、
// 聚合下钻取数、以及控制器载入 / 导入时的一次性分类参照完整性自愈。
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/category_tree.dart';
import 'package:verifin/app/model_lookup.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/report_analysis.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/in_memory_ledger_repository.dart';

LedgerEntry _expense(String id, String categoryId, double amount) =>
    LedgerEntry(
      id: id,
      bookId: defaultLedgerBookId,
      type: EntryType.expense,
      amount: amount,
      categoryId: categoryId,
      accountId: 'cash',
      note: '',
      occurredAt: DateTime(2026, 7, 1),
    );

Future<VeriFinController> _controllerWith({
  required List<Category> categories,
  required List<LedgerEntry> entries,
  List<RecurringRule> recurringRules = const <RecurringRule>[],
}) async {
  final store = LocalKeyValueStore();
  store.write('verifin.privacy_consent.v1', 'true');
  store.write('verifin.onboarding.v1', 'true');
  store.write('verifin.locale.v1', 'zh');
  final repo = InMemoryLedgerRepository();
  await repo.saveBooks(<LedgerBook>[
    LedgerBook(
      id: defaultLedgerBookId,
      name: '日常账本',
      createdAt: DateTime(2026, 1, 1),
      isDefault: true,
    ),
  ]);
  await repo.saveAccounts(<Account>[
    const Account(
      id: 'cash',
      bookId: defaultLedgerBookId,
      name: '现金',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    ),
  ]);
  await repo.saveCategories(categories);
  await repo.saveEntries(entries);
  await repo.saveRecurringRules(recurringRules);
  return VeriFinController.create(store, repository: repo);
}

void main() {
  group('category_tree 对孤儿 / 悬空分类的收口', () {
    test('parentId 指向不存在的父分类（孤儿）→ 视为自身顶级，不返回幽灵祖先', () {
      final categories = <Category>[
        const Category(
          id: 'orphan',
          label: '餐饮',
          type: EntryType.expense,
          iconCode: 'category',
          parentId: 'gone', // 指向已不存在的父分类
        ),
      ];
      expect(ancestorIds(categories, 'orphan'), isEmpty);
      expect(rootIdOf(categories, 'orphan'), 'orphan');
    });

    test('交易引用的分类本身不存在（悬空引用）→ rootId 为该 id 自身', () {
      expect(rootIdOf(const <Category>[], 'ghost'), 'ghost');
    });

    test('normalizedCategoryLabel 容忍大小写 / 首尾空白 / 全半角', () {
      expect(normalizedCategoryLabel(' 餐饮 '), normalizedCategoryLabel('餐饮'));
      expect(normalizedCategoryLabel('ABC'), normalizedCategoryLabel('abc'));
      expect(normalizedCategoryLabel('ＡＢＣ'), normalizedCategoryLabel('abc'));
      expect(normalizedCategoryLabel('餐饮　'), normalizedCategoryLabel('餐饮'));
    });
  });

  group('分类排行显示层止血', () {
    final categories = <Category>[
      const Category(
        id: 'dining',
        label: '餐饮',
        type: EntryType.expense,
        iconCode: 'restaurant',
      ),
    ];
    // 一半交易挂在真「餐饮」，一半挂在一个查不到分类的悬空 id。
    final entries = <LedgerEntry>[
      _expense('a', 'dining', 10),
      _expense('b', 'dining', 20),
      _expense('c', 'ghost_dining', 30),
      _expense('d', 'ghost_dining', 40),
    ];

    test('悬空引用不再冒名成第二个「餐饮」，而是归为「已删除分类」占位', () {
      final stats = reportCategoryStats(entries, categories, EntryType.expense);
      final dining = stats.where((s) => s.category.label == '餐饮').toList();
      expect(dining, hasLength(1));
      expect(dining.single.categoryId, 'dining');
      expect(dining.single.amount, 30);

      final ghost = stats.where((s) => s.categoryId == 'ghost_dining').toList();
      expect(ghost, hasLength(1));
      expect(ghost.single.category.label, isNot('餐饮'));
      expect(ghost.single.amount, 70);
    });

    test('下钻按聚合原始 key 取数，两个统计行各自 scope 到正确的交易', () {
      final diningChildren = reportCategoryChildStats(
        entries,
        categories,
        'dining',
        EntryType.expense,
      );
      expect(diningChildren.fold<double>(0, (sum, s) => sum + s.amount), 30);

      final ghostChildren = reportCategoryChildStats(
        entries,
        categories,
        'ghost_dining',
        EntryType.expense,
      );
      expect(ghostChildren.fold<double>(0, (sum, s) => sum + s.amount), 70);
    });

    test('categoryByIdFrom 对未知 id 返回占位而非列表首个分类', () {
      final resolved = categoryByIdFrom(categories, 'ghost_dining');
      expect(resolved.label, isNot('餐饮'));
      expect(resolved.id, 'ghost_dining');
    });
  });

  group('控制器载入时的分类参照完整性自愈', () {
    test('孤儿 parentId 重挂为顶级', () async {
      final controller = await _controllerWith(
        categories: <Category>[
          const Category(
            id: 'orphan',
            label: '零食',
            type: EntryType.expense,
            iconCode: 'category',
            parentId: 'gone',
          ),
        ],
        entries: <LedgerEntry>[_expense('a', 'orphan', 5)],
      );
      final orphan = controller.categories.firstWhere((c) => c.id == 'orphan');
      expect(orphan.parentId, isNull);
    });

    test('重复同名分类合并，交易引用改指向保留者', () async {
      final controller = await _controllerWith(
        categories: <Category>[
          const Category(
            id: 'dining1',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'restaurant',
          ),
          const Category(
            id: 'dining2',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'restaurant',
          ),
        ],
        entries: <LedgerEntry>[
          _expense('a', 'dining1', 10),
          _expense('b', 'dining2', 20),
        ],
      );
      final dining = controller.categories
          .where((c) => c.label == '餐饮' && c.type == EntryType.expense)
          .toList();
      expect(dining, hasLength(1), reason: '两个同名「餐饮」应合并为一个');
      final keptId = dining.single.id;
      expect(
        controller.entries.every((e) => e.categoryId == keptId),
        isTrue,
        reason: '两条交易都应指向保留下来的分类',
      );
    });

    test('悬空交易引用归入「未分类」，且不再有交易指向不存在的分类', () async {
      final controller = await _controllerWith(
        categories: <Category>[
          const Category(
            id: 'dining',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'restaurant',
          ),
        ],
        entries: <LedgerEntry>[
          _expense('a', 'dining', 10),
          _expense('b', 'ghost', 20),
        ],
      );
      final ids = controller.categories.map((c) => c.id).toSet();
      expect(
        controller.entries.every((e) => ids.contains(e.categoryId)),
        isTrue,
        reason: '自愈后不应再有指向不存在分类的交易',
      );
      final moved = controller.entries.firstWhere((e) => e.id == 'b');
      final target = controller.categories.firstWhere(
        (c) => c.id == moved.categoryId,
      );
      expect(target.label, '未分类');
    });

    test('数据本就干净时自愈不改动（幂等）', () async {
      final controller = await _controllerWith(
        categories: <Category>[
          const Category(
            id: 'dining',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'restaurant',
          ),
        ],
        entries: <LedgerEntry>[_expense('a', 'dining', 10)],
      );
      expect(controller.categories.map((c) => c.id), contains('dining'));
      expect(
        controller.categories.any((c) => c.label == '未分类'),
        isFalse,
        reason: '没有悬空引用就不该凭空创建「未分类」',
      );
    });
  });

  group('创建分类的查重防再生', () {
    test('addCategory 不重复创建同一父级下的同名同类型分类', () async {
      final controller = await _controllerWith(
        categories: <Category>[
          const Category(
            id: 'dining',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'restaurant',
          ),
        ],
        entries: const <LedgerEntry>[],
      );
      final before = controller.categories
          .where((c) => c.label == '餐饮' && c.type == EntryType.expense)
          .length;
      // 近似同名（首尾空格）也应被判为重复而不新建。
      controller.addCategory(
        type: EntryType.expense,
        label: ' 餐饮 ',
        iconCode: 'restaurant',
      );
      final after = controller.categories
          .where(
            (c) =>
                normalizedCategoryLabel(c.label) == '餐饮' &&
                c.type == EntryType.expense,
          )
          .length;
      expect(after, before);
    });
  });
}
