import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_liquid_glass.dart';
import 'package:verifin/app/root_navigation_styles.dart';

/// 液态玻璃底栏样式：几何声明、条目契约与降级行为。
///
/// widget 测试环境没有 Impeller，`ImageFilter.isShaderFilterSupported` 为 false，
/// 因此这里覆盖的正是「着色器不可用时仍保留模糊玻璃与全部交互」这条路径。
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
    // 玻璃样式是唯一绘制背景模糊的已注册样式。
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('液态玻璃底栏向读屏暴露选中态，并回调正确下标', (tester) async {
    final selected = <int>[];
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_LiquidGlassHarness(onSelected: selected.add));

      expect(
        tester.getSemantics(find.text('首页')),
        isSemantics(label: '首页', isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('看板')),
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
}

class _LiquidGlassHarness extends StatefulWidget {
  const _LiquidGlassHarness({this.onSelected});

  final ValueChanged<int>? onSelected;

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
      theme: buildVeriFinTheme(Brightness.light),
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
