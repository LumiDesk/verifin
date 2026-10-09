import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';
import 'package:verifin/app/root_navigation_styles.dart';

/// 停靠底栏的布局与契约。
///
/// 条目由本项目自有的 `VeriBottomBar` 绘制（抄写自 `bottom_bar_matu` 并修复，见
/// `lib/app/veri_bottom_bar.dart` 头注释）；快捷记账按钮已移出底栏，改由 Shell 在
/// 右下角浮动（见 navigation_settings_test 中的壳层断言），因此这里只覆盖底栏自身。
void main() {
  group('根导航样式契约', () {
    test('默认样式已登记，标识唯一', () {
      expect(veriRootNavigationStyles, isNotEmpty);
      expect(
        veriRootNavigationStyles,
        contains(veriRootDefaultNavigationStyle),
        reason: '默认样式必须出现在注册表里，否则样式选择页无法展示它',
      );
      final ids = <String>[
        for (final style in veriRootNavigationStyles) style.id,
      ];
      expect(ids.toSet().length, ids.length, reason: '样式标识会写入 KV，必须唯一');
    });

    test('未知或缺失标识回退默认样式', () {
      expect(veriRootNavigationStyleFor(null), veriRootDefaultNavigationStyle);
      expect(veriRootNavigationStyleFor(''), veriRootDefaultNavigationStyle);
      expect(
        veriRootNavigationStyleFor('not-a-style'),
        veriRootDefaultNavigationStyle,
      );
      expect(
        veriRootNavigationStyleFor(veriRootDefaultNavigationStyle.id),
        veriRootDefaultNavigationStyle,
      );
    });

    test('停靠样式的避让由布局推导，取值与迁移前一致', () {
      final layout = veriRootDefaultNavigationStyle.layout;
      expect(layout.extendBody, isFalse);
      expect(layout.occupiedHeight, 64);
      // 停靠样式由 Scaffold 让位，列表末项只保留呼吸留白。
      expect(layout.contentBottomPadding, 12);
    });
  });

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
    expect(
      barRect.height,
      lessThanOrEqualTo(veriRootDefaultNavigationStyle.layout.occupiedHeight),
    );
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

  testWidgets('底栏颜色跟随主题主色，不写死品牌蓝', (tester) async {
    const customPrimary = Color(0xFFB3261E);
    final baseTheme = buildVeriFinTheme(Brightness.light);
    final theme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(primary: customPrimary),
    );

    await tester.pumpWidget(_NavigationHarness(theme: theme));

    // 选中项（首页）用主题主色而非 veriRoyal；未选中项保持灰阶。
    final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    expect(selectedIcon.color, customPrimary);
    expect(selectedIcon.color, isNot(veriRoyal));
    final unselectedIcon = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_outlined),
    );
    expect(unselectedIcon.color, isNot(customPrimary));
  });

  testWidgets('底栏条目向无障碍暴露选中状态', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _NavigationHarness());

      // 选中态由 currentIndex 驱动，条目语义要同时带上标签、点击与选中标记，
      // 否则 TalkBack 只能念出名字，说不出当前停在第几个 Tab。
      expect(
        tester.getSemantics(find.text('首页')),
        isSemantics(label: '首页', isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('资产')),
        isSemantics(label: '资产', isSelected: false, hasTapAction: true),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('点按条目回调对应下标', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_NavigationHarness(onSelected: selected.add));

    // 按条目 key 定位而不是按等宽几何：同一套断言对将来的其它样式也成立。
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('main_nav_item_2'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(selected, contains(2));
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness({this.onSelected, this.theme});

  final ValueChanged<int>? onSelected;
  final ThemeData? theme;

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
      theme: widget.theme ?? buildVeriFinTheme(Brightness.dark),
      home: Scaffold(
        body: Center(child: Text('page:$_index')),
        bottomNavigationBar: VeriRootNavigationHost(
          style: veriRootDefaultNavigationStyle,
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
