import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/pages/home_page.dart';

void main() {
  test('玻璃不能让路由过渡使用的 Material 基色透明', () {
    for (final brightness in Brightness.values) {
      expect(buildVeriFinTheme(brightness).colorScheme.surface.a, 1);
    }
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

  testWidgets('每个路由在 Navigator 内拥有不透明背景', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.dark),
        builder: (_, child) => VeriGlassBackdrop(child: child!),
        home: const Scaffold(body: Text('root')),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const Scaffold(key: Key('next_page'), body: Text('next')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final backgrounds = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(Navigator),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .where(
          (decoration) =>
              decoration.gradient?.colors.every((color) => color.a == 1) ??
              false,
        );
    expect(backgrounds, isNotEmpty, reason: '背景不能只留在 Navigator 外，否则返回半途会透出下一页');
    Future<void> backEvent(String method, double progress) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [progress * 200, 300.0],
            'progress': progress,
            'swipeEdge': 0,
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await backEvent('startBackGesture', 0);
    await backEvent('updateBackGestureProgress', 0.35);
    expect(navigator.userGestureInProgress, isTrue);
    final page = find.byKey(const Key('next_page'));
    final localBackdrop = find
        .ancestor(of: page, matching: find.byType(VeriGlassBackdrop))
        .first;
    expect(tester.getRect(localBackdrop), tester.getRect(page));
    await backEvent('cancelBackGesture', 0.35);
    expect(find.text('next'), findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
  }, skip: !veriGlassDesignPreview);
}
