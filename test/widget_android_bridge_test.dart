import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/home_widget_service.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/shell.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestDatabases();
  const channel = MethodChannel('verifin/app');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('原生快照使用各组件的账本、金额和日期范围', () async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    final original = controller.activeBook.id;
    controller.addLedgerBook('旅行');
    final selected = controller.activeBook.id;
    expect(selected, isNot(original));
    controller.addEntry(
      LedgerEntry(
        id: 'real',
        bookId: selected,
        type: EntryType.expense,
        amount: 37,
        categoryId: controller.categoriesForType(EntryType.expense).first.id,
        accountId: '',
        note: '',
        occurredAt: DateTime.now(),
      ),
    );
    controller.switchLedgerBook(original);
    Map<dynamic, dynamic>? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'syncWidgetSnapshots') {
            payload = call.arguments;
          }
          return null;
        });
    await pushWidgetData(controller);
    final snapshots = payload!['snapshots'] as Map;
    final metrics = snapshots[selected] as Map;
    final presentation = metrics['periodExpense'] as Map;
    expect(presentation['amount'], contains('37'));
    expect((presentation['points'] as String).split(',').last, '37.0');
    expect(controller.activeBook.id, original);
  });

  testWidgets('冷启动点击小组件会切换所选账本并打开记账', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    final original = controller.activeBook.id;
    controller.addLedgerBook('旅行');
    final selected = controller.activeBook.id;
    controller.switchLedgerBook(original);
    var consumed = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'consumeWidgetRoute') {
        consumed++;
        return {'route': 'entry', 'bookId': selected};
      }
      if (call.method == 'consumeQuickEntryIntent') return false;
      return null;
    });
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const VeriFinShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(consumed, 1);
    expect(controller.activeBook.id, selected);
    expect(find.byKey(const Key('number_pad_ok')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('资产曲线使用净资产且缺汇率时不展示部分曲线', () async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    controller.addAccount(
      Account(
        id: 'widget-cash',
        bookId: controller.activeBook.id,
        name: '现金',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 1000,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    );
    controller.setMonthlyBudget(now, 100);
    controller.addEntry(
      LedgerEntry(
        id: 'widget-expense',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 37,
        categoryId: controller.categoriesForType(EntryType.expense).first.id,
        accountId: 'widget-cash',
        note: '',
        occurredAt: now,
      ),
    );
    Map<dynamic, dynamic>? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'updateWidgetData') {
            payload = call.arguments as Map;
          }
          return null;
        });
    await pushWidgetData(controller);
    expect(payload!['budgetUsage'], closeTo(.37, .0001));
    expect(
      double.parse((payload!['netWorthPoints'] as String).split(',').last),
      963,
    );
    expect(
      double.parse((payload!['trendPoints'] as String).split(',').last),
      37,
    );

    controller.addAccount(
      Account(
        id: 'widget-usd',
        bookId: controller.activeBook.id,
        name: 'USD',
        type: AccountType.cash,
        groupId: null,
        initialBalance: 10,
        currencyCode: 'USD',
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
      ),
    );
    await pushWidgetData(controller);
    expect(payload!['netWorthAmount'], '—');
    expect(payload!['netWorthPoints'], '');
  });
}
