import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/import/plan_builder.dart';
import 'package:verifin/app/backup/import/raw_import.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';

/// 固定时钟：plan_builder 的 id 由 now 派生，固定它保证断言可复现。
final DateTime _now = DateTime(2026, 7, 12, 12);
const String _bookId = 'book_test';

ImportPlan _build({
  List<RawImportRecord> records = const <RawImportRecord>[],
  List<ImportRowError> errors = const <ImportRowError>[],
  List<RawImportAccount> accounts = const <RawImportAccount>[],
  List<Account> existingAccounts = const <Account>[],
  List<Category> existingCategories = const <Category>[],
  List<Tag> existingTags = const <Tag>[],
}) {
  return buildImportPlanFromRecords(
    parsed: ParsedImport(records: records, errors: errors, accounts: accounts),
    bookId: _bookId,
    existingAccounts: existingAccounts,
    existingCategories: existingCategories,
    existingTags: existingTags,
    now: _now,
  );
}

RawImportRecord _record({
  DateTime? date,
  EntryType type = EntryType.expense,
  double amount = 10,
  String category = '',
  String subCategory = '',
  String account = '',
  String toAccount = '',
  String note = '',
  double fee = 0,
  double refunded = 0,
  List<String> tags = const <String>[],
  int? sourceLine,
}) {
  return RawImportRecord(
    date: date ?? DateTime(2026, 7, 1, 9, 30),
    type: type,
    amount: amount,
    category: category,
    subCategory: subCategory,
    account: account,
    toAccount: toAccount,
    note: note,
    fee: fee,
    refunded: refunded,
    tags: tags,
    sourceLine: sourceLine,
  );
}

Account _account(String id, String name) => Account(
  id: id,
  bookId: _bookId,
  name: name,
  type: AccountType.cash,
  groupId: null,
  initialBalance: 0,
  iconCode: 'wallet',
  note: '',
  includeInAssets: true,
  hidden: false,
);

Category _category(
  String id,
  String label, {
  EntryType type = EntryType.expense,
  String? parentId,
}) => Category(
  id: id,
  label: label,
  type: type,
  iconCode: 'category',
  parentId: parentId,
);

