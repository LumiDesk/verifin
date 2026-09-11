import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_query_tool.dart';
import 'package:verifin/app/ledger_math.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/l10n/app_localizations.dart';

LedgerEntry _e({
  required String id,
  EntryType type = EntryType.expense,
  double amount = 100,
  String categoryId = 'food',
  String note = '',
  List<String> tagIds = const <String>[],
  DateTime? at,
}) {
  return LedgerEntry(
    id: id,
    bookId: 'b',
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: 'acc',
    note: note,
    occurredAt: at ?? DateTime(2026, 6, 15),
    tagIds: tagIds,
  );
}

AiToolContext _ctx(
  List<LedgerEntry> entries, {
  List<Category> categories = const <Category>[],
  List<Tag> tags = const <Tag>[],
  List<Account> accounts = const <Account>[],
  List<ExchangeRate> exchangeRates = const <ExchangeRate>[],
  DateTime? now,
}) {
  return AiToolContext(
    entries: entries,
    accounts: accounts,
    categories: categories,
    tags: tags,
    balanceOf: (_) => 0,
    baseCurrencyCode: 'CNY',
    exchangeRates: exchangeRates,
    now: now ?? DateTime(2026, 6, 20),
    l10n: lookupAppLocalizations(const Locale('zh')),
  );
}

Category _cat(String id, String label) =>
    Category(id: id, label: label, type: EntryType.expense, iconCode: 'food');

Account _account({
  required String id,
  required String name,
  String currencyCode = 'CNY',
}) => Account(
  id: id,
  bookId: 'b',
  name: name,
  type: AccountType.cash,
  groupId: null,
  initialBalance: 0,
  iconCode: 'cash',
  note: '',
  includeInAssets: true,
  hidden: false,
  currencyCode: currencyCode,
);

AiQueryTool _tool(String name) =>
    buildAiQueryTools().firstWhere((t) => t.name == name);

