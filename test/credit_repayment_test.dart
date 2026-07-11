import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/credit_repayment_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('信用卡还款：默认预填欠款，确认生成转账并抵消欠款', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final card = Account(
      id: 'credit-card-1',
      bookId: controller.activeBook.id,
      name: '测试信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: -500,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    final bank = Account(
      id: 'bank-1',
      bookId: controller.activeBook.id,
      name: '测试储蓄卡',
      type: AccountType.debitCard,
      groupId: null,
      initialBalance: 1000,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller
      ..addAccount(card)
      ..addAccount(bank)
      ..setDefaultAccountId(bank.id);

    expect(controller.accountBalance(card), -500);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CreditRepaymentPage(account: card),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 还款金额默认预填当前欠款 500，扣款账户默认取记账默认账户（储蓄卡）。
    expect(find.text('还款'), findsWidgets);
    expect(find.textContaining('500'), findsWidgets);
    expect(find.textContaining('测试储蓄卡'), findsOneWidget);

    // 点击确认（页头对勾）。
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // 欠款被抵消，储蓄卡扣款。
    expect(controller.accountBalance(card), 0);
    expect(controller.accountBalance(bank), 500);
    final repayment = controller.entries.firstWhere(
      (entry) =>
          entry.type == EntryType.transfer && entry.toAccountId == card.id,
    );
    expect(repayment.amount, 500);
    expect(repayment.accountId, bank.id);
    // 用真实转账分类（非空），列表不会回退成「已删除分类」。
    final transferCategoryIds = controller
        .categoriesForType(EntryType.transfer)
        .map((c) => c.id)
        .toList();
    expect(repayment.categoryId, isNotEmpty);
    expect(transferCategoryIds, contains(repayment.categoryId));
  });

  testWidgets('信用卡还款：无账户（代还）只增额度不扣任何账户', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final card = Account(
      id: 'credit-card-2',
      bookId: controller.activeBook.id,
      name: '花呗',
      type: AccountType.creditAccount,
      groupId: null,
      initialBalance: -300,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
    );
    controller.addAccount(card);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CreditRepaymentPage(account: card),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 选择「无账户（代还）」。
    await tester.tap(find.byKey(const Key('repay_from_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '无账户（代还）'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // 欠款被抵消，且没有从任何账户扣款（转账 accountId 为空）。
    expect(controller.accountBalance(card), 0);
    final repayment = controller.entries.firstWhere(
      (entry) =>
          entry.type == EntryType.transfer && entry.toAccountId == card.id,
    );
    expect(repayment.accountId, '');
    expect(repayment.amount, 300);
  });
}
