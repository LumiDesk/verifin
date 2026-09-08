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

  testWidgets('无标题数字键盘顶部间距与左右一致', (tester) async {
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
    // 无标题时不再保留标题占位，数字区域随内容上移；但外层容器顶部仍留 14 间距、不贴边。
    expect(withoutTitle.top, lessThan(withTitle.top));
    expect(withoutTitle.height, closeTo(withTitle.height, 0.01));
    expect(
      tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
      contains(const EdgeInsets.fromLTRB(14, 14, 14, 14)),
    );
  });
}
