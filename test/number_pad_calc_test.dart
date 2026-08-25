import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/calc_expression.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/main.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('汇率算式可保留十位小数，普通金额仍默认两位', () {
    expect(evaluateAmountExpression('1÷3'), 0.33);
    expect(evaluateAmountExpression('1÷3', decimalPlaces: 10), 0.3333333333);
  });

  Future<void> openNumberPad(WidgetTester tester) async {
    await pumpApp(tester);
    await tapBottomTab(tester, 0);
    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();
  }

  testWidgets('算式 500+800 展示结果并可确认为 1300', (tester) async {
    await openNumberPad(tester);

    await tester.tap(find.byKey(const Key('number_key_5')));
    await tester.tap(find.byKey(const Key('number_key_00')));
    await tester.tap(find.byKey(const Key('number_key_+')));
    await tester.tap(find.byKey(const Key('number_key_8')));
    await tester.tap(find.byKey(const Key('number_key_00')));
    await tester.pump();

    // 右下角浅色结果预览。
    expect(find.text('= 1300'), findsOneWidget);

    await tester.tap(find.byKey(const Key('number_pad_ok')));
    await tester.pumpAndSettle();

    // 落到记账页，默认支出的大金额带负号。
    expect(find.text('− 1300'), findsOneWidget);
  });

  testWidgets('不完整算式提示且不可确认', (tester) async {
    await openNumberPad(tester);

    await tester.tap(find.byKey(const Key('number_key_5')));
    await tester.tap(find.byKey(const Key('number_key_00')));
    await tester.tap(find.byKey(const Key('number_key_+')));
    await tester.pump();

    expect(find.text('算式不完整'), findsOneWidget);

    final okButton = tester.widget<FilledButton>(
      find.byKey(const Key('number_pad_ok')),
    );
    expect(okButton.onPressed, isNull);
  });

  testWidgets('allowZero 时清空后可确认（清除额度/预算场景）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      zhMaterialApp(
        home: const Scaffold(
          body: NumberPadSheet(
            title: '信用额度',
            initialAmount: 5000,
            allowZero: true,
            hapticsEnabled: false,
          ),
        ),
      ),
    );
    // 清空后 OK 仍可点（视为 0）。
    await tester.tap(find.byKey(const Key('number_key_C')));
    await tester.pump();
    final ok = tester.widget<FilledButton>(
      find.byKey(const Key('number_pad_ok')),
    );
    expect(ok.onPressed, isNotNull);
  });

  testWidgets('allowZero=false 时清空后仍不可确认', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      zhMaterialApp(
        home: const Scaffold(
          body: NumberPadSheet(
            title: '金额',
            initialAmount: 100,
            hapticsEnabled: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('number_key_C')));
    await tester.pump();
    final ok = tester.widget<FilledButton>(
      find.byKey(const Key('number_pad_ok')),
    );
    expect(ok.onPressed, isNull);
  });

  testWidgets('KWD 快速记账按本位币允许三位小数', (tester) async {
    final controller = await makeController();
    await controller.changeEmptyLedgerBookBaseCurrency(
      controller.activeBook.id,
      'KWD',
    );
    await tester.pumpWidget(VeriFinApp(controller: controller));
    await tapBottomTab(tester, 0);
    await tester.tap(find.byKey(const Key('quick_entry_fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('number_key_0')));
    await tester.tap(find.byKey(const Key('number_key_.')));
    await tester.tap(find.byKey(const Key('number_key_0')));
    await tester.tap(find.byKey(const Key('number_key_0')));
    await tester.tap(find.byKey(const Key('number_key_1')));
    await tester.pump();

    expect(find.text('0.001'), findsOneWidget);
    final ok = tester.widget<FilledButton>(
      find.byKey(const Key('number_pad_ok')),
    );
    expect(ok.onPressed, isNotNull);
  });

  testWidgets('JPY 金额键盘禁用小数点', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      zhMaterialApp(
        home: const Scaffold(
          body: NumberPadSheet(
            title: '日元金额',
            maxFractionDigits: 0,
            currencyCode: 'JPY',
            hapticsEnabled: false,
          ),
        ),
      ),
    );

    final dot = tester.widget<FilledButton>(
      find.byKey(const Key('number_key_.')),
    );
    expect(dot.onPressed, isNull);
  });
}
