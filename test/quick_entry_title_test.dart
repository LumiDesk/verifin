import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/entry_sheets.dart';

void main() {
  testWidgets('快速记账金额键盘不重复显示快速记账标题', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: NumberPadSheet(title: '快速记账', showTitle: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('快速记账'), findsNothing);
    expect(find.byType(NumberPadSheet), findsOneWidget);
  });

  testWidgets('隐藏快速记账标题仍保留数字区域的原始顶部间距', (tester) async {
    Future<Rect> pumpPad(bool showTitle) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumberPadSheet(title: '快速记账', showTitle: showTitle),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byKey(const Key('number_pad_display')));
    }

    final withTitle = await pumpPad(true);
    final withoutTitle = await pumpPad(false);
    expect(withoutTitle.top, closeTo(withTitle.top, 0.01));
    expect(withoutTitle.height, closeTo(withTitle.height, 0.01));
  });
}