void main() {
  group('账户解析：按名新建与复用', () {
    test('账户名未匹配现有账户时新建（挂当前账本、默认现金类型），字段透传', () {
      final at = DateTime(2026, 7, 2, 18, 30);
      final plan = _build(
        records: <RawImportRecord>[
          _record(account: '现金', amount: 23.5, note: '午饭', date: at),
        ],
      );
      expect(plan.errors, isEmpty);
      final account = plan.newAccounts.single;
      expect(account.name, '现金');
      expect(account.bookId, _bookId);
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, 0);
      final entry = plan.entries.single;
      expect(entry.accountId, account.id);
      expect(entry.bookId, _bookId);
      expect(entry.type, EntryType.expense);
      expect(entry.amount, 23.5);
      expect(entry.note, '午饭');
      expect(entry.occurredAt, at);
    });

    test('同名账户跨行只新建一次', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(account: '现金'),
          _record(account: '现金', type: EntryType.income, amount: 5),
        ],
      );
      expect(plan.newAccounts, hasLength(1));
      expect(plan.entries.map((e) => e.accountId).toSet(), <String>{
        plan.newAccounts.single.id,
      });
    });

    test('现有账户按名复用、不再新建', () {
      final plan = _build(
        existingAccounts: <Account>[_account('acct_cash', '现金')],
        records: <RawImportRecord>[_record(account: '现金')],
      );
      expect(plan.newAccounts, isEmpty);
      expect(plan.entries.single.accountId, 'acct_cash');
    });

    test('账户名为空记为无账户（accountId 空串、不新建）', () {
      final plan = _build(records: <RawImportRecord>[_record()]);
      expect(plan.newAccounts, isEmpty);
      expect(plan.entries.single.accountId, isEmpty);
    });
  });

  group('分类层级解析（resolveCategoryHierarchy）', () {
    test('一级+二级：子分类挂 parentId、类型一致，交易引用子分类', () {
      final plan = _build(
        records: <RawImportRecord>[_record(category: '餐饮', subCategory: '午餐')],
      );
      expect(plan.newCategories, hasLength(2));
      final parent = plan.newCategories.firstWhere((c) => c.label == '餐饮');
      final child = plan.newCategories.firstWhere((c) => c.label == '午餐');
      expect(parent.parentId, isNull);
      expect(child.parentId, parent.id);
      expect(parent.type, EntryType.expense);
      expect(child.type, EntryType.expense);
      expect(plan.entries.single.categoryId, child.id);
    });

    test('只有一级或只有二级都按顶级分类处理', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(category: '餐饮'),
          _record(subCategory: '零食'),
        ],
      );
      expect(plan.newCategories, hasLength(2));
      expect(plan.newCategories.map((c) => c.parentId), everyElement(isNull));
      expect(plan.newCategories.map((c) => c.label).toSet(), <String>{
        '餐饮',
        '零食',
      });
    });

    test('同名分类跨行去重、复用同一 id', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(category: '餐饮', subCategory: '午餐'),
          _record(category: '餐饮', subCategory: '午餐'),
          _record(category: '餐饮'),
        ],
      );
      expect(plan.newCategories, hasLength(2)); // 餐饮 + 午餐。
      final parent = plan.newCategories.firstWhere((c) => c.label == '餐饮');
      final child = plan.newCategories.firstWhere((c) => c.label == '午餐');
      expect(plan.entries[0].categoryId, child.id);
      expect(plan.entries[1].categoryId, child.id);
      expect(plan.entries[2].categoryId, parent.id);
    });

    test('顶级与子级同名互不合并；不同父级下的同名子分类各自独立', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(category: '其他'),
          _record(category: '餐饮', subCategory: '其他'),
          _record(category: '交通', subCategory: '其他'),
        ],
      );
      // 其他(顶级) + 餐饮 + 其他(餐饮下) + 交通 + 其他(交通下) = 5 个。
      expect(plan.newCategories, hasLength(5));
      final others = plan.newCategories.where((c) => c.label == '其他').toList();
      expect(others, hasLength(3));
      expect(others.map((c) => c.parentId).toSet(), hasLength(3));
      // 三笔交易引用三个不同的「其他」。
      expect(plan.entries.map((e) => e.categoryId).toSet(), hasLength(3));
    });

    test('按归一化名复用现有分类（大小写/全角/首尾空白差异）', () {
      final plan = _build(
        existingCategories: <Category>[_category('cat_food', 'Food')],
        records: <RawImportRecord>[_record(category: 'ＦＯＯＤ ')],
      );
      expect(plan.newCategories, isEmpty);
      expect(plan.entries.single.categoryId, 'cat_food');
    });

    test('子分类可挂在现有父分类下', () {
      final plan = _build(
        existingCategories: <Category>[_category('cat_food', '餐饮')],
        records: <RawImportRecord>[_record(category: '餐饮', subCategory: '午餐')],
      );
      final child = plan.newCategories.single;
      expect(child.label, '午餐');
      expect(child.parentId, 'cat_food');
      expect(plan.entries.single.categoryId, child.id);
    });

    test('同名不同收支类型的分类不合并', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(category: '其他'),
          _record(category: '其他', type: EntryType.income, amount: 5),
        ],
      );
      expect(plan.newCategories, hasLength(2));
      expect(plan.newCategories.map((c) => c.type).toSet(), <EntryType>{
        EntryType.expense,
        EntryType.income,
      });
      expect(plan.entries[0].categoryId, isNot(plan.entries[1].categoryId));
    });

    test('分类名为空时 categoryId 为空、不新建', () {
      final plan = _build(records: <RawImportRecord>[_record()]);
      expect(plan.newCategories, isEmpty);
      expect(plan.entries.single.categoryId, isEmpty);
    });
  });

  group('标签解析（resolveTags）', () {
    test('多标签全部新建并按序挂到交易', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(tags: <String>['吃饭', '午饭', '休息']),
        ],
      );
      expect(plan.newTags.map((t) => t.label).toList(), <String>[
        '吃饭',
        '午饭',
        '休息',
      ]);
      expect(
        plan.entries.single.tagIds,
        plan.newTags.map((t) => t.id).toList(),
      );
    });

    test('行内重复标签（含归一化差异）去重', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(tags: <String>['吃饭', '吃饭 ', '看剧']),
        ],
      );
      expect(plan.newTags, hasLength(2));
      expect(plan.entries.single.tagIds, hasLength(2));
    });

    test('跨行同名标签复用同一 id', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(tags: <String>['吃饭']),
          _record(tags: <String>['吃饭', '加班']),
        ],
      );
      expect(plan.newTags, hasLength(2));
      final eat = plan.newTags.firstWhere((t) => t.label == '吃饭');
      expect(plan.entries[0].tagIds, <String>[eat.id]);
      expect(plan.entries[1].tagIds.first, eat.id);
    });

    test('现有标签按归一化名复用、不新建', () {
      final plan = _build(
        existingTags: <Tag>[const Tag(id: 'tag_work', label: '工作')],
        records: <RawImportRecord>[
          _record(tags: <String>['工作 ']),
        ],
      );
      expect(plan.newTags, isEmpty);
      expect(plan.entries.single.tagIds, <String>['tag_work']);
    });

    test('空标签名跳过', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(tags: <String>['', '好']),
        ],
      );
      expect(plan.newTags, hasLength(1));
      expect(plan.entries.single.tagIds, hasLength(1));
    });
  });

  group('退款钳制（仅支出生效）', () {
    test('部分退款照实记录，净额 = 金额 − 退款', () {
      final plan = _build(
        records: <RawImportRecord>[_record(amount: 30, refunded: 10)],
      );
      final entry = plan.entries.single;
      expect(entry.refundedAmount, 10);
      expect(entry.netAmount, 20);
    });

    test('退款超过金额钳到金额（净额 0）', () {
      final plan = _build(
        records: <RawImportRecord>[_record(amount: 30, refunded: 50)],
      );
      final entry = plan.entries.single;
      expect(entry.refundedAmount, 30);
      expect(entry.netAmount, 0);
    });

    test('负数退款钳到 0', () {
      final plan = _build(
        records: <RawImportRecord>[_record(amount: 30, refunded: -5)],
      );
      expect(plan.entries.single.refundedAmount, 0);
    });

    test('收入行忽略退款列', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(type: EntryType.income, amount: 100, refunded: 10),
        ],
      );
      expect(plan.entries.single.refundedAmount, 0);
    });
  });

  group('转账记录', () {
    test('转出/转入账户 + 手续费 + 标签，分类恒为空', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(
            type: EntryType.transfer,
            amount: 500,
            account: '微信',
            toAccount: '支付宝',
            fee: 6,
            tags: <String>['互转'],
            note: '倒账',
          ),
        ],
      );
      expect(plan.errors, isEmpty);
      final entry = plan.entries.single;
      expect(entry.type, EntryType.transfer);
      expect(entry.amount, 500);
      expect(entry.fee, 6);
      expect(entry.categoryId, isEmpty);
      expect(entry.note, '倒账');
      final from = plan.newAccounts.firstWhere((a) => a.id == entry.accountId);
      final to = plan.newAccounts.firstWhere((a) => a.id == entry.toAccountId);
      expect(from.name, '微信');
      expect(to.name, '支付宝');
      final tag = plan.newTags.single;
      expect(tag.label, '互转');
      expect(entry.tagIds, <String>[tag.id]);
    });

    test('单边转账：转出为空 → accountId 空串；转入为空 → toAccountId null', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(type: EntryType.transfer, amount: 100, toAccount: '支付宝'),
          _record(type: EntryType.transfer, amount: 200, account: '微信'),
        ],
      );
      expect(plan.errors, isEmpty);
      final inbound = plan.entries[0];
      expect(inbound.accountId, isEmpty);
      expect(
        plan.newAccounts.firstWhere((a) => a.id == inbound.toAccountId).name,
        '支付宝',
      );
      final outbound = plan.entries[1];
      expect(outbound.toAccountId, isNull);
      expect(
        plan.newAccounts.firstWhere((a) => a.id == outbound.accountId).name,
        '微信',
      );
    });

    test('两端账户都为空：报错并跳过，错误行号取 sourceLine', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(type: EntryType.transfer, amount: 10, sourceLine: 7),
        ],
      );
      expect(plan.entries, isEmpty);
      final error = plan.errors.single;
      expect(error.line, 7);
      expect(error.message, '转账缺少账户');
    });

    test('转出=转入：报错、不产出交易也不新建账户；无 sourceLine 时行号为 0', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(
            type: EntryType.transfer,
            amount: 10,
            account: '现金',
            toAccount: '现金',
          ),
        ],
      );
      expect(plan.entries, isEmpty);
      expect(plan.newAccounts, isEmpty);
      final error = plan.errors.single;
      expect(error.line, 0);
      expect(error.message, '转出与转入账户不能相同');
    });

    test('手续费只在转账上生效，收支行忽略 fee', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(amount: 30, fee: 3),
          _record(type: EntryType.income, amount: 30, fee: 3),
        ],
      );
      expect(plan.entries.map((e) => e.fee), everyElement(0));
    });
  });

  group('错误透传与计数', () {
    test('parser 逐行错误透传进计划，不影响有效记录导入', () {
      final plan = _build(
        errors: <ImportRowError>[
          const ImportRowError(line: 3, message: '金额无效（应为大于 0 的数字）'),
        ],
        records: <RawImportRecord>[_record()],
      );
      expect(plan.importedCount, 1);
      expect(plan.errorCount, 1);
      expect(plan.errors.single.line, 3);
      expect(plan.errors.single.message, '金额无效（应为大于 0 的数字）');
      expect(plan.isEmpty, isFalse);
    });

    test('无交易且无错误时 isEmpty 为真', () {
      expect(_build().isEmpty, isTrue);
    });
  });

  group('Tally 账户元数据（余额回推与独立账户）', () {
    /// 某账户导入后的显示余额 = 初始余额 + 该账户在导入交易中的增量合计。
    double displayedBalance(ImportPlan plan, Account account) {
      var balance = account.initialBalance;
      for (final entry in plan.entries) {
        balance += accountDeltaForEntry(entry, account.id);
      }
      return balance;
    }

    test('有流水的新建账户回推初始余额 = 目标余额 − Σ交易增量（含转账手续费）', () {
      final plan = _build(
        records: <RawImportRecord>[
          _record(type: EntryType.income, amount: 100, account: '微信余额'),
          _record(amount: 40, account: '微信余额'),
          _record(
            type: EntryType.transfer,
            amount: 50,
            fee: 2,
            account: '微信余额',
            toAccount: '银行卡',
          ),
        ],
        accounts: <RawImportAccount>[
          const RawImportAccount(
            name: '微信余额',
            signedBalance: 1000,
            includeInAssets: true,
            type: AccountType.onlinePayment,
          ),
          const RawImportAccount(
            name: '银行卡',
            signedBalance: 500,
            includeInAssets: true,
            type: AccountType.debitCard,
          ),
        ],
      );
      final wechat = plan.newAccounts.firstWhere((a) => a.name == '微信余额');
      final bank = plan.newAccounts.firstWhere((a) => a.name == '银行卡');
      // 微信增量 = +100 − 40 − (50+2) = 8；银行卡增量 = +50。
      expect(wechat.initialBalance, closeTo(992, 1e-9));
      expect(bank.initialBalance, closeTo(450, 1e-9));
      expect(displayedBalance(plan, wechat), closeTo(1000, 1e-9));
      expect(displayedBalance(plan, bank), closeTo(500, 1e-9));
      expect(
        plan.standaloneAccountIds,
        containsAll(<String>[wechat.id, bank.id]),
      );
    });

    test('元数据覆盖账户类型与 includeInAssets（不再是默认现金）', () {
      final plan = _build(
        records: <RawImportRecord>[_record(amount: 10, account: '公积金')],
        accounts: <RawImportAccount>[
          const RawImportAccount(
            name: '公积金',
            signedBalance: 500,
            includeInAssets: false,
            type: AccountType.investment,
          ),
        ],
      );
      final fund = plan.newAccounts.single;
      expect(fund.type, AccountType.investment);
      expect(fund.includeInAssets, isFalse);
    });

    test('无流水资产直接以当前余额补建（含负余额负债）并标记独立', () {
      final plan = _build(
        accounts: <RawImportAccount>[
          const RawImportAccount(
            name: 'qq钱包',
            signedBalance: 0,
            includeInAssets: true,
            type: AccountType.onlinePayment,
          ),
          const RawImportAccount(
            name: '花呗',
            signedBalance: -300,
            includeInAssets: true,
            type: AccountType.creditAccount,
          ),
        ],
      );
      expect(plan.entries, isEmpty);
      expect(plan.newAccounts, hasLength(2));
      final qq = plan.newAccounts.firstWhere((a) => a.name == 'qq钱包');
      final huabei = plan.newAccounts.firstWhere((a) => a.name == '花呗');
      expect(qq.initialBalance, 0);
      expect(huabei.initialBalance, -300);
      expect(huabei.type, AccountType.creditAccount);
      expect(qq.bookId, _bookId);
      expect(
        plan.standaloneAccountIds,
        containsAll(<String>[qq.id, huabei.id]),
      );
    });

    test('已存在的同名账户不改动、不标记独立', () {
      final plan = _build(
        existingAccounts: <Account>[_account('acct_cash', '现金')],
        records: <RawImportRecord>[_record(amount: 10, account: '现金')],
        accounts: <RawImportAccount>[
          const RawImportAccount(
            name: '现金',
            signedBalance: 999,
            includeInAssets: true,
            type: AccountType.cash,
          ),
        ],
      );
      expect(plan.newAccounts, isEmpty);
      expect(plan.standaloneAccountIds, isEmpty);
      expect(plan.entries.single.accountId, 'acct_cash');
    });

    test('无元数据时不产生独立账户集合', () {
      final plan = _build(records: <RawImportRecord>[_record(account: '现金')]);
      expect(plan.standaloneAccountIds, isEmpty);
    });
  });

  group('引用一致性与可复现 id', () {
    List<RawImportRecord> mixedRecords() => <RawImportRecord>[
      _record(
        account: '现金',
        category: '餐饮',
        subCategory: '午餐',
        tags: <String>['工作', '加班'],
        amount: 23.5,
        refunded: 3,
      ),
      _record(
        type: EntryType.income,
        amount: 8000,
        account: '工资卡',
        category: '工资',
      ),
      _record(
        type: EntryType.transfer,
        amount: 100,
        fee: 1,
        account: '现金',
        toAccount: '工资卡',
      ),
      _record(amount: 5), // 无账户无分类。
    ];

    test('交易引用的账户/分类/标签 id 都在「现有+待新建」集合内', () {
      final plan = _build(
        existingAccounts: <Account>[_account('acct_cash', '现金')],
        existingCategories: <Category>[_category('cat_food', '餐饮')],
        existingTags: <Tag>[const Tag(id: 'tag_work', label: '工作')],
        records: mixedRecords(),
      );
      expect(plan.errors, isEmpty);
      expect(plan.entries, hasLength(4));

      final accountIds = <String>{
        'acct_cash',
        ...plan.newAccounts.map((a) => a.id),
      };
      final categoryIds = <String>{
        'cat_food',
        ...plan.newCategories.map((c) => c.id),
      };
      final tagIds = <String>{'tag_work', ...plan.newTags.map((t) => t.id)};
      for (final entry in plan.entries) {
        expect(entry.bookId, _bookId);
        if (entry.accountId.isNotEmpty) {
          expect(accountIds, contains(entry.accountId));
        }
        if (entry.toAccountId != null) {
          expect(accountIds, contains(entry.toAccountId));
        }
        if (entry.categoryId.isNotEmpty) {
          expect(categoryIds, contains(entry.categoryId));
        }
        for (final tagId in entry.tagIds) {
          expect(tagIds, contains(tagId));
        }
      }
      // 新建子分类挂在现有父分类下；新建分类里没有重复的父分类。
      final lunch = plan.newCategories.firstWhere((c) => c.label == '午餐');
      expect(lunch.parentId, 'cat_food');
      expect(plan.newCategories.map((c) => c.label), isNot(contains('餐饮')));
      // 全部新建实体 id 互不重复。
      final allIds = <String>[
        ...plan.entries.map((e) => e.id),
        ...plan.newAccounts.map((a) => a.id),
        ...plan.newCategories.map((c) => c.id),
        ...plan.newTags.map((t) => t.id),
      ];
      expect(allIds.toSet(), hasLength(allIds.length));
    });

    test('同输入两次构建产出完全一致（id 由 now 与记录序派生）', () {
      ImportPlan run() => _build(
        existingCategories: <Category>[_category('cat_food', '餐饮')],
        records: mixedRecords(),
        accounts: <RawImportAccount>[
          const RawImportAccount(
            name: '工资卡',
            signedBalance: 12000,
            includeInAssets: true,
            type: AccountType.debitCard,
          ),
        ],
      );
      final first = run();
      final second = run();
      expect(
        jsonEncode(first.entries.map((e) => e.toJson()).toList()),
        jsonEncode(second.entries.map((e) => e.toJson()).toList()),
      );
      expect(
        first.newAccounts.map((a) => '${a.id}:${a.name}:${a.initialBalance}'),
        second.newAccounts.map((a) => '${a.id}:${a.name}:${a.initialBalance}'),
      );
      expect(
        first.newCategories.map((c) => '${c.id}:${c.label}:${c.parentId}'),
        second.newCategories.map((c) => '${c.id}:${c.label}:${c.parentId}'),
      );
      expect(
        first.newTags.map((t) => '${t.id}:${t.label}'),
        second.newTags.map((t) => '${t.id}:${t.label}'),
      );
      expect(first.standaloneAccountIds, second.standaloneAccountIds);
    });
  });
}