void main() {
  test('注册表工具名唯一且非空', () {
    final tools = buildAiQueryTools();
    final names = tools.map((t) => t.name).toList();
    expect(names.toSet().length, names.length, reason: '工具名不应重复');
    for (final t in tools) {
      expect(t.name.trim(), isNotEmpty);
      expect(t.description.trim(), isNotEmpty);
      // 无参工具（账户一览 / 净资产 / 信用卡账单）的参数说明本来就为空。
      if (t.schema.properties.isNotEmpty) {
        expect(t.schema.promptDescription, isNotEmpty);
      }
    }
  });

  test('typed schema generates native definitions and validates arguments', () {
    final tool = _tool('queryTransactions');
    final definition = tool.toNativeDefinition();
    final function = definition['function']! as Map<String, Object?>;
    final parameters = function['parameters']! as Map<String, Object?>;
    final properties = parameters['properties']! as Map<String, Object?>;

    expect(definition['type'], 'function');
    expect(function['name'], 'queryTransactions');
    expect(parameters['type'], 'object');
    expect(parameters['additionalProperties'], isFalse);
    expect(properties.keys, containsAll(<String>['range', 'start', 'end']));
    expect(
      tool.schema.validate(<String, Object?>{
        'range': 'thisMonth',
        'limit': 20,
      }),
      isEmpty,
    );
    expect(
      tool.schema.validate(<String, Object?>{
        'range': 'not-a-range',
        'unknown': true,
      }),
      hasLength(2),
    );
  });

  test('summary 汇总当月收支净额', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'x', type: EntryType.expense, amount: 300),
      _e(id: 'i', type: EntryType.income, amount: 1000),
      _e(
        id: 'old',
        type: EntryType.expense,
        amount: 999,
        at: DateTime(2026, 5, 1),
      ),
    ]);
    final r = _tool(
      'summary',
    ).run(ctx, <String, Object?>{'range': 'thisMonth'});
    final d = r.display as AiStatDisplay;
    expect(d.items.firstWhere((i) => i.label == '支出').value, 300);
    expect(d.items.firstWhere((i) => i.label == '收入').value, 1000);
    expect(d.items.firstWhere((i) => i.label == '净额').value, 700);
  });

  test('categoryRanking 按顶级分类降序、支持 limit', () {
    final ctx = _ctx(
      <LedgerEntry>[
        _e(id: 'a', amount: 100, categoryId: 'food'),
        _e(id: 'b', amount: 400, categoryId: 'travel'),
        _e(id: 'c', amount: 50, categoryId: 'fun'),
      ],
      categories: <Category>[
        _cat('food', '餐饮'),
        _cat('travel', '出行'),
        _cat('fun', '娱乐'),
      ],
    );
    final r = _tool(
      'categoryRanking',
    ).run(ctx, <String, Object?>{'range': 'thisMonth', 'limit': 2});
    final d = r.display as AiRankingDisplay;
    expect(d.rows.length, 2);
    expect(d.rows.first.label, '出行');
    expect(d.rows.first.amount, 400);
  });

  test('largestTransactions 取最大若干笔并返回 entryIds', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'small', amount: 30),
      _e(id: 'big', amount: 900),
      _e(id: 'mid', amount: 300),
    ]);
    final r = _tool(
      'largestTransactions',
    ).run(ctx, <String, Object?>{'range': 'all', 'limit': 2});
    final d = r.display as AiTransactionsDisplay;
    expect(d.entryIds, <String>['big', 'mid']);
  });

  test('queryTransactions 按关键词与金额筛选', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'a', amount: 200, note: '星巴克咖啡'),
      _e(id: 'b', amount: 20, note: '星巴克咖啡'),
      _e(id: 'c', amount: 200, note: '午饭'),
    ]);
    final r = _tool('queryTransactions').run(ctx, <String, Object?>{
      'range': 'all',
      'keyword': '星巴克',
      'minAmount': 50,
    });
    final d = r.display as AiTransactionsDisplay;
    expect(d.entryIds, <String>['a']);
  });

  test('queryTransactions 转账摘要展示两端金额而不是本位币 0', () {
    const cny = Account(
      id: 'cny',
      bookId: 'b',
      name: '人民币',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    const usd = Account(
      id: 'usd',
      bookId: 'b',
      name: '美元',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'USD',
    );
    final transfer = LedgerEntry(
      id: 'transfer',
      bookId: 'b',
      type: EntryType.transfer,
      amount: 720,
      currencyCode: 'CNY',
      accountAmount: 720,
      toAccountAmount: 100,
      baseAmount: 0,
      categoryId: 'transfer_out',
      accountId: cny.id,
      toAccountId: usd.id,
      note: '换汇',
      occurredAt: DateTime(2026, 6, 15),
    );
    final result = _tool('queryTransactions').run(
      _ctx(<LedgerEntry>[transfer], accounts: const <Account>[cny, usd]),
      <String, Object?>{'range': 'all', 'type': 'transfer'},
    );

    expect(result.summary, contains('CNY 720'));
    expect(result.summary, contains('USD 100'));
    expect(result.summary, isNot(contains('CNY 0')));
  });

  test('trend 按时间窗返回趋势序列', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'a', amount: 100, at: DateTime(2026, 6, 3)),
      _e(id: 'b', amount: 50, at: DateTime(2026, 6, 10)),
    ]);
    final result = _tool(
      'trend',
    ).run(ctx, <String, Object?>{'range': 'thisMonth', 'type': 'expense'});
    final display = result.display! as AiTrendDisplay;
    expect(display.values.fold<double>(0, (sum, value) => sum + value), 150);
    expect(result.summary, contains('150'));
  });

  test('compare 给出环比与同比', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'a', amount: 200, at: DateTime(2026, 6, 3)),
      _e(id: 'b', amount: 100, at: DateTime(2026, 5, 3)),
    ]);
    final result = _tool(
      'compare',
    ).run(ctx, <String, Object?>{'month': '2026-06'});
    final display = result.display! as AiStatDisplay;
    expect(display.items.first.value, 200);
    expect(result.summary, contains('+100.0%'));
  });

  test('accountsOverview 列出账户与余额', () {
    final ctx = AiToolContext(
      entries: const <LedgerEntry>[],
      accounts: <Account>[_account(id: 'a1', name: '现金')],
      categories: const <Category>[],
      tags: const <Tag>[],
      balanceOf: (_) => 123.5,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
    );
    final result = _tool(
      'accountsOverview',
    ).run(ctx, const <String, Object?>{});
    final display = result.display! as AiTableDisplay;
    expect(display.rows.single.first, '现金');
    expect(display.rows.single[1], 'CNY');
    expect(display.rows.single[2], contains('123.5'));
  });

  test('单币种隐藏单位时账户表去掉币种列，摘要也不写币种代码', () {
    final ctx = AiToolContext(
      entries: const <LedgerEntry>[],
      accounts: <Account>[_account(id: 'a1', name: '现金')],
      categories: const <Category>[],
      tags: const <Tag>[],
      balanceOf: (_) => 123.5,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
      currencyDisplay: MoneyCodeDisplay.none,
    );
    final result = _tool(
      'accountsOverview',
    ).run(ctx, const <String, Object?>{});
    final display = result.display! as AiTableDisplay;
    // 币种列整列去掉，余额列顺位前移。
    expect(display.headers, <String>['账户', '余额']);
    expect(display.rows.single, <String>['现金', '123.5']);
    // 摘要句要跟界面上的金额同口径，否则模型会照着写出「合计 CNY …」。
    expect(result.summary, isNot(contains('CNY')));
  });

  test('单币种隐藏单位时同币种转账只报一次金额', () {
    const from = Account(
      id: 'a',
      bookId: 'b',
      name: '招行',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    const to = Account(
      id: 'b2',
      bookId: 'b',
      name: '现金',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final transfer = LedgerEntry(
      id: 'transfer',
      bookId: 'b',
      type: EntryType.transfer,
      amount: 100,
      currencyCode: 'CNY',
      accountAmount: 100,
      toAccountAmount: 100,
      baseAmount: 0,
      categoryId: 'transfer_out',
      accountId: from.id,
      toAccountId: to.id,
      note: '',
      occurredAt: DateTime(2026, 6, 15),
    );
    final result = _tool('queryTransactions').run(
      _ctx(<LedgerEntry>[transfer], accounts: const <Account>[from, to]),
      <String, Object?>{'range': 'all', 'type': 'transfer'},
    );

    // 两端同币种，报「100 → 100」是重复信息。
    expect(result.summary, isNot(contains('→')));
    expect(result.summary, contains('100'));
  });

  test('netWorth 缺汇率时不给部分和', () {
    final ctx = AiToolContext(
      entries: const <LedgerEntry>[],
      accounts: <Account>[
        _account(id: 'a1', name: '美元账户', currencyCode: 'USD'),
      ],
      categories: const <Category>[],
      tags: const <Tag>[],
      balanceOf: (_) => 100,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
    );
    final result = _tool('netWorth').run(ctx, const <String, Object?>{});
    expect(result.display, isNull);
    expect(result.summary, contains('缺少汇率'));
  });

  test('creditCardBill 汇总欠款、可用额度与本期账单', () {
    final card = Account(
      id: 'acc',
      bookId: 'b',
      name: '信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: 0,
      iconCode: 'bank',
      note: '',
      includeInAssets: true,
      hidden: false,
      creditLimit: 10000,
      statementDay: 5,
      dueDay: 20,
    );
    final ctx = AiToolContext(
      entries: <LedgerEntry>[
        _e(id: 'c', amount: 300, at: DateTime(2026, 6, 6)),
      ],
      accounts: <Account>[card],
      categories: const <Category>[],
      tags: const <Tag>[],
      balanceOf: (_) => -300,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
    );
    final result = _tool('creditCardBill').run(ctx, const <String, Object?>{});
    final display = result.display! as AiTableDisplay;
    expect(display.rows.single.first, '信用卡');
    expect(result.summary, contains('300'));
  });

  test('单币种隐藏单位时信用卡摘要不带币种代码', () {
    final card = Account(
      id: 'acc',
      bookId: 'b',
      name: '信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: 0,
      iconCode: 'bank',
      note: '',
      includeInAssets: true,
      hidden: false,
      creditLimit: 10000,
      statementDay: 5,
      dueDay: 20,
    );
    final ctx = AiToolContext(
      entries: <LedgerEntry>[
        _e(id: 'c', amount: 300, at: DateTime(2026, 6, 6)),
      ],
      accounts: <Account>[card],
      categories: const <Category>[],
      tags: const <Tag>[],
      balanceOf: (_) => -300,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
      currencyDisplay: MoneyCodeDisplay.none,
    );
    final result = _tool('creditCardBill').run(ctx, const <String, Object?>{});
    // 卡片表格本来就没有币种列，摘要句是这张卡唯一的币种来源；隐藏单位时它也不能写代码。
    expect(result.summary, isNot(contains('CNY')));
    expect(result.summary, contains('300'));
  });

  test('多币种信用卡表格保留币种列，避免金额无法辨认', () {
    final cny = Account(
      id: 'cny-card',
      bookId: 'b',
      name: '人民币卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: 0,
      iconCode: 'bank',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'CNY',
      creditLimit: 10000,
    );
    final usd = cny.copyWith(id: 'usd-card', name: '美元卡', currencyCode: 'USD');
    final result = _tool('creditCardBill').run(
      AiToolContext(
        entries: const <LedgerEntry>[],
        accounts: <Account>[cny, usd],
        categories: const <Category>[],
        tags: const <Tag>[],
        balanceOf: (account) => account.id == usd.id ? -200 : -100,
        baseCurrencyCode: 'CNY',
        now: DateTime(2026, 6, 20),
        l10n: lookupAppLocalizations(const Locale('zh')),
      ),
      const <String, Object?>{},
    );
    final display = result.display! as AiTableDisplay;
    expect(display.headers, <String>['账户', '币种', '当前欠款', '可用额度', '本期账单']);
    expect(
      display.rows.map((row) => row[1]),
      containsAll(<String>['CNY', 'USD']),
    );
  });

  test('budgetStatus 汇总预算执行并列出需要关注的分类', () {
    final ctx = AiToolContext(
      entries: <LedgerEntry>[
        _e(id: 'a', amount: 900, at: DateTime(2026, 6, 3)),
      ],
      accounts: const <Account>[],
      categories: <Category>[_cat('food', '餐饮')],
      tags: const <Tag>[],
      balanceOf: (_) => 0,
      baseCurrencyCode: 'CNY',
      now: DateTime(2026, 6, 20),
      l10n: lookupAppLocalizations(const Locale('zh')),
      budget: AiBudgetContext(
        keyMonthOf: (date) => DateTime(date.year, date.month),
        windowOf: (keyMonth) => DateWindow(
          start: DateTime(keyMonth.year, keyMonth.month, 1),
          end: DateTime(keyMonth.year, keyMonth.month + 1, 0),
        ),
        monthlyBudgetOf: (_) => 1000,
        categoryBudgetOf: (_, _) => 500,
      ),
    );
    final result = _tool('budgetStatus').run(ctx, const <String, Object?>{});
    final display = result.display! as AiStatDisplay;
    expect(display.items.firstWhere((i) => i.label == '预算').value, 1000);
    expect(display.items.firstWhere((i) => i.label == '已花').value, 900);
    expect(result.summary, contains('需要关注'));
  });

  test('缺省 / 非法参数优雅降级不抛异常', () {
    final ctx = _ctx(<LedgerEntry>[_e(id: 'a', amount: 100)]);
    for (final tool in buildAiQueryTools()) {
      expect(
        () =>
            tool.run(ctx, <String, Object?>{'range': 'nonsense', 'limit': 'x'}),
        returnsNormally,
        reason: '${tool.name} 应对非法参数降级',
      );
    }
  });

  group('AiResultDisplay 序列化往返', () {
    void roundTrip(AiResultDisplay original) {
      final restored = aiResultDisplayFromJson(original.toJson());
      expect(restored.runtimeType, original.runtimeType);
    }

    test('stat', () {
      const d = AiStatDisplay(
        title: '汇总',
        items: <AiStatItem>[
          AiStatItem(label: '支出', value: 300),
          AiStatItem(label: '净额', value: 700, emphasize: true),
        ],
      );
      roundTrip(d);
      final r = aiResultDisplayFromJson(d.toJson())! as AiStatDisplay;
      expect(r.items.last.emphasize, isTrue);
      expect(r.items.first.value, 300);
    });

    test('ranking / trend / transactions / table', () {
      roundTrip(
        const AiRankingDisplay(
          title: '排行',
          rows: <AiRankingRow>[
            AiRankingRow(label: '餐饮', amount: 400, percent: 0.8, count: 3),
          ],
        ),
      );
      roundTrip(
        const AiTrendDisplay(
          title: '趋势',
          values: <double>[1, 2, 3],
          labels: <String>['一', '二', '三'],
        ),
      );
      roundTrip(
        const AiTransactionsDisplay(title: '明细', entryIds: <String>['a', 'b']),
      );
      final table = aiResultDisplayFromJson(
        const AiTableDisplay(
          title: '表',
          headers: <String>['名称', '金额'],
          rows: <List<String>>[
            <String>['餐饮', '400'],
          ],
        ).toJson(),
      );
      expect((table! as AiTableDisplay).rows.first, <String>['餐饮', '400']);
    });

    test('未知 kind 返回 null', () {
      expect(aiResultDisplayFromJson(<String, Object?>{'kind': 'zzz'}), isNull);
    });
  });
}
