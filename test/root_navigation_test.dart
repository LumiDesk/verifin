import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  testWidgets('pressing the current slider gives a subtle compression', (
    tester,
  ) async {
    await tester.pumpWidget(const _NavigationHarness());

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + capsuleRect.width / 8, capsuleRect.center.dy),
    );
    await tester.pump();

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('main_nav_indicator_scale')),
          )
          .scale,
      0.94,
    );
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('main_nav_indicator_scale')),
          )
          .duration,
      const Duration(milliseconds: 160),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('main_nav_indicator_scale')),
          )
          .scale,
      1,
    );
  });

  testWidgets('a tap on a tab boundary always resolves to one tab', (
    tester,
  ) async {
    await tester.pumpWidget(const _NavigationHarness());

    final capsuleRect = tester.getRect(
      find.byKey(const Key('main_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + slotWidth, capsuleRect.center.dy),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final resolvedPageCount =
        find.textContaining('page:0').evaluate().length +
        find.textContaining('page:1').evaluate().length;
    expect(resolvedPageCount, 1);
    final indicatorRect = tester.getRect(
      find.byKey(const Key('main_nav_indicator')),
    );
    final firstCenter = tester
        .getCenter(find.byKey(const Key('main_tab_0')))
        .dx;
    final secondCenter = tester
        .getCenter(find.byKey(const Key('main_tab_1')))
        .dx;
    final nearestCenterDistance = <double>[
      (indicatorRect.center.dx - firstCenter).abs(),
      (indicatorRect.center.dx - secondCenter).abs(),
    ].reduce((a, b) => a < b ? a : b);
    expect(nearestCenterDistance, lessThan(0.5));
  });

  testWidgets(
    'pressing a distant tab moves toward the finger without jumping',
    (tester) async {
      await tester.pumpWidget(const _NavigationHarness());

      final capsuleRect = tester.getRect(
        find.byKey(const Key('main_nav_capsule')),
      );
      final slotWidth = capsuleRect.width / 4;
      final firstCenter = tester
          .getCenter(find.byKey(const Key('main_tab_0')))
          .dx;
      final fourthCenter = tester
          .getCenter(find.byKey(const Key('main_tab_3')))
          .dx;
      final gesture = await tester.startGesture(
        Offset(fourthCenter, capsuleRect.center.dy),
      );
      await tester.pump();

      expect(
        tester.getRect(find.byKey(const Key('main_nav_indicator'))).center.dx,
        closeTo(firstCenter, 0.5),
      );

      await tester.pump(const Duration(milliseconds: 40));
      final movingCenter = tester
          .getRect(find.byKey(const Key('main_nav_indicator')))
          .center
          .dx;
      expect(movingCenter, greaterThan(firstCenter));
      expect(movingCenter, lessThan(fourthCenter));

      await gesture.moveTo(
        Offset(capsuleRect.left + slotWidth * 2.5, capsuleRect.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.textContaining('page:2'), findsOneWidget);
    },
  );

  testWidgets('hover changes content color without painting a background', (
    tester,
  ) async {
    await tester.pumpWidget(const _NavigationHarness());

    final tab = find.byKey(const Key('main_tab_3'));
    final iconFinder = find
        .descendant(of: tab, matching: find.byType(Icon))
        .first;
    final tabContext = tester.element(tab);
    final scheme = Theme.of(tabContext).colorScheme;

    expect(
      tester.widget<Icon>(iconFinder).color,
      scheme.onSurface.withValues(alpha: 0.48),
    );
    final ink = tester.widget<InkWell>(find.byKey(const Key('main_tab_ink_3')));
    expect(ink.hoverColor, Colors.transparent);
    expect(ink.highlightColor, Colors.transparent);
    expect(ink.splashColor, Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(tab));
    await tester.pump();

    expect(
      tester.widget<Icon>(iconFinder).color,
      scheme.onSurface.withValues(alpha: 0.76),
    );

    await mouse.removePointer();
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
