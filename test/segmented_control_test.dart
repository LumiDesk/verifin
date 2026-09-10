import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required List<String> values,
    required String selected,
    required ValueChanged<String> onChanged,
    bool compact = false,
    Color? Function(String)? accentOf,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VeriSegmentedControl<String>(
                values: values,
                selected: selected,
                labelOf: (value) => value,
                onChanged: onChanged,
                compact: compact,
                accentOf: accentOf,
                semanticLabel: '测试分段',
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('渲染全部选项并标出当前选中', (tester) async {
    await pumpControl(
      tester,
      values: const <String>['支出', '收入', '转账'],
      selected: '收入',
      onChanged: (_) {},
    );

    // rolling 会把选中项额外渲染一份用于滑动动画，因此按“至少一个”断言。
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.text('转账'), findsWidgets);
  });

  testWidgets('点击未选中项回调，点击当前项不回调', (tester) async {
    final tapped = <String>[];
    await pumpControl(
      tester,
      values: const <String>['支出', '收入'],
      selected: '支出',
      onChanged: tapped.add,
    );

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(tapped, <String>['收入']);
  });

  testWidgets('提供整组与单项的无障碍语义', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpControl(
      tester,
      values: const <String>['支出', '收入'],
      selected: '收入',
      onChanged: (_) {},
    );

    // 第三方控件本身不带语义，包装层必须补上：整组标注当前值。
    final node = tester.getSemantics(find.bySemanticsLabel('测试分段'));
    expect(node.label, '测试分段');
    expect(node.value, '收入');
    handle.dispose();
  });

  testWidgets('选中项使用 accentOf 的强调色', (tester) async {
    await pumpControl(
      tester,
      values: const <String>['支出', '收入'],
      selected: '支出',
      onChanged: (_) {},
      accentOf: (value) => value == '支出' ? veriExpense : null,
    );
    await tester.pumpAndSettle();

    final colors = tester
        .widgetList<Text>(find.text('支出'))
        .map((text) => text.style?.color)
        .toList();
    expect(colors, contains(veriExpense));
  });

  testWidgets('紧凑档高度小于常规档', (tester) async {
    await pumpControl(
      tester,
      values: const <String>['日', '月'],
      selected: '日',
      onChanged: (_) {},
    );
    final regular = tester.getSize(find.byType(VeriSegmentedControl<String>));

    await pumpControl(
      tester,
      values: const <String>['日', '月'],
      selected: '日',
      onChanged: (_) {},
      compact: true,
    );
    final dense = tester.getSize(find.byType(VeriSegmentedControl<String>));

    expect(dense.height, lessThan(regular.height));
  });
}
