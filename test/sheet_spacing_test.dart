import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/sheets.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> openWithButton(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void expectTitleGap(WidgetTester tester, String title) {
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    final titleTop = tester.getTopLeft(find.text(title).first).dy;
    expect(titleTop - sheetTop, greaterThanOrEqualTo(8));
  }

  testWidgets('通用选项弹窗标题与弹窗边缘保持顶部间距', (tester) async {
    await openWithButton(tester, (context) async {
      await showOptionSheet<String>(
        context: context,
        title: '筛选账户',
        values: const <String>['all'],
        selected: 'all',
        labelOf: (value) => value,
      );
    });
    expectTitleGap(tester, '筛选账户');
  });

  testWidgets('分类选择弹窗标题与弹窗边缘保持顶部间距', (tester) async {
    await openWithButton(tester, (context) async {
      await showCategoryPickerSheet(
        context,
        categories: const <Category>[
          Category(
            id: 'dining',
            label: '餐饮',
            type: EntryType.expense,
            iconCode: 'dining',
          ),
        ],
        selectedId: 'dining',
        title: '筛选分类',
      );
    });
    expectTitleGap(tester, '筛选分类');
  });

  testWidgets('账户选择弹窗标题与弹窗边缘保持顶部间距', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAccountPickerSheet(
                  context: context,
                  title: '筛选账户',
                  accounts: controller.accounts,
                  selectedId: accountPickerAllId,
                  balanceOf: controller.accountBalance,
                  allLabel: '全部账户',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expectTitleGap(tester, '筛选账户');
  });
}
