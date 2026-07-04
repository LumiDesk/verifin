import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/transaction_import.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  group('parseCsv', () {
    test('基础逗号分隔', () {
      final rows = parseCsv('a,b,c\n1,2,3\n');
      expect(rows, <List<String>>[
        <String>['a', 'b', 'c'],
        <String>['1', '2', '3'],
      ]);
    });

    test('引号包裹字段内逗号与换行与转义引号', () {
      final rows = parseCsv('a,"b,含逗号","含""引号"\n"多\n行",2,3');
      expect(rows.first, <String>['a', 'b,含逗号', '含"引号']);
      expect(rows[1], <String>['多\n行', '2', '3']);
    });

    test('忽略空行', () {
      final rows = parseCsv('a,b\n\n\n1,2\n');
      expect(rows.length, 2);
    });
  });

  group('buildImportPlan', () {
    List<Category> baseCategories() => <Category>[
      const Category(
        id: 'cat_food',
        label: '餐饮',
        type: EntryType.expense,
        iconCode: 'dining',
      ),
    ];
    List<Account> baseAccounts() => <Account>[
      const Account(
        id: 'acc_cash',
        bookId: 'book_default',
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 0,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    ];

    ImportPlan build(String csv) => buildImportPlan(
      rows: parseCsv(csv),
      bookId: 'book_default',
      existingAccounts: baseAccounts(),
      existingCategories: baseCategories(),
      now: DateTime(2026, 1, 5, 12),
    );

    test('匹配现有账户/分类，导入支出', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,23.5,餐饮,现金,,午饭',
      );
      expect(plan.importedCount, 1);
      expect(plan.newAccounts, isEmpty);
      expect(plan.newCategories, isEmpty);
      final entry = plan.entries.single;
      expect(entry.type, EntryType.expense);
      expect(entry.amount, 23.5);
      expect(entry.categoryId, 'cat_food');
      expect(entry.accountId, 'acc_cash');
      expect(entry.note, '午饭');
    });

    test('未知账户与分类按名称新建', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,收入,8000,工资,工资卡,,月薪',
      );
      expect(plan.importedCount, 1);
      expect(plan.newAccounts.single.name, '工资卡');
      expect(plan.newCategories.single.label, '工资');
      expect(plan.newCategories.single.type, EntryType.income);
      expect(plan.entries.single.accountId, plan.newAccounts.single.id);
      expect(plan.entries.single.categoryId, plan.newCategories.single.id);
    });

    test('转账需要转入账户且不同', () {
      final ok = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,储蓄卡,取现');
      expect(ok.importedCount, 1);
      expect(ok.entries.single.toAccountId, isNotNull);
      expect(ok.newAccounts.single.name, '储蓄卡');

      final missing = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,,x');
      expect(missing.importedCount, 0);
      expect(missing.errorCount, 1);

      final same = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,现金,x');
      expect(same.errorCount, 1);
    });

    test('非法行记录错误而不中断其余行', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n'
        'bad-date,支出,10,餐饮,现金,,x\n'
        '2026-01-05,飞行,10,餐饮,现金,,x\n'
        '2026-01-05,支出,-5,餐饮,现金,,x\n'
        '2026-01-05,支出,12,餐饮,现金,,好行',
      );
      expect(plan.importedCount, 1);
      expect(plan.errorCount, 3);
      expect(plan.errors.map((e) => e.line), <int>[2, 3, 4]);
    });

    test('缺少必需列抛 FormatException', () {
      expect(
        () => build('日期,金额\n2026-01-05,10'),
        throwsA(isA<FormatException>()),
      );
    });

    test('支持斜杠日期与带时间', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026/01/05 09:30,支出,10,餐饮,现金,,x',
      );
      expect(plan.entries.single.occurredAt, DateTime(2026, 1, 5, 9, 30));
    });
  });

  group('控制器 CSV 导入', () {
    test('导入后交易进入当前账本并新建账户/分类', () async {
      final controller = await makeController();
      final beforeEntries = controller.entries.length;
      final beforeAccounts = controller.accounts.length;
      final plan = controller.importTransactionsFromCsv(
        '日期,类型,金额,分类,账户,转入账户,备注\n'
        '2026-01-05,支出,23.5,夜宵,钱包A,,宵夜\n'
        '2026-01-06,收入,100,红包,钱包A,,压岁钱',
      );
      expect(plan.importedCount, 2);
      expect(controller.entries.length, beforeEntries + 2);
      // 新账户 钱包A 落地。
      expect(controller.accounts.where((a) => a.name == '钱包A'), hasLength(1));
      expect(controller.accounts.length, beforeAccounts + 1);
      // 新分类 夜宵/红包 落地。
      expect(controller.categories.any((c) => c.label == '夜宵'), isTrue);
      expect(controller.categories.any((c) => c.label == '红包'), isTrue);
    });

    test('导入的模板自身可被解析导入', () async {
      final controller = await makeController();
      final plan = controller.importTransactionsFromCsv(
        transactionCsvTemplate(),
      );
      expect(plan.importedCount, 3);
      expect(plan.errorCount, 0);
    });
  });
}
