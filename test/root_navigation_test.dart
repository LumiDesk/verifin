import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';

void main() {
  testWidgets('root navigation fits a 360dp Android viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.padding = const FakeViewPadding(bottom: 20);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _NavigationHarness());

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('main_bottom_nav')), findsOneWidget);
    expect(find.byKey(const Key('quick_entry_fab')), findsOneWidget);
    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final quickEntryRect = tester.getRect(
      find.byKey(const Key('main_quick_entry_scale')),
    );
    expect(capsuleRect.width, 244);
    expect(capsuleRect.left, 24);
    expect(360 - quickEntryRect.right, 24);
    expect(800 - capsuleRect.bottom, 44);
  });

  testWidgets('quick entry only operates on home and preserves long press', (
    tester,
  ) async {
    await tester.pumpWidget(const _NavigationHarness());

    await tester.longPress(find.byKey(const Key('quick_entry_fab')));
    await tester.pump();
    expect(find.textContaining('long:1'), findsOneWidget);

    await tester.tap(find.text('资产'));
    await tester.pumpAndSettle();

    expect(find.textContaining('page:1'), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('main_quick_entry_visibility')),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('导航与快捷按钮使用不透明实色，不绘制模糊', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    final navMaterial = tester.widget<Material>(
      find.byKey(const Key('main_nav_material')),
    );
    final quickEntryMaterial = tester.widget<Material>(
      find.byKey(const Key('main_quick_entry_material')),
    );

    // 曾经这里是磨砂玻璃：表面半透明 + BackdropFilter。现在必须是不透明实色。
    expect(navMaterial.color!.a, 1, reason: '导航胶囊必须不透明，不能透出下层内容');
    expect(quickEntryMaterial.color!.a, 1, reason: '快捷记账按钮必须不透明');
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('条目由 bottom_bar_matu 绘制，四个中文标签始终可见', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    // 静止时必须显示实时文字（规范要求），不能是截图或图标替代；
    // 条目不做逐项 Key，测试用唯一的中文标签定位。
    for (final label in <String>['首页', '资产', '看板', '我的']) {
      expect(find.text(label), findsWidgets, reason: '$label 标签应常显');
    }
  });

  testWidgets('拖动跨过多个条目后吸附到最近的目的地', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + slotWidth * 3.5, capsuleRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.moveTo(
      Offset(capsuleRect.left + slotWidth * 2.5, capsuleRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('page:2'), findsOneWidget);
  });

  testWidgets('在条目边界点按只解析为一个目的地', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    // 正好落在第 0/1 个条目的分界线上：原始指针与条目自身都不能各选一次。
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + slotWidth, capsuleRect.center.dy),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final resolved =
        find.textContaining('page:0').evaluate().length +
        find.textContaining('page:1').evaluate().length;
    expect(resolved, 1, reason: '一次点按只能选中一个目的地');
  });

  testWidgets('按住条目后向远处拖动，最终落在手指下的目的地', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + slotWidth * 0.5, capsuleRect.center.dy),
    );
    await tester.pump();
    // 按住期间不应立刻跳转。
    expect(find.textContaining('page:0'), findsOneWidget);

    await gesture.moveTo(
      Offset(capsuleRect.left + slotWidth * 2.5, capsuleRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('page:2'), findsOneWidget);
  });

  testWidgets('点按任意条目都能切到它', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    const labels = <String>['首页', '资产', '看板', '我的'];
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(find.text(labels[i]));
      await tester.pumpAndSettle();
      expect(find.textContaining('page:$i'), findsOneWidget);
    }
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness();

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  int _index = 0;
  int _longPresses = 0;

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
      darkTheme: buildVeriFinTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: Center(child: Text('page:$_index\nlong:$_longPresses')),
        bottomNavigationBar: VeriRootNavigation(
          currentIndex: _index,
          destinations: _destinations,
          onDestinationSelected: (index) => setState(() => _index = index),
          quickEntryLabel: '快速记账',
          showQuickEntry: _index == 0,
          onQuickEntryTap: () {},
          onQuickEntryLongPress: () {
            setState(() => _longPresses += 1);
          },
        ),
      ),
    );
  }
}
