import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/pending_refunds_page.dart';
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

  testWidgets('待退款清单：显示待到账退款并可标记已到账', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final bookId = controller.activeBook.id;
    controller.addEntry(
      LedgerEntry(
        id: 'e3',
        bookId: bookId,
        type: EntryType.expense,
        amount: 100,
        categoryId: 'dining',
        accountId: '',
        note: '退货订单',
        occurredAt: DateTime(2026, 7, 4),
      ),
    );
    // 待到账退款（settledAt 为 null）。
    controller.addRefund(
      expenseId: 'e3',
      amount: 40,
      accountId: '',
      initiatedAt: DateTime(2026, 7, 4),
    );
    expect(controller.pendingRefunds.length, 1);

    await tester.binding.setSurfaceSize(const Size(460, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const PendingRefundsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('退货订单'), findsOneWidget);
    expect(find.text('标记已到账'), findsOneWidget);

    await tester.tap(find.text('标记已到账'));
    await tester.pumpAndSettle();

    // 核销后不再是待退款，且原支出净额降为 60。
    expect(controller.pendingRefunds, isEmpty);
    expect(controller.entries.firstWhere((e) => e.id == 'e3').netAmount, 60);
  });

  testWidgets('添加退款：数字键盘显示「最多」上限并当场封顶', (WidgetTester tester) async {
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
          id: 'e4',
          bookId: bookId,
          type: EntryType.expense,
          amount: 200,
          categoryId: 'dining',
          accountId: 'cash',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
        ),
      );
    // 先退 50 → 剩余可退 150。
    controller.addRefund(
      expenseId: 'e4',
      amount: 50,
      accountId: 'cash',
      initiatedAt: DateTime(2026, 7, 4),
      settledAt: DateTime(2026, 7, 5),
    );

    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'e4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开添加退款弹窗：默认金额=剩余可退 150。
    await tester.tap(find.text('添加退款'));
    await tester.pumpAndSettle();
    expect(find.text('+150'), findsOneWidget);

    // 点大金额进数字键盘 → 清空 → 输 999（超上限）。
    await tester.tap(find.text('+150'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number_key_C')));
    await tester.tap(find.byKey(const Key('number_key_9')));
    await tester.tap(find.byKey(const Key('number_key_9')));
    await tester.tap(find.byKey(const Key('number_key_9')));
    await tester.pump();
    // 数字键盘里显示「最多 150」。
    expect(find.text('最多 150'), findsOneWidget);

    // 确认 → 封顶为 150 回到退款弹窗（不是 999）。
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();
    expect(find.text('+150'), findsOneWidget);
    expect(find.text('+999'), findsNothing);
  });
}
