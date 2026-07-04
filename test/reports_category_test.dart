import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('看板分类统计按层级聚合到顶级分类', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final diningId = controller.categories
        .firstWhere((c) => c.label == '餐饮')
        .id;
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = controller.categories
        .firstWhere((c) => c.label == '咖啡')
        .id;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'coffee-report',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 40,
          categoryId: coffeeId,
          accountId: 'cash-report',
          note: '拿铁',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2);
    await tester.pumpAndSettle();

    // 咖啡（子分类）的支出滚动计入顶级「餐饮」，看板不单列子分类。
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('咖啡'), findsNothing);
  });

  testWidgets('看板标签统计展示各标签支出', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final tagId = controller.addTag('必要')!;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'tag-report',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 60,
          categoryId: 'dining',
          accountId: 'cash-report',
          note: '',
          occurredAt: now,
          tagIds: <String>[tagId],
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2);
    await tester.pumpAndSettle();

    // 标签统计面板在看板底部，滚动到可见。
    await tester.scrollUntilVisible(
      find.text('必要'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('标签统计'), findsWidgets);
    expect(find.text('必要'), findsOneWidget);
    expect(find.textContaining('占支出'), findsWidgets);
  });
}
