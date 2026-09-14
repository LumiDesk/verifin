import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/home_widget_service.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/app/widget_config.dart';
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

  test('用户小组件定义和可展示结果会同步到原生进程', () async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    controller.addEntry(
      LedgerEntry(
        id: 'widget-entry',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 37,
        categoryId: controller.categoriesForType(EntryType.expense).first.id,
        accountId: '',
        note: '',
        occurredAt: DateTime.now(),
      ),
    );
    await controller.saveUserWidgetDefinitions([
      UserWidgetDefinition(
        id: 'design-1',
        name: '今日支出卡',
        template: WidgetTemplate.trend,
        bookId: controller.activeBook.id,
        primaryMetric: WidgetMetric.todayExpense,
        chartMetric: WidgetChartMetric.expense,
      ),
    ]);
    Map<dynamic, dynamic>? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'syncUserWidgetDefinitions') {
            payload = call.arguments;
          }
          return null;
        });

    await pushWidgetData(controller);

    final definitions = payload!['definitions'] as List;
    final definition = definitions.single as Map;
    expect(definition['id'], 'design-1');
    final presentation = definition['presentation'] as Map;
    expect(presentation['amount'], contains('37'));
    expect(presentation['label'], '今日支出');
    expect(presentation['points'], isA<List>());
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
}
