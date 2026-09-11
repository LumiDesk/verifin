import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/pages/home_page.dart';

void main() {
  test('路由过渡使用的 Material 基色必须不透明', () {
    for (final brightness in Brightness.values) {
      expect(buildVeriFinTheme(brightness).colorScheme.surface.a, 1);
    }
  });

  test('Scaffold 背景是不透明画布色，不再走透明+全屏玻璃层', () {
    for (final brightness in Brightness.values) {
      expect(
        buildVeriFinTheme(brightness).scaffoldBackgroundColor.a,
        1,
        reason: '页面背景必须自带不透明底色，不能依赖外部玻璃层补底',
      );
    }
  });

  testWidgets('页面背景在默认与统一布局中都使用实色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: const Scaffold(body: VeriPage(child: Text('content'))),
      ),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(VeriPage),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color?.a, 1);
  });

  test('深色输入默认无白边，聚焦和错误保留语义边框', () {
    final input = buildVeriFinTheme(Brightness.dark).inputDecorationTheme;
    expect(input.enabledBorder!.borderSide.style, BorderStyle.none);
    expect(input.focusedBorder!.borderSide.color, veriRoyal);
    expect(input.errorBorder!.borderSide.color, veriExpense);
  });

  test('材质预览保留 v1.15 移动端全局字号', () {
    final text = buildVeriFinTheme(Brightness.dark).textTheme;
    expect(text.displayLarge!.fontSize, 38);
    expect(text.displaySmall!.fontSize, 26);
    expect(text.titleLarge!.fontSize, 17);
    expect(text.titleMedium!.fontSize, 14);
    expect(text.titleSmall!.fontSize, 13);
    expect(text.labelMedium!.fontSize, 11);
    expect(text.labelSmall!.fontSize, 10);
  });

  testWidgets('最近交易标题按住不画横条且点击仍可用', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeaderAction(
            title: '最近交易',
            trailing: '',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.highlightColor, Colors.transparent);
    expect(ink.splashColor, Colors.transparent);
    await tester.tap(find.text('最近交易'));
    expect(taps, 1);
  });
}
