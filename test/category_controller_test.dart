import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  String idOfLabel(VeriFinController controller, String label) {
    return controller.categories.firstWhere((c) => c.label == label).id;
  }

  test('addCategory 带 parentId 创建子分类并继承父类型', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮'); // expense 顶级
    controller.addCategory(
      type: EntryType.income, // 传入的类型应被父分类覆盖
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffee = controller.categories.firstWhere((c) => c.label == '咖啡');
    expect(coffee.parentId, diningId);
    expect(coffee.type, EntryType.expense);
    expect(
      controller.childCategories(diningId).map((c) => c.label),
      contains('咖啡'),
    );
  });

  test('addCategory 父分类不存在时不创建', () async {
    final controller = await makeController();
    final before = controller.categories.length;
    controller.addCategory(
      type: EntryType.expense,
      label: '幽灵',
      iconCode: 'category',
      parentId: 'not-exist',
    );
    expect(controller.categories.length, before);
  });

  test('moveCategory 移动到新父级、移到顶级', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    final shoppingId = idOfLabel(controller, '购物');
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = idOfLabel(controller, '咖啡');

    expect(controller.moveCategory(coffeeId, shoppingId), isTrue);
    expect(controller.categoryById(coffeeId).parentId, shoppingId);

    // 移到顶级。
    expect(controller.moveCategory(coffeeId, null), isTrue);
    expect(controller.categoryById(coffeeId).parentId, isNull);
  });

  test('moveCategory 阻止成环与跨类型', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    final salaryId = idOfLabel(controller, '工资'); // income
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = idOfLabel(controller, '咖啡');

    // 不能把父分类移动到自己的后代之下（成环）。
    expect(controller.moveCategory(diningId, coffeeId), isFalse);
    // 不能移到自身。
    expect(controller.moveCategory(diningId, diningId), isFalse);
    // 不能跨类型（expense 子分类挂到 income 父分类下）。
    expect(controller.moveCategory(coffeeId, salaryId), isFalse);
  });

  test('reorderCategories 只在同级兄弟间重排', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    controller.addCategory(
      type: EntryType.expense,
      label: '早餐',
      iconCode: 'dining',
      parentId: diningId,
    );
    controller.addCategory(
      type: EntryType.expense,
      label: '晚餐',
      iconCode: 'dining',
      parentId: diningId,
    );
    expect(
      controller.childCategories(diningId).map((c) => c.label).toList(),
      <String>['早餐', '晚餐'],
    );
    controller.reorderCategories(EntryType.expense, diningId, 1, 0);
    expect(
      controller.childCategories(diningId).map((c) => c.label).toList(),
      <String>['晚餐', '早餐'],
    );
  });

  test('deleteCategory 有子分类时被拦截', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = idOfLabel(controller, '咖啡');

    expect(controller.deleteCategory(diningId), isFalse);
    // 先删子分类，父分类才能删。
    expect(controller.deleteCategory(coffeeId), isTrue);
    expect(controller.deleteCategory(diningId), isTrue);
    expect(controller.categories.any((c) => c.id == diningId), isFalse);
  });

  test('deleteCategory 清理关联的分类预算', () async {
    final controller = await makeController();
    final month = DateTime(2026, 7);
    controller.addCategory(
      type: EntryType.expense,
      label: '临时',
      iconCode: 'category',
    );
    final tempId = idOfLabel(controller, '临时');
    controller.setCategoryBudget(month, tempId, 200);
    expect(controller.categoryBudget(month, tempId), 200);

    expect(controller.deleteCategory(tempId), isTrue);
    expect(controller.categoryBudget(month, tempId), 0);
  });

  LedgerEntry expenseEntry(
    VeriFinController controller,
    String id,
    String categoryId,
  ) {
    return LedgerEntry(
      id: id,
      bookId: controller.activeBook.id,
      type: EntryType.expense,
      amount: 10,
      categoryId: categoryId,
      accountId: '',
      note: '',
      occurredAt: DateTime(2026, 7, 1),
    );
  }

  test('mergeCategoryInto 把源分类交易并入目标并删除源分类', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    final shoppingId = idOfLabel(controller, '购物');
    controller.addEntry(expenseEntry(controller, 'm1', shoppingId));
    controller.addEntry(expenseEntry(controller, 'm2', shoppingId));
    controller.addEntry(expenseEntry(controller, 'm3', diningId));

    final moved = controller.mergeCategoryInto(shoppingId, diningId);
    expect(moved, 2);
    // 源分类被删除，其交易全部改指向目标。
    expect(controller.categories.any((c) => c.id == shoppingId), isFalse);
    expect(controller.entries.where((e) => e.categoryId == diningId).length, 3);
    expect(controller.entries.any((e) => e.categoryId == shoppingId), isFalse);
  });

  test('mergeCategoryInto 拦截：源有子分类 / 目标是源后代 / 自身', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    final shoppingId = idOfLabel(controller, '购物');
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final coffeeId = idOfLabel(controller, '咖啡');

    // 源有子分类：不能合并。
    expect(controller.mergeCategoryInto(diningId, shoppingId), -1);
    // 目标是源的后代：不能合并。
    expect(controller.mergeCategoryInto(diningId, coffeeId), -1);
    // 合并到自身：不能。
    expect(controller.mergeCategoryInto(shoppingId, shoppingId), -1);
    // 分类均未被改动。
    expect(controller.categories.any((c) => c.id == diningId), isTrue);
    expect(controller.categories.any((c) => c.id == shoppingId), isTrue);
  });

  test('mergeCategoryInto 清理源分类的分类预算', () async {
    final controller = await makeController();
    final month = DateTime(2026, 7);
    final diningId = idOfLabel(controller, '餐饮');
    final shoppingId = idOfLabel(controller, '购物');
    controller.setCategoryBudget(month, shoppingId, 300);
    expect(controller.categoryBudget(month, shoppingId), 300);

    expect(controller.mergeCategoryInto(shoppingId, diningId) >= 0, isTrue);
    expect(controller.categoryBudget(month, shoppingId), 0);
  });

  test('categoryTreeForType 前序展开携带深度', () async {
    final controller = await makeController();
    final diningId = idOfLabel(controller, '餐饮');
    controller.addCategory(
      type: EntryType.expense,
      label: '咖啡',
      iconCode: 'dining',
      parentId: diningId,
    );
    final tree = controller.categoryTreeForType(EntryType.expense);
    final coffeeNode = tree.firstWhere((n) => n.category.label == '咖啡');
    final diningNode = tree.firstWhere((n) => n.category.label == '餐饮');
    expect(diningNode.depth, 0);
    expect(coffeeNode.depth, 1);
    // 子分类紧跟在父分类之后。
    final diningIdx = tree.indexOf(diningNode);
    expect(tree[diningIdx + 1].category.label, '咖啡');
    expect(controller.categoryPathLabel(coffeeNode.category.id), '餐饮 / 咖啡');
  });
}
