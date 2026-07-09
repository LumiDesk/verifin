import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('看板可进入统计分析页并切换维度与范围', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller
      ..addEntry(
        LedgerEntry(
          id: 'exp-1',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 120,
          categoryId: 'dining',
          accountId: 'cash-report',
          note: '',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'inc-1',
          bookId: controller.activeBook.id,
          type: EntryType.income,
          amount: 5000,
          categoryId: 'salary',
          accountId: 'cash-report',
          note: '',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2);
    await tester.pumpAndSettle();

    // 打开统计分析页。
    await tester.tap(find.byTooltip('统计分析'));
    await tester.pumpAndSettle();

    expect(find.text('统计分析'), findsOneWidget);
    expect(find.text('收支概览'), findsOneWidget);
    // 本月范围显示同比/环比对比卡。
    expect(find.text('同比 · 环比'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('分类排行'),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    // 默认支出维度显示餐饮分类。
    expect(find.text('餐饮'), findsWidgets);

    // 切换到收入维度，分类排行显示工资。（「收入」同时出现在概览标签与维度切换，取切换段）
    await tester.tap(find.text('收入').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('工资'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('工资'), findsWidgets);

    // 切换到本年范围（不显示同比/环比卡）。
    await tester.scrollUntilVisible(
      find.text('本年'),
      -250,
      scrollable: scrollable,
    );
    await tester.tap(find.text('本年'));
    await tester.pumpAndSettle();
    // 回到顶部（头部标题带出副标题）确认范围标签更新为年份，且同比/环比卡消失。
    await tester.scrollUntilVisible(
      find.text('统计分析'),
      -250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('${now.year}年'), findsWidgets);
    expect(find.text('同比 · 环比'), findsNothing);
  });

  testWidgets('统计分析页可切换分类/子分类/标签维度并下钻', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    // 在「餐饮」下建子分类「午餐」。
    controller.addCategory(
      type: EntryType.expense,
      label: '午餐',
      iconCode: 'dining',
      parentId: 'dining',
    );
    final lunchId = controller.categories.firstWhere((c) => c.label == '午餐').id;
    final tagId = controller.addTag('工作')!;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'sub-1',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 60,
          categoryId: lunchId,
          accountId: '',
          note: '',
          occurredAt: now,
          tagIds: <String>[tagId],
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('统计分析'));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    // 切到「子分类」维度 → 出现「午餐」。
    await tester.scrollUntilVisible(
      find.text('子分类'),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.text('子分类'));
    await tester.pumpAndSettle();
    expect(find.text('午餐'), findsWidgets);

    // 切到「标签」维度 → 出现标签「工作」与排行标题。
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('标签排行'), findsOneWidget);
    expect(find.text('工作'), findsWidgets);

    // 回「分类」维度，点「餐饮」行下钻 → 弹层出现「午餐」。
    await tester.tap(find.text('分类').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('餐饮'),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('的子分类'), findsOneWidget);
    expect(find.text('午餐'), findsWidgets);
  });
}
