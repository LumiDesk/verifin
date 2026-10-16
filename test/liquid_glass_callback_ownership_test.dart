import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/platform_bridge.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_liquid_glass.dart';

/// 液态玻璃底栏的静态回调归属（回归）。
///
/// `AppGlassBridge.onTabSelected` 是静态字段，而导航栏样式选择页会渲染只读预览
/// （`onSelect` 为 null、从不挂载原生栏）。曾经的 `dispose()` 无条件把它置空，
/// 于是预览被销毁时把**真实底栏**注册的处理器一起清掉：原生栏照常移动水滴，
/// Dart 侧收不到回调 →「水滴动了、页面不切」。
///
/// 这里不依赖原生 install（测试环境无法完成图标光栅化），直接验证销毁语义：
/// 实例销毁时只能清除「仍属于自己」的回调。
void main() {
  const destinations = <VeriNavigationDestination>[
    VeriNavigationDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '首页',
    ),
  ];

  setUp(() => AppGlassBridge.onTabSelected = null);
  tearDown(() => AppGlassBridge.onTabSelected = null);

  Future<void> pumpBar(
    WidgetTester tester, {
    required ValueChanged<int>? onSelect,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVeriFinTheme(Brightness.light),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: VeriRootNavigationHost(
            style: const VeriLiquidGlassRootNavigationStyle(),
            spec: VeriRootNavigationSpec(
              currentIndex: 0,
              destinations: destinations,
              onSelect: onSelect,
              keyPrefix: 'preview',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('预览实例（未挂载原生栏）销毁时不清除他人的回调', (tester) async {
    // 模拟真实底栏已注册的处理器。
    var handled = -1;
    void realHandler(int index) => handled = index;
    AppGlassBridge.onTabSelected = realHandler;

    // 挂载只读预览（与样式选择页同构：onSelect 为 null）。
    await pumpBar(tester, onSelect: null);
    expect(AppGlassBridge.onTabSelected, isNotNull, reason: '预览挂载不应影响已有回调');

    // 销毁预览。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(
      AppGlassBridge.onTabSelected,
      isNotNull,
      reason: '预览实例销毁不得清空真实底栏的切换回调',
    );
    AppGlassBridge.onTabSelected?.call(0);
    expect(handled, 0, reason: '真实底栏的回调应仍可触发切页');
  });

  testWidgets('未注册回调的实例销毁时不影响 Bridge 状态', (tester) async {
    void realHandler(int index) {}
    AppGlassBridge.onTabSelected = realHandler;

    // 连续两次挂载/销毁预览，Bridge 上的回调应始终是同一个。
    await pumpBar(tester, onSelect: null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpBar(tester, onSelect: null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(AppGlassBridge.onTabSelected, realHandler);
  });
}
