import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/reports_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('看板排行下钻的交易列表沿用当前统计期间', (tester) async {
    // 月统计面板较多，用更高的画布保证排行卡片完整落在视口内。
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = await makeController();
    addTearDown(controller.dispose);
    final bookId = controller.activeBook.id;
    final now = DateTime.now();
    controller
      ..addEntry(
        LedgerEntry(
          id: 'current-month',
          bookId: bookId,
          type: EntryType.expense,
          amount: 100,
          categoryId: 'dining',
          accountId: 'cash',
          note: '本月餐饮',
          occurredAt: DateTime(now.year, now.month, 1, 12),
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'previous-month',
          bookId: bookId,
          type: EntryType.expense,
          amount: 50,
          categoryId: 'dining',
          accountId: 'cash',
          note: '上月餐饮',
          occurredAt: DateTime(now.year, now.month - 1, 15, 12),
        ),
      );

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        // ReportsPage 自身不提供 Scaffold，单独 pump 时补一层。
        child: zhMaterialApp(home: const Scaffold(body: ReportsPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('月统计'));
    await tester.pumpAndSettle();

    // 排行卡在月统计底部，滚到「餐饮」这一行再点，进入子分类弹层。
    final dining = controller
        .categoriesForType(EntryType.expense)
        .firstWhere((category) => category.label == '餐饮');
    final diningRow = find.byKey(Key('ranking_row_${dining.id}'));
    await tester.scrollUntilVisible(
      diningRow,
      300,
      scrollable: firstVerticalScrollable(),
    );
    await tester.tap(diningRow);
    await tester.pumpAndSettle();
    expect(find.text('「餐饮」的子分类'), findsOneWidget);

    await tester.tap(find.text('查看交易'));
    await tester.pumpAndSettle();

    // 列表只含所选月份的餐饮交易，上个月的不再混进来。
    expect(find.text('本月餐饮'), findsOneWidget);
    expect(find.text('上月餐饮'), findsNothing);
  });
}
