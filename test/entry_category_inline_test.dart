import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/entry_detail_page.dart';

import 'support/test_harness.dart';

/// 覆盖记账页三列分类胶囊和现有多级分类选择器的组合交互。
void main() {
  useTestDatabases();

  String idOfLabel(VeriFinController controller, String label) {
    return controller.categories.firstWhere((c) => c.label == label).id;
  }

  /// 造一个带「餐饮 → 午餐 → 工作午餐」层级的控制器。
  Future<VeriFinController> controllerWithSubcategories() async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    controller
      ..addCategory(
        type: EntryType.expense,
        label: '早餐',
        iconCode: 'dining',
        parentId: diningId,
      )
      ..addCategory(
        type: EntryType.expense,
        label: '午餐',
        iconCode: 'dining',
        parentId: diningId,
      );
    final lunchId = idOfLabel(controller, '午餐');
    controller.addCategory(
      type: EntryType.expense,
      label: '工作午餐',
      iconCode: 'dining',
      parentId: lunchId,
    );
    return controller;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    VeriFinController controller,
    Widget page,
  ) async {
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('分类使用三列紧凑胶囊且子分类不常驻展开', (tester) async {
    final controller = await controllerWithSubcategories();
    await pumpPage(
      tester,
      controller,
      const EntryDetailPage(initialAmount: 30),
    );

    expect(find.byKey(const Key('entry_category_grid')), findsOneWidget);
    expect(find.text('午餐'), findsNothing);
    expect(find.text('早餐'), findsNothing);
    expect(find.byKey(const Key('entry_category_more_dining')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('entry_category_dining'))).height,
      closeTo(31, 2),
    );
  });

  testWidgets('省略号打开现有多级选择器并回填三级分类', (tester) async {
    final controller = await controllerWithSubcategories();
    await pumpPage(
      tester,
      controller,
      const EntryDetailPage(initialAmount: 30),
    );

    await tester.tap(find.byKey(const Key('entry_category_more_dining')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPickerSheet), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('工作午餐'), findsOneWidget);

    final workLunch = find.text('工作午餐');
    await tester.ensureVisible(workLunch);
    await tester.pumpAndSettle();
    await tester.tap(workLunch);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryPickerSheet), findsNothing);
    expect(find.text('工作午餐'), findsOneWidget);
    expect(find.byKey(const Key('entry_category_more_dining')), findsOneWidget);
  });

  testWidgets('编辑子分类交易时在顶级胶囊中显示叶子名称', (tester) async {
    final controller = await controllerWithSubcategories();
    final lunchId = idOfLabel(controller, '午餐');
    final entry = LedgerEntry(
      id: 'e1',
      bookId: controller.activeBook.id,
      type: EntryType.expense,
      amount: 30,
      categoryId: lunchId,
      accountId: '',
      note: '',
      occurredAt: DateTime(2026, 7, 12, 12, 0),
    );

    await pumpPage(tester, controller, EntryDetailPage.draft(entry: entry));

    expect(find.byType(CategoryPickerSheet), findsNothing);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.byKey(const Key('entry_category_more_dining')), findsOneWidget);
  });
}
