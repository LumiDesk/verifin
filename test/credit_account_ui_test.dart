import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/account_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> pumpDetail(
    WidgetTester tester,
    dynamic controller,
    Account account,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: AccountDetailPage(account: account),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('信用卡详情：分组模块齐全，信用信息卡数值正确', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final card = Account(
      id: 'cc',
      bookId: controller.activeBook.id,
      name: '招商信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: -3200,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
      cardLast4: '8321',
      creditLimit: 5000,
      statementDay: 5,
      dueDay: 25,
    );
    controller.addAccount(card);
    await pumpDetail(tester, controller, card);

    // 分组小标题都在（「信用」与信用图标标签同名，故用 findsWidgets）。
    for (final label in <String>['基本信息', '卡片信息', '展示与记账', '危险操作']) {
      expect(find.text(label), findsOneWidget, reason: '缺分组: $label');
    }
    expect(find.text('信用'), findsWidgets, reason: '缺信用分组');
    // 卡号入口改名为「卡号」，不再叫「卡号后四位」。
    expect(find.text('卡号'), findsWidgets);
    expect(find.text('卡号后四位'), findsNothing);
    // 信用信息卡：已用/可用/本期账单 + 可用额度数值（5000-3200=1800）。
    expect(find.text('已用'), findsOneWidget);
    expect(find.text('可用额度'), findsOneWidget);
    expect(find.text('本期账单'), findsOneWidget);
    expect(find.textContaining('1800'), findsWidgets);
    // 还款按钮在。
    expect(find.text('还款'), findsWidgets);
  });

  testWidgets('现金详情：不显示卡片/信用模块与还款按钮', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final cash = Account(
      id: 'cash1',
      bookId: controller.activeBook.id,
      name: '钱包',
      type: AccountType.cash,
      groupId: null,
      initialBalance: 100,
      iconCode: 'cash',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller.addAccount(cash);
    await pumpDetail(tester, controller, cash);

    // 基础分组在，卡片/信用分组与还款按钮都不显示。
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('展示与记账'), findsOneWidget);
    expect(find.text('卡片信息'), findsNothing);
    expect(find.text('信用'), findsNothing);
    expect(find.text('信用额度'), findsNothing);
    expect(find.text('还款'), findsNothing);
  });

  testWidgets('信用账户（花呗）详情：有信用模块，无卡片模块', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final huabei = Account(
      id: 'hb',
      bookId: controller.activeBook.id,
      name: '花呗',
      type: AccountType.creditAccount,
      groupId: null,
      initialBalance: -560,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
      creditLimit: 5000,
    );
    controller.addAccount(huabei);
    await pumpDetail(tester, controller, huabei);

    expect(find.text('信用'), findsOneWidget);
    expect(find.text('还款'), findsWidgets);
    // 信用账户无实体卡号，不显示卡片模块。
    expect(find.text('卡片信息'), findsNothing);
  });

  testWidgets('转账交易在列表中显示转账分类而非「已删除分类」', (WidgetTester tester) async {
    final controller = await makeController();
    // 模拟还款：转账、分类为 transfer_out（「转出」）。
    final repayment = LedgerEntry(
      id: 'r1',
      bookId: controller.activeBook.id,
      type: EntryType.transfer,
      amount: 500,
      categoryId: 'transfer_out',
      accountId: '',
      toAccountId: '',
      note: '还款',
      occurredAt: DateTime(2026, 7, 11, 10),
    );
    // 对照：空分类会回退成「已删除分类」（修复前还款的样子）。
    final broken = repayment.copyWith(id: 'r2', categoryId: '');

    await tester.pumpWidget(
      zhMaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              TransactionTile(
                repayment,
                accounts: controller.accounts,
                categories: controller.categories,
              ),
              TransactionTile(
                broken,
                accounts: controller.accounts,
                categories: controller.categories,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('转出'), findsOneWidget);
    expect(find.text('已删除分类'), findsOneWidget);
  });

  testWidgets('切换账户类型到现金：保存前仅改草稿，保存后清空信用字段', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final card = Account(
      id: 'cc2',
      bookId: controller.activeBook.id,
      name: '信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: -100,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
      cardLast4: '8321',
      cardNumber: '6222000000008321',
      cardLast4Follows: true,
      creditLimit: 5000,
      statementDay: 5,
      dueDay: 25,
    );
    controller.addAccount(card);
    await pumpDetail(tester, controller, card);

    // 打开类型选择器，选「现金」。
    await tester.tap(find.text('类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();

    expect(
      controller.accounts.firstWhere((a) => a.id == 'cc2').type,
      AccountType.creditCard,
    );

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final updated = controller.accounts.firstWhere((a) => a.id == 'cc2');
    expect(updated.type, AccountType.cash);
    expect(updated.creditLimit, isNull);
    expect(updated.statementDay, isNull);
    expect(updated.dueDay, isNull);
    expect(updated.cardNumber, '');
    expect(updated.cardLast4, '');
  });

  testWidgets('设置信用额度：先更新草稿，点击保存后落库', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    // 初始无额度、无账单日 → 无信用信息卡，避免「信用额度」文本歧义。
    final card = Account(
      id: 'cc3',
      bookId: controller.activeBook.id,
      name: '信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: -1000,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller.addAccount(card);
    await pumpDetail(tester, controller, card);

    // 尚未设额度：无信用信息卡。
    expect(find.text('可用额度'), findsNothing);

    await tester.tap(find.text('信用额度'));
    await tester.pumpAndSettle();
    for (final key in <String>['3', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('number_key_$key')));
    }
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    // 草稿预览立即显示，但 Controller 尚未改变。
    expect(
      controller.accounts.firstWhere((a) => a.id == 'cc3').creditLimit,
      isNull,
    );
    expect(find.text('可用额度'), findsOneWidget);
    expect(find.textContaining('2000'), findsWidgets);

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(
      controller.accounts.firstWhere((a) => a.id == 'cc3').creditLimit,
      3000,
    );
  });
}
