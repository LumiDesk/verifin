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

    test('分类为空的收支兜底到「未分类」固定 id，不再落空分类（issue #16）', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,23.5,,现金,,没写分类',
      );
      expect(plan.importedCount, 1);
      expect(
        plan.entries.single.categoryId,
        uncategorizedCategoryId(EntryType.expense),
      );
      final candidate = plan.newCategories.single;
      expect(candidate.id, uncategorizedCategoryId(EntryType.expense));
      expect(candidate.label, '未分类');
      expect(candidate.type, EntryType.expense);
    });

    test('「未分类」候选按类型各一：多行复用、收支分开', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n'
        '2026-01-05,支出,10,,现金,,a\n'
        '2026-01-05,支出,20,,现金,,b\n'
        '2026-01-05,收入,30,,现金,,c',
      );
      expect(plan.importedCount, 3);
      expect(plan.newCategories.map((c) => c.id).toSet(), <String>{
        uncategorizedCategoryId(EntryType.expense),
        uncategorizedCategoryId(EntryType.income),
      });
    });

    test('现有「未分类」（固定 id 或用户手建同名）直接复用、不进候选', () {
      const rows = '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,10,,现金,,x';
      // 固定 id 已存在 → 复用。
      final withFixed = buildImportPlan(
        rows: parseCsv(rows),
        bookId: 'book_default',
        existingAccounts: baseAccounts(),
        existingCategories: <Category>[
          ...baseCategories(),
          buildUncategorizedCategory(EntryType.expense, english: false),
        ],
        now: DateTime(2026, 1, 5, 12),
      );
      expect(withFixed.newCategories, isEmpty);
      expect(
        withFixed.entries.single.categoryId,
        uncategorizedCategoryId(EntryType.expense),
      );

      // 用户手建的同名顶级分类（id 不同）→ 复用它，避免与
      // (label,type,parent) 唯一索引冲突建出重复同名分类。
      final manual = buildImportPlan(
        rows: parseCsv(rows),
        bookId: 'book_default',
        existingAccounts: baseAccounts(),
        existingCategories: const <Category>[
          Category(
            id: 'cat_manual',
            label: '未分类',
            type: EntryType.expense,
            iconCode: 'category',
          ),
        ],
        now: DateTime(2026, 1, 5, 12),
      );
      expect(manual.newCategories, isEmpty);
      expect(manual.entries.single.categoryId, 'cat_manual');
    });

    test('seedEnglish 时「未分类」候选取英文文案', () {
      final plan = buildImportPlan(
        rows: parseCsv('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,10,,现金,,x'),
        bookId: 'book_default',
        existingAccounts: baseAccounts(),
        existingCategories: baseCategories(),
        now: DateTime(2026, 1, 5, 12),
        seedEnglish: true,
      );
      expect(plan.newCategories.single.label, 'Uncategorized');
    });

    test('转账：双账户正常、单边允许、双空报错、相同报错', () {
      final ok = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,储蓄卡,取现');
      expect(ok.importedCount, 1);
      expect(ok.entries.single.toAccountId, isNotNull);
      expect(ok.newAccounts.single.name, '储蓄卡');

      // 单边转账（仅转出，转入未跟踪）→ 仍按转账记，转入端为空。
      final oneSided = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,,x',
      );
      expect(oneSided.importedCount, 1);
      expect(oneSided.entries.single.toAccountId, isNull);
      expect(oneSided.entries.single.accountId, isNotEmpty);

      // 两端都空 → 无法表示为转账，报错。
      final bothEmpty = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,,,x');
      expect(bothEmpty.importedCount, 0);
      expect(bothEmpty.errorCount, 1);

      final same = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,现金,x');
      expect(same.errorCount, 1);
    });

    test('转账手续费：识别「手续费」列并落到 fee（缺列则为 0）', () {
      final withFee = build(
        '日期,类型,金额,分类,账户,转入账户,备注,手续费\n2026-01-05,转账,500,,现金,储蓄卡,取现,2.5',
      );
      expect(withFee.entries.single.fee, 2.5);

      final noFeeColumn = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,转账,500,,现金,储蓄卡,取现',
      );
      expect(noFeeColumn.entries.single.fee, 0);
    });

    test('账户为空的收支导入为无账户交易（不再报错）', () {
      final plan = build('日期,类型,金额,分类,账户,转入账户,备注\n2026-01-05,支出,23.5,餐饮,,,记一笔');
      expect(plan.importedCount, 1);
      expect(plan.errorCount, 0);
      expect(plan.entries.single.accountId, isEmpty);
      expect(plan.newAccounts, isEmpty);
    });

    test('非法行记录错误而不中断其余行', () {
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n'
        'bad-date,支出,10,餐饮,现金,,x\n'
        '2026-01-05,飞行,10,餐饮,现金,,x\n'
        '2026-01-05,支出,abc,餐饮,现金,,x\n'
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

    test('越界日期不被静默归一化，按错误行处理', () {
      // 2-30 不存在、25:70 超范围；应记为错误而非静默变成 3-2 / 次日。
      final plan = build(
        '日期,类型,金额,分类,账户,转入账户,备注\n'
        '2026-02-30,支出,10,餐饮,现金,,不存在的日\n'
        '2026-01-05 25:70,支出,10,餐饮,现金,,越界时间\n'
        '2026-01-05,支出,12,餐饮,现金,,正常',
      );
      expect(plan.importedCount, 1);
      expect(plan.errorCount, 2);
      expect(plan.entries.single.note, '正常');
    });
  });

  group('CSV 模板严格校验', () {
    test('本应用模板表头通过（顺序/首尾空白容忍）', () {
      // 用模板自身表头 + 打乱顺序 + 带空白，均应通过。
      validateCsvTemplateHeader(parseCsv(transactionCsvTemplate()));
      validateCsvTemplateHeader(parseCsv(' 类型 , 日期 ,金额,分类,账户,转入账户,备注\n'));
    });

    test('第三方软件原生表头被拒（不再靠通用识别）', () {
      // 钱迹：账户1/账户2/一级分类；随手记：交易类型。均非模板列，须报错。
      expect(
        () => validateCsvTemplateHeader(
          parseCsv('时间,类型,金额,一级分类,账户1,账户2,备注\n支出,,,,,,'),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            validateCsvTemplateHeader(parseCsv('交易类型,日期,金额,一级分类,账户1,账户2,备注\n')),
        throwsFormatException,
      );
    });

    test('可选列（子分类/标签）与省略可选列均通过', () {
      // 补充可选的 子分类/标签 列（issue #11 层级分类 + 多标签）——都是模板认识的列。
      validateCsvTemplateHeader(parseCsv('日期,类型,金额,分类,子分类,账户,转入账户,备注,标签\n'));
      // 省略可选列（只留必需 + 分类）——白名单不因缺可选列而报错。
      validateCsvTemplateHeader(parseCsv('日期,类型,金额,账户\n'));
    });

    test('外来列即报错、空文件报错', () {
      // 混入一个非模板列即拒（其余列都合法也不放行）。
      expect(
        () => validateCsvTemplateHeader(
          parseCsv('日期,类型,金额,分类,账户,转入账户,备注,不存在的列\n'),
        ),
        throwsFormatException,
      );
      expect(
        () => validateCsvTemplateHeader(const <List<String>>[]),
        throwsFormatException,
      );
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
