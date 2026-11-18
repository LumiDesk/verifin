import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_liquid_glass.dart';
import 'package:verifin/app/root_navigation_styles.dart';

/// 液态玻璃底栏样式：几何声明、条目契约与交互行为。
void main() {
  test('液态玻璃样式已注册，且与偏好枚举一一对应', () {
    const style = VeriLiquidGlassRootNavigationStyle();
    expect(veriRootNavigationStyles, contains(style));
    expect(
      veriRootNavigationStyleFor(style.id).id,
      VeriLiquidGlassRootNavigationStyle.styleId,
    );
  });

  test('液态玻璃样式声明悬浮避让，列表留白与占用高度自洽', () {
    const style = VeriLiquidGlassRootNavigationStyle();
    final layout = style.layout;
    expect(layout.extendBody, isTrue, reason: '内容要能从胶囊下方滚过');
    expect(
      layout.occupiedHeight,
      VeriLiquidGlassRootNavigationStyle.barHeight +
          VeriLiquidGlassRootNavigationStyle.bottomGap,
    );
    expect(
      layout.contentBottomPadding,
      layout.occupiedHeight + layout.listBottomGap,
    );
  });

  testWidgets('液态玻璃底栏常显四个标签并暴露稳定条目 key', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.padding = const FakeViewPadding(bottom: 0);
    tester.view.viewPadding = const FakeViewPadding(bottom: 0);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _LiquidGlassHarness());
    expect(tester.takeException(), isNull);

    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(ValueKey<String>('main_nav_item_$index')),
        findsOneWidget,
      );
    }
    for (final label in <String>['首页', '资产', '看板', '我的']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('main_bottom_nav')),
          matching: find.text(label),
        ),
        findsWidgets,
      );
    }
    // 玻璃样式复用第三方 `GlassTabBar.bottom`，不在应用层另画玻璃面板。
    expect(
      find.descendant(
        of: find.byKey(const Key('main_bottom_nav')),
        matching: find.byType(GlassTabBar),
      ),
      findsOneWidget,
    );
  });

  testWidgets('液态玻璃底栏向读屏暴露选中态，并回调正确下标', (tester) async {
    final selected = <int>[];
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_LiquidGlassHarness(onSelected: selected.add));

      expect(
        tester.getSemantics(find.bySemanticsLabel('首页')),
        isSemantics(label: '首页', isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('看板')),
        isSemantics(label: '看板', isSelected: false, hasTapAction: true),
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey<String>('main_nav_item_2'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, contains(2));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('液态玻璃底栏支持横向拖动并吸附到最近一项', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_LiquidGlassHarness(onSelected: selected.add));

    final bar = tester.getRect(find.byKey(const Key('main_nav_bar')));
    await tester.dragFrom(
      Offset(bar.left + 12, bar.center.dy),
      Offset(bar.width * 0.6, 0),
    );
    await tester.pumpAndSettle();

    expect(selected, isNotEmpty, reason: '拖动松手后应把目标下标交给 Shell');
    expect(selected.last, inInclusiveRange(1, 3));
  });

  testWidgets('深色模式使用中性、轻磨砂的底栏材质', (tester) async {
    await tester.pumpWidget(
      _LiquidGlassHarness(theme: buildVeriFinTheme(Brightness.dark)),
    );

    final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    final settings = bar.settings;
    expect(settings, isNotNull);
    // 真实底栏保留实时玻璃：premium + blur，不允许被预览的「无 backdrop」调校带偏。
    expect(bar.quality, GlassQuality.premium);
    expect(
      settings!.glassColor.a,
      lessThan(LiquidGlassSettings.ios27Dark.glassColor.a),
      reason: '深色底栏应减少白色雾层',
    );
    expect(
      settings.saturation,
      lessThan(LiquidGlassSettings.ios27Dark.saturation),
      reason: '降低饱和度，避免把后方页面的蓝色放大成整块蓝灰底',
    );
    expect(settings.blur, 2);
    expect(settings.frost, 4);
    expect(settings.frostOpacity, 0.68);
    expect(settings.bodyShade, 0.18);
    expect(settings.backerColor?.a, closeTo(0.07, 0.001));
    expect(bar.indicatorColor?.a, closeTo(0.06, 0.001));
  });
}

class _LiquidGlassHarness extends StatefulWidget {
  const _LiquidGlassHarness({this.onSelected, this.theme});

  final ValueChanged<int>? onSelected;
  final ThemeData? theme;

  @override
  State<_LiquidGlassHarness> createState() => _LiquidGlassHarnessState();
}

class _LiquidGlassHarnessState extends State<_LiquidGlassHarness> {
  int _index = 0;

  static const _destinations = <VeriNavigationDestination>[
    VeriNavigationDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '首页',
    ),
    VeriNavigationDestination(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: '资产',
    ),
    VeriNavigationDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      label: '看板',
    ),
    VeriNavigationDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: widget.theme ?? buildVeriFinTheme(Brightness.light),
      home: Scaffold(
        extendBody: true,
        body: const SizedBox.expand(),
        bottomNavigationBar: VeriRootNavigationHost(
          style: const VeriLiquidGlassRootNavigationStyle(),
          spec: VeriRootNavigationSpec(
            currentIndex: _index,
            destinations: _destinations,
            onSelect: (index) {
              widget.onSelected?.call(index);
              setState(() => _index = index);
            },
          ),
        ),
      ),
    );
  }
}
