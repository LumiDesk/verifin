import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin_ui_lab/main.dart';

void main() {
  test('七个默认 SVG 使用已确定的语义配色且不依赖 currentColor', () {
    const expectedColors = <String, String>{
      'wallet.svg': '#346EDB',
      'credit.svg': '#7B61D1',
      'bank.svg': '#2F6F8A',
      'cash.svg': '#16A36F',
      'investment.svg': '#E9862D',
      'savings.svg': '#D95C8A',
      'card.svg': '#2A8FB0',
    };
    for (final entry in expectedColors.entries) {
      final svg = File(
        'assets/account_icon_candidates/${entry.key}',
      ).readAsStringSync();
      expect(svg, contains(entry.value), reason: entry.key);
      expect(svg, isNot(contains('currentColor')), reason: entry.key);
    }
  });

  testWidgets('账户图标候选方案使用纯白背景和 10% 内边距', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.accountIcons),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_icon_preview')), findsOneWidget);
    expect(find.text('账户图标白底方案'), findsOneWidget);

    final current = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('current_icon_asset:credit_001')),
            matching: find.byType(Container),
          )
          .first,
    );
    final proposed = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('proposed_icon_asset:credit_001')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((current.padding! as EdgeInsets).left, closeTo(6.48, 0.001));
    expect((proposed.padding! as EdgeInsets).left, closeTo(3.6, 0.001));
    expect((proposed.decoration! as BoxDecoration).color, Colors.white);
    expect(find.byKey(const Key('current_generic_wallet')), findsOneWidget);
    expect(find.byKey(const Key('proposed_generic_wallet')), findsOneWidget);
    final genericCandidate = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('proposed_generic_wallet')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((genericCandidate.decoration! as BoxDecoration).color, Colors.white);
  });

  testWidgets('可即时切换至 8% 内边距，深浅主题仍保持白底', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.accountIcons),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_icon_padding_8')));
    await tester.pumpAndSettle();
    var proposed = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('proposed_icon_asset:credit_001')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((proposed.padding! as EdgeInsets).left, closeTo(2.88, 0.001));
    expect((proposed.decoration! as BoxDecoration).color, Colors.white);

    await tester.tap(find.byKey(const Key('theme_toggle')));
    await tester.pumpAndSettle();
    proposed = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('proposed_icon_asset:credit_001')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((proposed.decoration! as BoxDecoration).color, Colors.white);
  });
}
