import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  /// 轨道的横向内边距与选项间隙，必须与 `VeriSegmentedControl` 内部取值一致。
  const trackPadding = 2.0;
  const trackSpacing = 2.0;

  /// 一个选项槽的宽度：可用宽度扣掉轨道内边距与选项间隙后按选项数均分。
  double slotWidth(double availableWidth, int count) =>
      (availableWidth - trackPadding * 2 - trackSpacing * (count - 1)) / count;

  /// 在宽度受限的容器里渲染（`ListView` 子项、拉伸的列等都是这种紧约束）。
  Future<void> pumpStretched(
    WidgetTester tester, {
    required int count,
    required double width,
  }) {
    final values = <String>[for (var i = 0; i < count; i++) '选项$i'];
    return tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: VeriSegmentedControl<String>(
                values: values,
                selected: values.first,
                labelOf: (value) => value,
                onChanged: (_) {},
                semanticLabel: '测试分段',
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  // 胶囊宽度必须等于**一个选项槽的宽度**。第三方控件只在「选项总宽超过可用宽度」
  // 时把胶囊一起等比缩小；可用宽度有富余时它把余量全摊进选项间隙，胶囊仍停在传入
  // 的固定宽度上。此前写死 58 / 92，于是选项越少胶囊越窄——两项时只覆盖约三分之一
  // 的槽位，四项的因为总宽已超出、走等比缩小那条路反而是正常的。
  for (final count in <int>[2, 3, 4]) {
    testWidgets('$count 项时胶囊铺满一个选项槽', (tester) async {
      const controlWidth = 361.0;
      await pumpStretched(tester, count: count, width: controlWidth);

      final control = tester.widget<AnimatedToggleSwitch<String>>(
        find.byType(AnimatedToggleSwitch<String>),
      );
      expect(
        control.indicatorSize.width,
        closeTo(slotWidth(controlWidth, count), 0.01),
        reason: '$count 项时胶囊应等于槽宽，而不是固定宽度',
      );
      // 胶囊 + 选项间隙必须正好铺满轨道：这样每个槽位都被胶囊整除，不会出现
      // 「胶囊窄、槽位宽」的错位。
      final rendered = tester.getSize(
        find.byType(VeriSegmentedControl<String>),
      );
      expect(rendered.width, closeTo(controlWidth, 0.01));
      expect(
        control.indicatorSize.width * count + trackSpacing * (count - 1),
        closeTo(rendered.width - trackPadding * 2, 0.01),
      );
    });
  }

  testWidgets('宽度不受限时沿用原来的紧凑/常规固定宽度', (tester) async {
    // `Row` 里不加 `Expanded`：横向约束无限，此时没有「槽宽」可算，退回原值。
    // 覆盖这条是为了避免为修「太窄」把本来正常的场景一起改掉。
    Future<double> indicatorWidthOf({required bool compact}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildVeriFinTheme(Brightness.dark),
          home: Scaffold(
            body: SizedBox(
              height: 60,
              child: Row(
                children: <Widget>[
                  VeriSegmentedControl<String>(
                    values: const <String>['日', '月'],
                    selected: '日',
                    compact: compact,
                    labelOf: (value) => value,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return tester
          .widget<AnimatedToggleSwitch<String>>(
            find.byType(AnimatedToggleSwitch<String>),
          )
          .indicatorSize
          .width;
    }

    expect(await indicatorWidthOf(compact: false), 92);
    expect(await indicatorWidthOf(compact: true), 58);
  });
}
