import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

void main() {
  final categories = <Category>[
    const Category(
      id: 'dining',
      label: '餐饮',
      type: EntryType.expense,
      iconCode: 'dining',
    ),
    const Category(
      id: 'coffee',
      label: '咖啡',
      type: EntryType.expense,
      iconCode: 'dining',
      parentId: 'dining',
    ),
    const Category(
      id: 'shopping',
      label: '购物',
      type: EntryType.expense,
      iconCode: 'shopping',
    ),
  ];

  Future<String?> openPicker(
    WidgetTester tester, {
    String selectedId = 'dining',
    bool expandedByDefault = false,
  }) async {
    String? result;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => CategoryPickerSheet(
                      categories: categories,
                      selectedId: selectedId,
                      expandedByDefault: expandedByDefault,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('默认收起父分类，未选中路径的子分类不显示', (tester) async {
    await openPicker(tester);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
    expect(find.text('咖啡'), findsNothing);
    // 「餐饮」尾部是折叠箭头。
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('点击展开箭头显示子分类', (tester) async {
    await openPicker(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('偏好开启时默认展开所有父分类', (tester) async {
    await openPicker(tester, expandedByDefault: true);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('已选项的祖先路径自动展开', (tester) async {
    await openPicker(tester, selectedId: 'coffee');
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });

  testWidgets('点选子分类返回其 id', (tester) async {
    String? picked;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => CategoryPickerSheet(
                      categories: categories,
                      selectedId: 'coffee',
                      expandedByDefault: false,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('咖啡'));
    await tester.pumpAndSettle();
    expect(picked, 'coffee');
  });
}
