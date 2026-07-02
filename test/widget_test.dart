import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/main.dart';

Future<void> tapBottomTab(WidgetTester tester, int index) async {
  final nav = tester.widget<BottomNavigationBar>(
    find.byKey(const Key('main_bottom_nav')),
  );
  nav.onTap!(index);
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
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme_segmented_button')), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('creates an entry through the quick entry flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VeriFinApp());

    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('number_key_4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_key_5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save_entry_button')), findsOneWidget);
    expect(find.text('45'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('save_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('今日交易'), findsOneWidget);
    expect(find.text('餐饮'), findsAtLeastNWidgets(1));
    expect(find.text('-45'), findsAtLeastNWidgets(1));
  });
}
