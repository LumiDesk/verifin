import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/pending_refunds_page.dart';
import 'package:verifin/pages/refund_editor.dart';
import 'package:verifin/pages/transaction_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('支出详情：退款先留在草稿，保存交易后原子落库并可重载', (WidgetTester tester) async {
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

    // 退款弹窗确认后，交易页自动保存聚合草稿。
    expect(controller.refundsForEntry('e1'), isNotEmpty);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 0);

    // 生成一条已到账退款、净额归零、原账户余额 = 1000 − 100 + 100 = 1000。
    final refunds = controller.refundsForEntry('e1');
    expect(refunds.length, 1);
    expect(refunds.single.amount, 100);
    expect(refunds.single.settledAt, isNotNull);
    expect(controller.entries.firstWhere((e) => e.id == 'e1').netAmount, 0);
    final cash = controller.accounts.firstWhere((a) => a.id == 'cash');
    expect(controller.accountBalance(cash), 1000);

    // 模拟进程重启，确保不是只改了内存状态。
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    final reloaded = await makeController(store);
    expect(reloaded.refundsForEntry('e1').single.amount, 100);
    expect(reloaded.entries.firstWhere((e) => e.id == 'e1').netAmount, 0);
    reloaded.dispose();
  });

  testWidgets('已有部分退款时，默认剩余金额可保存', (WidgetTester tester) async {
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
          id: 'partial-refund-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 250.89,
          categoryId: 'dining',
          accountId: 'cash',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
        ),
      );
    for (final amount in <double>[50, 50, 51, 51]) {
      controller.addRefund(
        expenseId: 'partial-refund-expense',
        amount: amount,
        accountId: 'cash',
        initiatedAt: DateTime(2026, 7, 4),
        settledAt: DateTime(2026, 7, 5),
      );
    }

    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'partial-refund-expense'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认剩余可退必须是 48.89，而不是 48.889999…；确认后自动保存。
    await tester.tap(find.text('添加退款'));
    await tester.pumpAndSettle();
    expect(find.text('+48.89'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(controller.refundsForEntry('partial-refund-expense').length, 5);
    expect(
      controller.entries
          .firstWhere((entry) => entry.id == 'partial-refund-expense')
          .netAmount,
      0,
    );
    expect(find.text('交易金额、币种或关联数据不完整，请检查后重试。'), findsNothing);
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
    expect(
      find.byKey(
        const ValueKey<String>(
          'anchored_menu_item_transaction_detail_type_income',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.text('转账'), findsWidgets);
    // 「退款」不作为可选类型（选项弹窗里不出现）。
    expect(find.widgetWithText(ListTile, '退款'), findsNothing);
  });

  testWidgets('存在关联退款时交易类型入口锁定', (WidgetTester tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    final bookId = controller.activeBook.id;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'locked-expense',
          bookId: bookId,
          type: EntryType.expense,
          amount: 50,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
          refundedBaseAmount: 10,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'linked-refund',
          bookId: bookId,
          type: EntryType.refund,
          amount: 10,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(2026, 7, 5),
          refundOf: 'locked-expense',
          settledAt: DateTime(2026, 7, 5),
          baseAmount: 10,
        ),
      );

    await tester.binding.setSurfaceSize(const Size(460, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: const TransactionDetailPage(entryId: 'locked-expense'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_type_choice')), findsNothing);
    await tester.tap(find.text('类型'));
    await tester.pumpAndSettle();
    expect(find.text('收入'), findsNothing);
  });

  testWidgets('已有跨账户外币退款只改发起日期时保持实际到账金额', (WidgetTester tester) async {
    final controller = await makeController();
    final bookId = controller.activeBook.id;
    controller
      ..addAccount(
        Account(
          id: 'usd-refund-account',
          bookId: bookId,
          name: '美元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'USD',
        ),
      )
      ..addAccount(
        Account(
          id: 'eur-refund-account',
          bookId: bookId,
          name: '欧元现金',
          type: AccountType.cash,
          groupId: null,
          initialBalance: 100,
          iconCode: 'cash',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: 'EUR',
        ),
      );
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime(2026, 1, 1),
      rateToBase: 7.2,
    );
    await controller.saveExchangeRateDraft(
      currencyCode: 'EUR',
      effectiveDate: DateTime(2026, 1, 1),
      rateToBase: 8,
    );
    await controller.saveExchangeRateDraft(
      currencyCode: 'USD',
      effectiveDate: DateTime(2026, 1, 2),
      rateToBase: 7.5,
    );
    await controller.saveExchangeRateDraft(
      currencyCode: 'EUR',
      effectiveDate: DateTime(2026, 1, 2),
      rateToBase: 7.5,
    );
    controller.addEntry(
      LedgerEntry(
        id: 'usd-refund-expense',
        bookId: bookId,
        type: EntryType.expense,
        amount: 100,
        currencyCode: 'USD',
        accountAmount: 100,
        baseAmount: 720,
        categoryId: controller.categoriesForType(EntryType.expense).first.id,
        accountId: 'usd-refund-account',
        note: '',
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    final refund = controller.addRefund(
      expenseId: 'usd-refund-expense',
      amount: 50,
      accountId: 'eur-refund-account',
      initiatedAt: DateTime(2026, 1, 1),
      settledAt: DateTime(2026, 1, 1),
      accountAmount: 46,
      baseAmount: 360,
      conversionSource: ConversionSource.manual,
    )!;

    RefundEditResult? result;
    await tester.binding.setSurfaceSize(const Size(460, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  final expense = controller.entries.firstWhere(
                    (entry) => entry.id == 'usd-refund-expense',
                  );
                  result = await showRefundSheet(
                    context: context,
                    expense: expense,
                    refunds: controller.refundsForEntry(expense.id),
                    existing: refund,
                  );
                },
                child: const Text('打开退款'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开退款'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('发起日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.refund!.occurredAt, DateTime(2026, 1, 2));
    expect(result!.refund!.accountAmount, 46);
    expect(result!.refund!.baseAmount, 360);
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
    expect(find.text('本位币冲抵额'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 核销前再次确认实际到账/本位币冲抵额；保存后净额降为 60。
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

  testWidgets('退款弹层内容可滚动，保存按钮在小屏上也点得到', (WidgetTester tester) async {
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
          id: 'e5',
          bookId: bookId,
          type: EntryType.expense,
          amount: 200,
          categoryId: 'dining',
          accountId: 'cash',
          note: '',
          occurredAt: DateTime(2026, 7, 4),
        ),
      );

    // 矮屏：内容一屏放不下，必须能滚动到保存按钮，而不是被裁掉。
    await tester.binding.setSurfaceSize(const Size(393, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          theme: buildVeriFinTheme(Brightness.light),
          home: const TransactionDetailPage(entryId: 'e5'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 矮屏下先滚到「添加退款」入口，再打开弹层。
    await tester.scrollUntilVisible(
      find.text('添加退款'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加退款'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '保存');
    expect(saveButton, findsOneWidget);
    // 弹层内必须存在滚动容器，否则 ensureVisible 会因找不到 Scrollable 直接抛错。
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
