import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/root_navigation.dart';

void main() {
  testWidgets('root navigation fits a 360dp Android viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _NavigationHarness());

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('main_bottom_nav')), findsOneWidget);
    expect(find.byKey(const Key('quick_entry_fab')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('main_nav_capsule'))).width,
      268,
    );
  });

  testWidgets('quick entry only operates on home and preserves long press', (
    tester,
  ) async {
    await tester.pumpWidget(const _NavigationHarness());

    await tester.longPress(find.byKey(const Key('quick_entry_fab')));
    await tester.pump();
    expect(find.textContaining('long:1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('main_tab_1')));
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

  testWidgets('glass surfaces have no authored gradients', (tester) async {
    await tester.pumpWidget(const _NavigationHarness());

    final navDecoration =
        tester.widget<Ink>(find.byKey(const Key('main_nav_ink'))).decoration
            as BoxDecoration;
    final indicatorDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('main_nav_indicator')),
                )
                .decoration
            as BoxDecoration;
    final quickEntryDecoration =
        tester
                .widget<Ink>(find.byKey(const Key('main_quick_entry_ink')))
                .decoration
            as BoxDecoration;

    expect(navDecoration.gradient, isNull);
    expect(indicatorDecoration.gradient, isNull);
    expect(quickEntryDecoration.gradient, isNull);
  });

  testWidgets('dragging the slider snaps to a complete destination', (
    tester,
  ) async {
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
