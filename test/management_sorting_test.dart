import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/tag_management_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('标签拖动只改排序草稿，点击软碟后才提交', (tester) async {
    final controller = await makeController();
    controller
      ..addTag('工作')
      ..addTag('旅行');
    await tester.binding.setSurfaceSize(const Size(460, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const TagManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('保存'), findsOneWidget);
    final handles = find.byIcon(Icons.drag_handle);
    final firstHandle = tester.getCenter(handles.at(0));
    final secondHandle = tester.getCenter(handles.at(1));
    await tester.timedDragFrom(
      firstHandle,
      Offset(0, secondHandle.dy - firstHandle.dy + 30),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(controller.tags.map((tag) => tag.label), <String>['工作', '旅行']);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.tags.map((tag) => tag.label), <String>['旅行', '工作']);
  });

  test('分类、标签、账户分组排序草稿保存后可重载', () async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);

    final categories = List<Category>.of(controller.categories);
    final firstExpense = categories.indexWhere(
      (category) =>
          category.type == EntryType.expense && category.parentId == null,
    );
    final secondExpense = categories.indexWhere(
      (category) =>
          category.type == EntryType.expense &&
          category.parentId == null &&
          categories.indexOf(category) > firstExpense,
    );
    final categoryOrder = categories.map((category) => category.id).toList();
    final movedCategory = categoryOrder.removeAt(secondExpense);
    categoryOrder.insert(firstExpense, movedCategory);
    expect(await controller.saveCategoryOrderDraft(categoryOrder), isTrue);

    controller
      ..addTag('工作')
      ..addTag('旅行')
      ..addAccountGroup('日常')
      ..addAccountGroup('信用');
    await controller.waitForPendingWrites();
    expect(
      await controller.saveTagOrderDraft(
        controller.tags.reversed.map((tag) => tag.id).toList(),
      ),
      isTrue,
    );
    expect(
      await controller.saveAccountGroupOrderDraft(
        controller.accountGroups.reversed.map((group) => group.id).toList(),
      ),
      isTrue,
    );

    final reloaded = await makeController(store);
    expect(reloaded.categories[firstExpense].id, movedCategory);
    expect(reloaded.tags.map((tag) => tag.label), <String>['旅行', '工作']);
    expect(reloaded.accountGroups.map((group) => group.name), <String>[
      '信用',
      '日常',
    ]);
  });
}
