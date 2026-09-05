import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/glass_lighting.dart';
import 'package:verifin/app/root_navigation.dart';

void main() {
  testWidgets('玻璃滑块按压膨胀、拖动改变高光、取消复位且仍可切页', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: VeriRootNavigation(
              keyPrefix: 'lens',
              currentIndex: selected,
              quickEntryLabel: '记账',
              onDestinationSelected: (index) =>
                  setState(() => selected = index),
              destinations: const [
                VeriNavigationDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: '首页',
                ),
                VeriNavigationDestination(
                  icon: Icons.wallet_outlined,
                  selectedIcon: Icons.wallet,
                  label: '资产',
                ),
                VeriNavigationDestination(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: '看板',
                ),
                VeriNavigationDestination(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lens = find.byKey(const Key('lens_liquid_lens'));
    final original = tester.getRect(lens);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('lens_tab_0'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(lens).height, greaterThan(original.height));
    expect(tester.getSize(lens).width, greaterThan(original.width));
    await gesture.moveBy(const Offset(32, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final paint =
        tester
                .widget<CustomPaint>(find.byKey(const Key('lens_lens_light')))
                .painter!
            as VeriGlassLightPainter;
    expect(paint.motion, greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(lens).center.dx, closeTo(original.center.dx, 0.5));
    expect(tester.getSize(lens).height, closeTo(original.height, 0.5));
    await tester.tap(find.byKey(const Key('lens_tab_3')));
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  }, skip: !veriGlassDesignPreview);
}
