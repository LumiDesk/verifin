import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/attachments_editor.dart';
import 'package:verifin/pages/entry_detail_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('快速记账使用优化类型切换和无分割线底部保存', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 30)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('entry_type_segmented_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('entry_type_selected_expense')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.save_outlined), findsNothing);
    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
    expect(
      tester
          .widget<Padding>(find.byKey(const Key('entry_bottom_save_padding')))
          .padding,
      const EdgeInsets.fromLTRB(22, 10, 22, 18),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('entry_bottom_save_bar')),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<CategoryGlyph>(
            find.descendant(
              of: find.byKey(const Key('entry_category_dining')),
              matching: find.byType(CategoryGlyph),
            ),
          )
          .color,
      veriExpense,
    );

    await tester.tap(find.byKey(const Key('entry_type_income')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_type_selected_income')), findsOneWidget);
    expect(
      tester
          .widget<CategoryGlyph>(
            find.descendant(
              of: find.byKey(const Key('entry_category_salary')),
              matching: find.byType(CategoryGlyph),
            ),
          )
          .color,
      veriIncome,
    );

    await tester.tap(find.byKey(const Key('entry_type_transfer')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CategoryGlyph>(
            find.descendant(
              of: find.byKey(const Key('entry_category_transfer_out')),
              matching: find.byType(CategoryGlyph),
            ),
          )
          .color,
      veriBlue,
    );
  });

  testWidgets('更多信息收纳日期时间标签报销附件与币种', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1100);
    addTearDown(tester.view.reset);

    final controller = await makeController();
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 30)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更多信息'), findsOneWidget);
    expect(find.byKey(const Key('entry_metadata_date')), findsOneWidget);
    expect(find.byKey(const Key('entry_metadata_time')), findsOneWidget);
    expect(find.byKey(const Key('entry_metadata_tags')), findsOneWidget);
    expect(
      find.byKey(const Key('entry_metadata_reimbursable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('entry_metadata_attachments')), findsOneWidget);
    expect(find.byKey(const Key('entry_currency_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('entry_metadata_tags')));
    await tester.pumpAndSettle();
    expect(find.byType(TagSelectorSheet), findsOneWidget);
  });

  testWidgets('紧凑附件条展示多张图片和小型删除按钮', (tester) async {
    const image =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final removed = <int>[];

    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: AttachmentsEditor(
            dataUrls: const <String>[image, image, image],
            onAddDataUrl: (_) {},
            onRemoveIndex: removed.add,
            showHeader: false,
            showAddButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片附件'), findsNothing);
    expect(find.byKey(const Key('attachment_remove_visual_0')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('attachment_remove_visual_0'))),
      const Size(16, 16),
    );

    await tester.tap(find.byKey(const Key('attachment_remove_visual_1')));
    expect(removed, <int>[1]);
  });
}
