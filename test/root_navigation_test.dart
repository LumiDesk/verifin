import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';

/// 停靠底栏的布局与契约。
///
/// 条目由 `bottom_bar_matu` 的 `BottomBarDoubleBullet` 绘制；快捷记账按钮已移出
/// 底栏，改由 Shell 在右下角浮动（见 navigation_settings_test 中的壳层断言），
/// 因此这里只覆盖底栏自身。
void main() {
  testWidgets('停靠底栏在 360dp 视口下整宽贴底', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.padding = const FakeViewPadding(bottom: 20);
    // 底栏读取的是 viewPadding（键盘弹起时 padding 会被 viewInsets 吃掉），
    // 真机上两者一致，测试也要一起设，否则模拟不出系统留白。
    tester.view.viewPadding = const FakeViewPadding(bottom: 20);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _NavigationHarness());

    expect(tester.takeException(), isNull);
    final navRect = tester.getRect(find.byKey(const Key('main_bottom_nav')));
    expect(navRect.left, 0, reason: '停靠底栏应整宽，不再留浮动外边距');
    expect(navRect.right, 360);
    // 表面一直铺到屏幕最底（盖住系统导航条），否则那一条会露出页面底色。
    expect(navRect.bottom, 800);
    // 条目内容让开系统导航条。
    final barRect = tester.getRect(find.byKey(const Key('main_nav_bar')));
    expect(barRect.bottom, lessThanOrEqualTo(800 - 20));
    expect(barRect.height, lessThanOrEqualTo(VeriRootNavigationBody.barHeight));
  });

  testWidgets('系统不留白时底栏仍有最小底部间距，不贴屏幕下边缘', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    // 手势提示线关闭的机器：系统不报底部留白（部分 ROM/机型如此）。
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _NavigationHarness());

    final navRect = tester.getRect(find.byKey(const Key('main_bottom_nav')));
    expect(navRect.bottom, 800, reason: '表面色仍要铺到屏幕最底');

    // 库把标签固定在条底 5dp；没有下限时条目会直接贴住物理下边缘。
    final barRect = tester.getRect(find.byKey(const Key('main_nav_bar')));
    expect(
      800 - barRect.bottom,
      greaterThanOrEqualTo(10),
      reason: '系统不留白时也要保住最小底部间距，否则条目贴边',
    );
  });

  testWidgets('四个中文标签常显在底栏内', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    for (final label in <String>['首页', '资产', '看板', '我的']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('main_bottom_nav')),
          matching: find.text(label),
        ),
        findsWidgets,
        reason: '$label 标签应常显在底栏内',
      );
    }
  });

  testWidgets('底栏不绘制模糊', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('点按条目回调对应下标', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_NavigationHarness(onSelected: selected.add));

    final navRect = tester.getRect(find.byKey(const Key('main_bottom_nav')));
    final slot = navRect.width / 4;
    await tester.tapAt(Offset(navRect.left + slot * 2.5, navRect.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(selected, contains(2));
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness({this.onSelected});

  final ValueChanged<int>? onSelected;

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
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
      theme: buildVeriFinTheme(Brightness.dark),
      home: Scaffold(
        body: Center(child: Text('page:$_index')),
        bottomNavigationBar: VeriRootNavigation(
          currentIndex: _index,
          destinations: _destinations,
          onDestinationSelected: (index) {
            widget.onSelected?.call(index);
            setState(() => _index = index);
          },
        ),
      ),
    );
  }
}
