import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/transaction_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<VeriFinController> setup() async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bank = Account(
      id: 'bank',
      bookId: controller.activeBook.id,
      name: '储蓄卡',
      type: AccountType.debitCard,
      groupId: null,
      initialBalance: 1000,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'CNY',
    );
    final card = Account(
      id: 'usd-card',
      bookId: controller.activeBook.id,
      name: '美元信用卡',
      type: AccountType.creditCard,
      groupId: null,
      initialBalance: 0,
      iconCode: 'credit',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: 'USD',
    );
    controller
      ..addAccount(bank)
      ..addAccount(card);
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime(2026, 1, 1),
      rateToBase: 7.0,
    );
    return controller;
  }

  LedgerEntry noAccountTransfer(VeriFinController controller) {
    final categoryId = controller
        .categoriesForType(EntryType.transfer)
        .first
        .id;
    return LedgerEntry(
      id: 'transfer-1',
      bookId: controller.activeBook.id,
      type: EntryType.transfer,
      amount: 100,
      currencyCode: 'CNY',
      toAccountAmount: 100,
      baseAmount: 0,
      categoryId: categoryId,
      accountId: '',
      toAccountId: 'bank',
      note: '',
      occurredAt: DateTime(2026, 1, 1),
    );
  }

  testWidgets('无账户转账转入外币账户：币种跟随转入账户并可保存', (tester) async {
    final controller = await setup();
    addTearDown(controller.dispose);
    controller.addEntry(noAccountTransfer(controller));

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: TransactionDetailPage(entryId: 'transfer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 把转入账户从储蓄卡(CNY)切换为美元信用卡(USD)。
    await tester.tap(find.text('转入账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('美元信用卡'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final saved = controller.entries.firstWhere((e) => e.id == 'transfer-1');
    expect(saved.currencyCode, 'USD');
    expect(saved.toAccountId, 'usd-card');
    expect(saved.accountId, '');
    expect(saved.toAccountAmount, 100);
  });

  testWidgets('无账户转账不显示手续费字段', (tester) async {
    final controller = await setup();
    addTearDown(controller.dispose);
    controller.addEntry(noAccountTransfer(controller));

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: TransactionDetailPage(entryId: 'transfer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手续费'), findsNothing);
    expect(find.text('无账户'), findsOneWidget);
  });
}
