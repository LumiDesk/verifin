import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('日历切换月份后显示并可使用「本月」快捷按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: const Scaffold(
          body: CalendarPreview(entries: <LedgerEntry>[], currencyCode: 'CNY'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月'), findsNothing);
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();

    expect(find.text('本月'), findsOneWidget);
    await tester.tap(find.text('本月'));
    await tester.pumpAndSettle();
    expect(find.text('本月'), findsNothing);
  });
}
