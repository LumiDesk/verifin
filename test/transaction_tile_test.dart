import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/amount_format.dart' as amount_format;
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

/// 覆盖 [TransactionTile] 的展示：分类层级、备注/无备注副行、标签、智能时间。
void main() {
  setUp(() {
    amount_format.moneyUnitStyle = MoneyUnitStyle.symbol;
    amount_format.hideUnitInSingleCurrency = true;
    amount_format.activeBookUsesMultipleCurrencies = false;
  });

  final account = Account(
    id: 'acc1',
    bookId: 'b1',
    name: '招商银行',
    type: AccountType.debitCard,
    groupId: 'g1',
    initialBalance: 0,
    iconCode: 'wallet',
    note: '',
    includeInAssets: true,
    hidden: false,
  );
  const categories = <Category>[
    Category(
      id: 'food',
      label: '食品餐饮',
      type: EntryType.expense,
      iconCode: 'restaurant',
    ),
    Category(
      id: 'lunch',
      label: '午餐',
      type: EntryType.expense,
      iconCode: 'restaurant',
      parentId: 'food',
    ),
  ];
  const tags = <Tag>[
    Tag(id: 't1', label: '出差'),
    Tag(id: 't2', label: '报销'),
    Tag(id: 't3', label: '客户'),
  ];

  LedgerEntry entry({
    String categoryId = 'lunch',
    String note = '',
    List<String> tagIds = const <String>[],
    DateTime? occurredAt,
  }) {
    return LedgerEntry(
      id: 'e1',
      bookId: 'b1',
      type: EntryType.expense,
      amount: 30,
      categoryId: categoryId,
      accountId: 'acc1',
      note: note,
      occurredAt: occurredAt ?? DateTime(2020, 1, 15, 9, 0),
      tagIds: tagIds,
    );
  }

  Future<void> pumpTile(
    WidgetTester tester,
    LedgerEntry e, {
    bool showDate = false,
    String? baseCurrencyCode,
    List<Account>? tileAccounts,
    double? runningBalance,
  }) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: TransactionTile(
            e,
            accounts: tileAccounts ?? <Account>[account],
            categories: categories,
            tags: tags,
            showDate: showDate,
            baseCurrencyCode: baseCurrencyCode,
            runningBalance: runningBalance,
          ),
        ),
      ),
    );
  }

  testWidgets('标题展示分类层级：父级与末级都在', (tester) async {
    await pumpTile(tester, entry());
    expect(find.text('食品餐饮'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
  });

  testWidgets('无备注时副行不回退账户名（账户名只在右侧标签出现一次）', (tester) async {
    await pumpTile(tester, entry(note: ''));
    // 改动前：无备注副行会显示账户名 → 与右侧标签重复出现两次；改动后只剩右侧一次。
    expect(find.text('招商银行'), findsOneWidget);
  });

  testWidgets('有备注时副行显示备注', (tester) async {
    await pumpTile(tester, entry(note: '打车回家'));
    expect(find.text('打车回家'), findsOneWidget);
    // 有备注就不显示账户名兜底，账户名仍只在右侧标签出现一次。
    expect(find.text('招商银行'), findsOneWidget);
  });

  testWidgets('副行展示标签，最多两个、更多收成 +N', (tester) async {
    await pumpTile(tester, entry(tagIds: <String>['t1', 't2', 't3']));
    expect(find.textContaining('#出差'), findsOneWidget);
    expect(find.textContaining('#报销'), findsOneWidget);
    // 三个标签只展示前两个，第三个收成 +1。
    expect(find.textContaining('+1'), findsOneWidget);
    expect(find.textContaining('#客户'), findsNothing);
  });

  testWidgets('showDate=true 时往年交易带年月日与时间', (tester) async {
    await pumpTile(
      tester,
      entry(occurredAt: DateTime(2020, 1, 15, 9, 0)),
      showDate: true,
    );
    expect(find.text('2020/01/15 09:00'), findsOneWidget);
  });

  testWidgets('showDate=false（默认）只显示时分、不带日期', (tester) async {
    await pumpTile(tester, entry(occurredAt: DateTime(2020, 1, 15, 9, 0)));
    expect(find.text('09:00'), findsOneWidget);
    expect(find.textContaining('2020/01/15'), findsNothing);
  });

  testWidgets('跨币种交易以原币为主金额并显示账户实际金额', (tester) async {
    amount_format.activeBookUsesMultipleCurrencies = true;
    await pumpTile(
      tester,
      LedgerEntry(
        id: 'foreign',
        bookId: 'b1',
        type: EntryType.expense,
        amount: 10,
        currencyCode: 'USD',
        accountAmount: 72,
        baseAmount: 72,
        conversionSource: ConversionSource.manual,
        categoryId: 'lunch',
        accountId: account.id,
        note: '',
        occurredAt: DateTime(2026, 8, 1),
      ),
      baseCurrencyCode: 'CNY',
    );

    expect(find.text('-10 \$'), findsOneWidget);
    expect(find.text('72 ¥'), findsOneWidget);
    expect(find.text('-72'), findsNothing);
  });

  testWidgets('同币种转账不显示换算副行（两端单位相同，纯重复）', (tester) async {
    const to = Account(
      id: 'acc2',
      bookId: 'b1',
      name: '现金',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    await pumpTile(
      tester,
      LedgerEntry(
        id: 'same',
        bookId: 'b1',
        type: EntryType.transfer,
        amount: 100,
        currencyCode: 'CNY',
        accountAmount: 100,
        toAccountAmount: 100,
        baseAmount: 0,
        categoryId: 'transfer_out',
        accountId: account.id,
        toAccountId: to.id,
        note: '',
        occurredAt: DateTime(2026, 8, 1),
      ),
      tileAccounts: <Account>[account, to],
      baseCurrencyCode: 'CNY',
    );

    // 主金额不带单位，副行也不该再出现「100 ¥ → 100 ¥」。
    // 账户名标签「招商银行 → 现金」是正常信息，这里只要求不再出现带单位的换算副行。
    expect(find.textContaining('¥'), findsNothing);
  });

  testWidgets('跨币种转账保留两端单位（反向保护）', (tester) async {
    amount_format.moneyUnitStyle = MoneyUnitStyle.code;
    amount_format.activeBookUsesMultipleCurrencies = true;
    const usd = Account(
      id: 'acc2',
      bookId: 'b1',
      name: '美元现金',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'USD',
    );
    await pumpTile(
      tester,
      LedgerEntry(
        id: 'fx',
        bookId: 'b1',
        type: EntryType.transfer,
        amount: 720,
        currencyCode: 'CNY',
        accountAmount: 720,
        toAccountAmount: 100,
        baseAmount: 0,
        categoryId: 'transfer_out',
        accountId: account.id,
        toAccountId: usd.id,
        note: '',
        occurredAt: DateTime(2026, 8, 1),
      ),
      tileAccounts: <Account>[account, usd],
      baseCurrencyCode: 'CNY',
    );

    // 两端币种不同，必须保留单位才能分辨哪端是哪种币。
    expect(find.text('CNY 720 → USD 100'), findsOneWidget);
  });

  testWidgets('逐笔结余在单币种账本不带单位', (tester) async {
    await pumpTile(tester, entry(), runningBalance: 970);

    expect(find.textContaining('余额'), findsOneWidget);
    expect(find.textContaining('970'), findsOneWidget);
    expect(find.textContaining('¥'), findsNothing);
  });

  testWidgets('逐笔结余在多币种账本保留单位（反向保护）', (tester) async {
    amount_format.activeBookUsesMultipleCurrencies = true;
    await pumpTile(tester, entry(), runningBalance: 970);

    expect(find.textContaining('970 ¥'), findsOneWidget);
  });
}
