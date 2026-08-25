import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin_ui_lab/main.dart';

void main() {
  testWidgets('记一笔预览默认使用分类宫格和轻量元数据标签', (tester) async {
    await tester.pumpWidget(const VeriFinUiLabApp());

    expect(find.byKey(const Key('entry_form_preview')), findsOneWidget);
    expect(find.byKey(const Key('category_grid')), findsOneWidget);
    expect(find.byKey(const Key('category_tile_dining')), findsOneWidget);
    expect(
      find.byKey(const Key('category_branch_menu_dining')),
      findsOneWidget,
    );
    expect(find.text('早餐'), findsNothing);
    expect(find.byKey(const Key('entry_metadata_chips')), findsOneWidget);
    expect(find.byKey(const Key('metadata_date')), findsOneWidget);
    expect(find.byKey(const Key('metadata_time')), findsOneWidget);
    expect(find.byKey(const Key('metadata_tags')), findsOneWidget);
    expect(find.byKey(const Key('metadata_reimbursable')), findsOneWidget);
    expect(find.byKey(const Key('metadata_attachments')), findsOneWidget);
    expect(find.byKey(const Key('account_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('entry_note_field')), findsOneWidget);
    expect(find.byType(SelectField), findsOneWidget);
    expect(find.text('轻点修改'), findsNothing);
    expect(find.byKey(const Key('entry_preview_save')), findsNothing);
    expect(find.byKey(const Key('entry_preview_save_bottom')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('entry_preview_save_bar')),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );

    final capsule = tester.widget<Material>(
      find.byKey(const Key('category_capsule_dining')),
    );
    final badge = tester.widget<Positioned>(
      find.byKey(const Key('category_branch_badge_position_dining')),
    );
    final content = tester.widget<Row>(
      find.byKey(const Key('category_content_dining')),
    );
    expect(capsule.shape, isA<StadiumBorder>());
    expect(
      tester.getSize(find.byKey(const Key('category_tile_dining'))).height,
      lessThan(34),
    );
    expect(badge.right, -1);
    expect(badge.bottom, 0);
    expect(content.mainAxisAlignment, MainAxisAlignment.center);
  });

  testWidgets('已选父分类的省略号打开现有多级分类选择组件', (tester) async {
    await tester.pumpWidget(const VeriFinUiLabApp());

    await tester.tap(find.byKey(const Key('category_branch_menu_dining')));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryPickerSheet), findsOneWidget);
    expect(find.text('选择餐饮分类'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('工作午餐'), findsOneWidget);

    await tester.ensureVisible(find.text('工作午餐'));
    await tester.tap(find.text('工作午餐'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryPickerSheet), findsNothing);
    expect(find.text('工作午餐'), findsOneWidget);
    expect(
      find.byKey(const Key('category_branch_menu_dining')),
      findsOneWidget,
    );
  });

  testWidgets('元数据标签可渐进展开换算和附件预览', (tester) async {
    await tester.pumpWidget(const VeriFinUiLabApp());

    expect(find.byKey(const Key('currency_details_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('metadata_currency')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('currency_details_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('metadata_attachments')));
    await tester.pumpAndSettle();
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);

    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    expect(find.text('附件 1'), findsOneWidget);
    expect(find.byKey(const Key('attachment_preview_strip')), findsOneWidget);
    expect(find.byKey(const Key('attachment_preview_0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('metadata_attachments')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(find.text('附件 2'), findsOneWidget);
    expect(find.byKey(const Key('attachment_preview_1')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('attachment_remove_size_0'))),
      const Size(16, 16),
    );

    await tester.tap(find.byKey(const Key('attachment_remove_0')));
    await tester.pumpAndSettle();
    expect(find.text('附件 1'), findsOneWidget);
    expect(find.byKey(const Key('attachment_preview_strip')), findsOneWidget);
  });

  testWidgets('标签入口支持多选并在弹层内新建标签', (tester) async {
    await tester.pumpWidget(const VeriFinUiLabApp());

    await tester.tap(find.byKey(const Key('metadata_tags')));
    await tester.pumpAndSettle();
    expect(find.byType(TagSelectorSheet), findsOneWidget);

    await tester.tap(find.text('通勤'));
    await tester.pump();
    await tester.tap(find.text('新建标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('preview_tag_input')), '旅行');
    await tester.tap(find.byKey(const Key('preview_tag_add')));
    await tester.pumpAndSettle();
    expect(find.text('旅行'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('标签 4'), findsOneWidget);
  });

  testWidgets('收入和转账切换会更新分类与主字段', (tester) async {
    await tester.pumpWidget(const VeriFinUiLabApp());

    await tester.tap(find.byKey(const Key('entry_type_income')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category_tile_salary')), findsOneWidget);
    expect(find.byKey(const Key('metadata_reimbursable')), findsNothing);

    await tester.tap(find.byKey(const Key('entry_type_transfer')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('category_tile_account-transfer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('to_account_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('fee_field')), findsOneWidget);
  });
}
