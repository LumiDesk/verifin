import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/chart_painters.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Finder inCategoryCard(Finder matching) => find.descendant(
    of: find.byKey(const Key('category_stats_card')),
    matching: matching,
  );

  Future<void> scrollToCategoryStats(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('category_stats_card')),
      250,
      scrollable: firstVerticalScrollable(),
    );
    await tester.pumpAndSettle();
  }

  String centerText(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('分类统计按顶级分类聚合，默认显示合计并可点选分段', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final diningId = controller.categories
        .firstWhere((category) => category.label == '餐饮')
        .id;
    final transportId = controller.categories
        .firstWhere((category) => category.label == '交通')
        .id;
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = controller.categories
        .firstWhere((category) => category.label == '咖啡')
        .id;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-coffee',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 40,
          categoryId: coffeeId,
          accountId: '',
          note: '拿铁',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-transport',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 60,
          categoryId: transportId,
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    final card = find.byKey(const Key('category_stats_card'));
    // 子分类的支出滚动计入顶级「餐饮」，卡片里不单列「咖啡」。
    expect(inCategoryCard(find.text('餐饮')), findsOneWidget);
    expect(inCategoryCard(find.text('咖啡')), findsNothing);
    expect(inCategoryCard(find.text('交通')), findsOneWidget);
    // 只有两个分类，没有可切换的「其他」范围。
    expect(find.byKey(const Key('category_stats_range_top5')), findsNothing);
    expect(inCategoryCard(find.text('前5')), findsNothing);

    // 中心默认显示合计 100；点圆环右侧第一段（金额最大的交通）后显示明细。
    expect(
      centerText(tester, 'category_stats_center_total'),
      startsWith('100'),
    );
    final chart = find.byType(VeriDonutChart);
    final center = tester.getCenter(chart);
    await tester.tapAt(center + const Offset(70, 0));
    await tester.pumpAndSettle();

    expect(centerText(tester, 'category_stats_center_label'), '交通');
    expect(
      centerText(tester, 'category_stats_center_amount'),
      startsWith('60'),
    );
    expect(centerText(tester, 'category_stats_center_percent'), '60.0%');

    // 再点同一段取消；中心恢复合计，不留下上一条分类。
    await tester.tapAt(center + const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('category_stats_center_total')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('category_stats_center_label')), findsNothing);
    expect(card, findsOneWidget);
  });

  testWidgets('分类统计默认前5合并其他，可切换全部且清空选中', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    const labels = <String>['餐饮', '交通', '购物', '居住', '娱乐', '医疗'];
    const amounts = <double>[60, 50, 40, 30, 20, 10];
    for (var i = 0; i < labels.length; i++) {
      final categoryId = controller.categories
          .firstWhere((category) => category.label == labels[i])
          .id;
      controller.addEntry(
        LedgerEntry(
          id: 'category-stats-$i',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: amounts[i],
          categoryId: categoryId,
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      );
    }
    controller.dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    final card = find.byKey(const Key('category_stats_card'));
    expect(find.byKey(const Key('category_stats_range_top5')), findsOneWidget);
    expect(inCategoryCard(find.text('其他')), findsOneWidget);
    expect(inCategoryCard(find.text('医疗')), findsNothing);

    // 选中第一段后切到全部：选中被清空，所有分类各自成段，其他消失。
    final chart = find.byType(VeriDonutChart);
    final center = tester.getCenter(chart);
    await tester.tapAt(center + const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('category_stats_center_label')),
      findsOneWidget,
    );

    await tester.tap(inCategoryCard(find.text('全部')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category_stats_range_all')), findsOneWidget);
    expect(
      find.byKey(const Key('category_stats_center_total')),
      findsOneWidget,
    );
    expect(inCategoryCard(find.text('其他')), findsNothing);
    for (final label in labels) {
      expect(inCategoryCard(find.text(label)), findsOneWidget);
    }

    await tester.tap(inCategoryCard(find.text('前5')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category_stats_range_top5')), findsOneWidget);
    expect(inCategoryCard(find.text('其他')), findsOneWidget);
    expect(inCategoryCard(find.text('医疗')), findsNothing);
    expect(card, findsOneWidget);
  });

  testWidgets('分类统计按实际支出口径，包含不计入预算的支出', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final diningId = controller.categories
        .firstWhere((category) => category.label == '餐饮')
        .id;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-counted',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 30,
          categoryId: diningId,
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-excluded',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 20,
          categoryId: diningId,
          accountId: '',
          note: '',
          occurredAt: now,
          excludedFromBudget: true,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    // 预算执行卡排除这 20；分类统计是实际支出，必须仍为 50。
    expect(centerText(tester, 'category_stats_center_total'), startsWith('50'));
  });

  testWidgets('分类统计随月份切换取数，并清空上个月的分段选中', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final diningId = controller.categories
        .firstWhere((category) => category.label == '餐饮')
        .id;
    final transportId = controller.categories
        .firstWhere((category) => category.label == '交通')
        .id;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-this-month',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 10,
          categoryId: diningId,
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'category-stats-last-month',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 20,
          categoryId: transportId,
          accountId: '',
          note: '',
          occurredAt: DateTime(lastMonth.year, lastMonth.month, 12),
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    expect(centerText(tester, 'category_stats_center_total'), startsWith('10'));
    expect(inCategoryCard(find.text('餐饮')), findsOneWidget);

    // 先选中本月分类，再翻到上个月；中心必须回到合计，不能保留旧分类。
    final chart = find.byType(VeriDonutChart);
    await tester.tapAt(tester.getCenter(chart) + const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('category_stats_center_label')),
      findsOneWidget,
    );

    await tester.drag(firstVerticalScrollable(), const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    expect(centerText(tester, 'category_stats_center_total'), startsWith('20'));
    expect(find.byKey(const Key('category_stats_center_label')), findsNothing);
    expect(inCategoryCard(find.text('交通')), findsOneWidget);
    expect(inCategoryCard(find.text('餐饮')), findsNothing);
  });

  testWidgets('分类统计在 360dp 与全部模式下不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 852);
    addTearDown(tester.view.reset);
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    const labels = <String>['餐饮', '交通', '购物', '居住', '娱乐', '医疗'];
    for (var i = 0; i < labels.length; i++) {
      final categoryId = controller.categories
          .firstWhere((category) => category.label == labels[i])
          .id;
      controller.addEntry(
        LedgerEntry(
          id: 'category-stats-narrow-$i',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 100.0 - i * 10,
          categoryId: categoryId,
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      );
    }
    controller.dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);
    await tester.tap(inCategoryCard(find.text('全部')).first);
    await tester.pumpAndSettle();

    expect(inCategoryCard(find.text('其他')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类统计无支出时显示空态', (tester) async {
    final store = LocalKeyValueStore();
    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await scrollToCategoryStats(tester);

    expect(inCategoryCard(find.text('暂无支出数据')), findsOneWidget);
    expect(find.byType(VeriDonutChart), findsNothing);
  });

  testWidgets('看板排行卡的标签分组展示各标签支出', (WidgetTester tester) async {
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
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();

    // 期间栏占了页面顶部一行，排行卡在 800dp 测试视口里落到首屏之外，
    // 先滚到卡片再操作它内部的分组切换。
    await tester.scrollUntilVisible(
      find.text('分类 · 标签排行'),
      250,
      scrollable: firstVerticalScrollable(),
    );
    await tester.pumpAndSettle();

    // 排行卡默认按顶级分类分组，切到「标签」分组。
    await tester.tap(find.text('标签').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('必要'),
      250,
      scrollable: firstVerticalScrollable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('分类 · 标签排行'), findsWidgets);
    expect(find.text('必要'), findsOneWidget);
    // 多标签会重复计入，占比之和可能超过 100%，卡片里必须带这条说明。
    expect(find.textContaining('超过 100%'), findsWidgets);
  });
}
