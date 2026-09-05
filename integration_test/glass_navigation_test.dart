import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verifin/app/navigation_glass_lens.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/glass_material.dart';
import 'package:verifin/app/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('真实浏览器加载透镜 Shader 并采样导航，拖动仍可切页', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            VeriMaterialScope(advanced: true, child: child!),
        theme: buildVeriFinTheme(Brightness.light),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: VeriRootNavigation(
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
    final refraction = find.byKey(const Key('main_lens_refraction'));
    expect(refraction, findsNothing, reason: '静止时保留实时文字，不显示缓存纹理');
    final lens = find.byKey(const Key('main_liquid_lens'));
    final before = tester.getSize(lens);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('main_tab_0'))),
    );
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 40 && refraction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(
      refraction,
      findsOneWidget,
      reason: '必须实际载入 shader 与导航纹理，不能把降级效果当作通过',
    );
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('main_tab_2'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(lens).height, greaterThan(before.height));
    final painter =
        tester.widget<CustomPaint>(refraction).painter!
            as VeriNavigationLensPainter;
    expect(painter.activity, greaterThan(0.5));
    expect(painter.source.width, greaterThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(refraction, findsNothing, reason: '松手恢复实时文字');
    expect(
      tester
          .widget<VeriRootNavigation>(find.byType(VeriRootNavigation))
          .currentIndex,
      2,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Glass lens PASS'))),
      ),
    );
  });
}
