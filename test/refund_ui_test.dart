import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/transaction_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('支出详情：添加退款后显示退款、净额归零', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'cash',
          bookId: bookId,
          name: '现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 1000,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'e1',
          bookId: bookId,
          type: EntryType.expense,
          amount: 100,
          categoryId: 'dining',
          accountId: 'cash',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
        ),
      );

    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'e1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 退款区初始为空。
    expect(find.text('暂无退款，点下方添加'), findsOneWidget);

    // 点「添加退款」→ 弹窗默认填满剩余（100）且已到账 → 保存。
    await tester.tap(find.text('添加退款'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 生成一条已到账退款、净额归零、原账户余额 = 1000 − 100 + 100 = 1000。
    final refunds = controller.refundsForEntry('e1');
    expect(refunds.length, 1);
    expect(refunds.single.amount, 100);
    expect(refunds.single.settledAt, isNotNull);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 0);
    final cash = controller.accounts.firstWhere((a) => a.id == 'cash');
    expect(controller.accountBalance(cash), 1000);
  });

  testWidgets('退款不在普通类型选择器里出现', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller.addEntry(
      LedgerEntry(
        id: 'e2',
        bookId: bookId,
        type: EntryType.expense,
        amount: 50,
        categoryId: 'dining',
        accountId: '',
        note: '',
        occurredAt: DateTime(2026, 7, 4),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'e2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开类型选择器：只有支出/收入/转账，没有「退款」。
    await tester.tap(find.text('类型'));
    await tester.pumpAndSettle();
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.text('转账'), findsWidgets);
    // 「退款」不作为可选类型（选项弹窗里不出现）。
    expect(find.widgetWithText(ListTile, '退款'), findsNothing);
  });
}
