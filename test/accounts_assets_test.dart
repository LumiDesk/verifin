
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('opens account icon picker from add account page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_icon_select_field')));
    await tester.pumpAndSettle();

    expect(find.text('选择账户图标'), findsOneWidget);
    expect(find.text('通用图标'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text('花呗'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('花呗'), findsOneWidget);
  });

  testWidgets('suggests bank icon from account name', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '中信银行储蓄卡');
    await tester.pumpAndSettle();

    expect(find.text('中信银行'), findsOneWidget);
  });

  testWidgets('opens asset cover selector from the assets page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('更换资产卡片背景'));
    await tester.pumpAndSettle();

    expect(find.text('资产卡片背景'), findsOneWidget);
    expect(find.text('使用线上图片'), findsOneWidget);
    expect(find.text('选择本地图片'), findsOneWidget);
  });

  testWidgets('starts with no default accounts', (WidgetTester tester) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);

    expect(find.text('支付宝'), findsNothing);
    expect(find.text('微信'), findsNothing);
    expect(find.text('花呗'), findsNothing);
  });

  testWidgets('shows empty state on account groups page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理分组'));
    await tester.pumpAndSettle();

    expect(find.text('还没有账户分组'), findsOneWidget);
    expect(find.text('点击右上角加号创建分组，用来整理不同账户。'), findsOneWidget);
  });

  testWidgets('shows accounts by type in the assets page by default', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await addTestAccount(tester, '现金账户');

    expect(find.text('网络支付'), findsOneWidget);
    expect(find.text('现金账户'), findsOneWidget);
  });

  testWidgets('asset section total ignores accounts excluded from assets', (
    WidgetTester tester,
  ) async {
    const included = Account(
      id: 'included-account',
      bookId: defaultLedgerBookId,
      name: '计入账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    const excluded = Account(
      id: 'excluded-account',
      bookId: defaultLedgerBookId,
      name: '不计入账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: false,
      hidden: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: Scaffold(
          body: AccountGroupCard(
            title: '现金',
            accounts: const <Account>[included, excluded],
            balances: const <Account, double>{included: 100, excluded: 500},
          ),
        ),
      ),
    );

    final totalText = tester.widget<Text>(
      find.byKey(const Key('account_group_total_现金')),
    );
    expect(totalText.data, '100');
    expect(find.text('600'), findsNothing);
  });

  testWidgets('account row shows card last four digits', (
    WidgetTester tester,
  ) async {
    const account = Account(
      id: 'card-account',
      bookId: defaultLedgerBookId,
      name: '中信信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: 0,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
      cardLast4: '8321',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: Scaffold(
          body: AccountGroupCard(
            title: '信用卡',
            accounts: const <Account>[account],
            balances: const <Account, double>{account: -120},
          ),
        ),
      ),
    );

    expect(find.textContaining('8321'), findsOneWidget);
  });

  testWidgets('switches asset account view and persists collapsed sections', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller
      ..addAccount(
        Account(
          id: 'asset-view-alipay',
          bookId: controller.activeBook.id,
          name: '支付宝账户',
          type: AccountType.onlinePayment,
          groupId: null,
          initialBalance: 0,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 1);

    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换为分类视图'));
    await tester.pumpAndSettle();

    expect(find.text('未分组'), findsOneWidget);
    expect(find.text('支付宝账户'), findsOneWidget);

    await tester.tap(find.text('未分组'));
    await tester.pumpAndSettle();
    expect(find.text('支付宝账户'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, store);
    await tapBottomTab(tester, 1);

    expect(find.text('未分组'), findsOneWidget);
    expect(find.text('支付宝账户'), findsNothing);
  });

  testWidgets('isolates accounts between ledger books', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await addTestAccount(tester, '默认账本账户');

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('日常账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '旅行账本');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);

    expect(find.text('默认账本账户'), findsNothing);
  });

  test('persists asset account view mode collapse and manual ordering', () async {
    final store = LocalKeyValueStore();
    final source = await makeController(store);
    final first = Account(
      id: 'order-a',
      bookId: source.activeBook.id,
      name: 'A 账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final second = Account(
      id: 'order-b',
      bookId: source.activeBook.id,
      name: 'B 账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    source
      ..addAccount(first)
      ..addAccount(second)
      ..toggleAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
      );
    final sorted = source.sortedAccountsForAssetSection(
      mode: AssetAccountViewMode.type,
      sectionId: AccountType.cash.name,
      accounts: source.accounts,
    );
    source
      ..reorderAssetAccounts(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
        accounts: sorted,
        oldIndex: 0,
        newIndex: 1,
      )
      ..dispose();

    final target = await makeController(store);
    final targetSorted = target.sortedAccountsForAssetSection(
      mode: AssetAccountViewMode.type,
      sectionId: AccountType.cash.name,
      accounts: target.accounts,
    );

    expect(target.assetAccountViewMode, AssetAccountViewMode.type);
    expect(
      target.isAssetSectionCollapsed(
        mode: AssetAccountViewMode.type,
        sectionId: AccountType.cash.name,
      ),
      isTrue,
    );
    expect(targetSorted.map((account) => account.id), <String>[
      'order-b',
      'order-a',
    ]);

    target.dispose();
  });

  test('persists manual asset section ordering', () async {
    final store = LocalKeyValueStore();
    final source = await makeController(store);
    const sections = <String>['onlinePayment', 'creditCard', 'debitCard'];
    source
      ..reorderAssetSections<String>(
        mode: AssetAccountViewMode.type,
        sections: sections,
        idOf: (section) => section,
        oldIndex: 0,
        newIndex: 2,
      )
      ..dispose();

    final target = await makeController(store);
    final sorted = target.sortedAssetSections<String>(
      mode: AssetAccountViewMode.type,
      sections: sections,
      idOf: (section) => section,
    );

    expect(sorted, <String>['creditCard', 'debitCard', 'onlinePayment']);

    target.dispose();
  });
}
