import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/main.dart';

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

  testWidgets('添加账户修改后返回可选择不保存', (tester) async {
    final controller = await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '临时账户');
    await tester.pump();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('保存修改？'), findsOneWidget);
    expect(controller.accounts, isEmpty);

    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();
    expect(find.text('临时账户'), findsNothing);
    expect(controller.accounts, isEmpty);
  });

  testWidgets('资产背景入口先进入显式保存的显示设置页', (WidgetTester tester) async {
    await pumpApp(tester);

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('更换资产卡片背景'));
    await tester.pumpAndSettle();

    expect(find.text('资产显示设置'), findsOneWidget);
    expect(find.byTooltip('保存'), findsOneWidget);
    await tester.tap(find.text('资产卡片背景'));
    await tester.pumpAndSettle();
    expect(find.text('资产卡片背景'), findsWidgets);
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

  testWidgets('混合币种资产缺汇率时隐藏总额，补齐后按本位币显示', (WidgetTester tester) async {
    final controller = await pumpApp(tester);
    final bookId = controller.activeBook.id;
    controller.addAccount(
      Account(
        id: 'cny-assets-account',
        bookId: bookId,
        name: '人民币现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 100,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: 'CNY',
      ),
    );
    controller.addAccount(
      Account(
        id: 'usd-assets-account',
        bookId: bookId,
        name: '美元现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 10,
        iconCode: 'cash',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: 'USD',
      ),
    );
    await tester.pump();
    await tapBottomTab(tester, 1);

    expect(find.text('有 1 个账户待设置汇率'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('美元现金'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('USD 10'), findsOneWidget);
    expect(find.text('CNY 172'), findsNothing);

    expect(
      await controller.saveExchangeRateDraft(
        currencyCode: 'USD',
        effectiveDate: DateTime(2020),
        rateToBase: 7.2,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(find.text('有 1 个账户待设置汇率'), findsNothing);
    expect(find.text('CNY 172'), findsNWidgets(2));
    expect(find.text('USD 10'), findsOneWidget);
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
      zhMaterialApp(
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
    expect(totalText.data, 'CNY 100');
    expect(find.text('600'), findsNothing);
  });

  testWidgets('account balance colors use a distinct neutral color for zero', (
    WidgetTester tester,
  ) async {
    const account = Account(
      id: 'balance-color-account',
      bookId: defaultLedgerBookId,
      name: '余额颜色账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    const excludedAccount = Account(
      id: 'excluded-balance-color-account',
      bookId: defaultLedgerBookId,
      name: '不计入资产账户',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'cash',
      note: '',
      includeInAssets: false,
      hidden: false,
    );
    final theme = buildVeriFinTheme(Brightness.light);
    late Color zeroColor;
    late Color nearZeroColor;
    late Color positiveColor;
    late Color negativeColor;
    late Color excludedColor;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            zeroColor = accountBalanceColor(context, account, 0);
            nearZeroColor = accountBalanceColor(context, account, -1e-12);
            positiveColor = accountBalanceColor(context, account, 1);
            negativeColor = accountBalanceColor(context, account, -1);
            excludedColor = accountBalanceColor(context, excludedAccount, 0);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(zeroColor, theme.colorScheme.onSurface);
    expect(nearZeroColor, theme.colorScheme.onSurface);
    expect(positiveColor, veriIncome);
    expect(negativeColor, veriExpense);
    expect(excludedColor, theme.colorScheme.onSurface.withValues(alpha: 0.42));
    expect(zeroColor, isNot(excludedColor));
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
      zhMaterialApp(
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

  testWidgets('CardNumberFields 受控：开关反映 follows，打开时同步后四位', (
    WidgetTester tester,
  ) async {
    final numberController = TextEditingController(text: '6222000000001234');
    final last4Controller = TextEditingController(text: '9999');
    var follows = false;

    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CardNumberFields(
              numberController: numberController,
              last4Controller: last4Controller,
              follows: follows,
              onFollowsChanged: (value) => setState(() => follows = value),
            ),
          ),
        ),
      ),
    );

    // 初始 follows=false：开关关、后四位保留手填值。
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(last4Controller.text, '9999');

    // 打开跟随：开关回传 true、后四位同步为完整卡号末四位。
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(follows, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(last4Controller.text, '1234');

    numberController.dispose();
    last4Controller.dispose();
  });

  testWidgets('资产视图保存前不生效，普通折叠不再持久化', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final seed = await makeController(store);
    seed.addAccount(
      Account(
        id: 'asset-view-alipay',
        bookId: seed.activeBook.id,
        name: '支付宝账户',
        type: AccountType.onlinePayment,
        groupId: null,
        initialBalance: 0,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    );
    seed.dispose();

    final controller = await pumpApp(tester, store);
    await tapBottomTab(tester, 1);

    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资产显示设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('类型视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类视图'));
    await tester.pumpAndSettle();

    // 设置页只更新草稿，Controller 仍保持类型视图。
    expect(controller.assetAccountViewMode, AssetAccountViewMode.type);
    await tester.tap(find.byTooltip('保存'));
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
    expect(find.text('支付宝账户'), findsOneWidget);
  });

  testWidgets('资产显示设置返回时可放弃草稿', (tester) async {
    final controller = await pumpApp(tester);
    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资产显示设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('类型视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('保存修改？'), findsOneWidget);
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();
    expect(controller.assetAccountViewMode, AssetAccountViewMode.type);
    expect(find.text('资产显示设置'), findsNothing);
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
    await tester.enterText(
      find.byKey(const Key('ledger_book_name_field')),
      '旅行账本',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ledger_book_save_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);

    expect(find.text('默认账本账户'), findsNothing);
  });

  test(
    'persists asset account view mode collapse and manual ordering',
    () async {
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
    },
  );

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

  testWidgets('资产分区排序先留在设置草稿，保存后才写入 Controller', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(460, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'a-cash',
          bookId: bookId,
          name: '现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 10,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addAccount(
        Account(
          id: 'a-credit',
          bookId: bookId,
          name: '信用卡',
          type: AccountType.creditCard,
          groupId: null,
          initialBalance: 0,
          iconCode: 'card',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      );
    await tester.pumpWidget(VeriFinApp(controller: controller));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资产显示设置'));
    await tester.pumpAndSettle();

    expect(find.text('拖动分区手柄或长按账户调整顺序'), findsOneWidget);
    final before = controller.sortedAssetSections<String>(
      mode: AssetAccountViewMode.type,
      sections: const <String>['creditCard', 'cash'],
      idOf: (section) => section,
    );
    expect(before, const <String>['creditCard', 'cash']);

    final handles = find.byIcon(Icons.drag_indicator);
    final firstHandle = tester.getCenter(handles.at(0));
    final secondHandle = tester.getCenter(handles.at(1));
    await tester.timedDragFrom(
      firstHandle,
      Offset(0, secondHandle.dy - firstHandle.dy + 40),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    // 拖动只改变页面草稿。
    expect(
      controller.sortedAssetSections<String>(
        mode: AssetAccountViewMode.type,
        sections: const <String>['creditCard', 'cash'],
        idOf: (section) => section,
      ),
      const <String>['creditCard', 'cash'],
    );
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(
      controller.sortedAssetSections<String>(
        mode: AssetAccountViewMode.type,
        sections: const <String>['creditCard', 'cash'],
        idOf: (section) => section,
      ),
      const <String>['cash', 'creditCard'],
    );
  });

  testWidgets('资产页不再提供会即时落库的内联排序', (WidgetTester tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'a-online',
          bookId: bookId,
          name: '网络支付',
          type: AccountType.onlinePayment,
          groupId: null,
          initialBalance: 10,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addAccount(
        Account(
          id: 'a-credit',
          bookId: bookId,
          name: '信用卡',
          type: AccountType.creditCard,
          groupId: null,
          initialBalance: 0,
          iconCode: 'card',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      );
    await tester.pumpWidget(VeriFinApp(controller: controller));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);

    expect(find.text('排序'), findsNothing);
    await tester.tap(find.byTooltip('资产操作'));
    await tester.pumpAndSettle();
    expect(find.text('排序分组'), findsNothing);
    expect(find.text('资产显示设置'), findsOneWidget);
  });
}
