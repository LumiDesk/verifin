import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/main.dart';

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('main_tab_$index')));
  await tester.pumpAndSettle();
}

Future<void> addTestAccount(WidgetTester tester, String name) async {
  await tapBottomTab(tester, 1);
  await tester.tap(find.byTooltip('资产操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('添加账户'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.tap(find.byTooltip('保存账户'));
  await tester.pumpAndSettle();
}

Future<void> createQuickEntry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quick_entry_fab')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('number_key_4')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_key_5')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('number_pad_ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the main tabs and switches between pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    expect(find.text('日常账本'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('净资产'), findsAtLeastNWidgets(1));

    await tapBottomTab(tester, 2);
    expect(find.text('数据看板'), findsOneWidget);

    await tapBottomTab(tester, 3);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('changes theme preference from the profile page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('opens asset cover selector from the assets page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);
    await tester.longPress(find.byKey(const Key('asset_cover_card')));
    await tester.pumpAndSettle();

    expect(find.text('资产卡片背景'), findsOneWidget);
    expect(find.text('使用线上图片'), findsOneWidget);
    expect(find.text('选择本地图片'), findsOneWidget);
  });

  testWidgets('shows neutral zero in income expense stats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tester.tap(find.text('支出走势'));
    await tester.pumpAndSettle();

    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('-0'), findsNothing);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('creates an entry through the quick entry flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);

    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
    expect(find.text('45'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('今日交易'), findsOneWidget);
    expect(find.text('餐饮'), findsAtLeastNWidgets(1));
    expect(find.text('-45'), findsAtLeastNWidgets(1));
  });

  testWidgets('opens and deletes an entry from the transaction detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '现金账户');
    await tapBottomTab(tester, 0);

    await createQuickEntry(tester);
    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮').first);
    await tester.pumpAndSettle();

    expect(find.text('支出'), findsAtLeastNWidgets(1));
    expect(find.text('账户'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(find.text('还没有交易'), findsOneWidget);
  });

  testWidgets('starts with no default accounts', (WidgetTester tester) async {
    await tester.pumpWidget(const VeriFinApp());

    await tapBottomTab(tester, 1);

    expect(find.text('支付宝'), findsNothing);
    expect(find.text('微信'), findsNothing);
    expect(find.text('花呗'), findsNothing);
  });

  testWidgets('isolates accounts between ledger books', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());
    await addTestAccount(tester, '默认账本账户');

    await tapBottomTab(tester, 3);
    await tester.tap(find.text('日常账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '旅行账本');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tapBottomTab(tester, 1);

    expect(find.text('默认账本账户'), findsNothing);
  });
}
