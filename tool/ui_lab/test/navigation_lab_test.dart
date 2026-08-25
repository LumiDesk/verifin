import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin_ui_lab/main.dart';

void main() {
  testWidgets('renders the isolated phone viewport and navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    expect(find.byKey(const Key('phone_viewport')), findsOneWidget);
    expect(find.byKey(const Key('lab_tab_0')), findsOneWidget);
    expect(find.byKey(const Key('lab_tab_3')), findsOneWidget);
    expect(find.byKey(const Key('lab_quick_entry')), findsOneWidget);
    expect(
      tester
          .widget<Padding>(find.byKey(const Key('lab_outer_spacing')))
          .padding,
      const EdgeInsets.fromLTRB(24, 0, 24, 24),
    );
  });

  testWidgets('switches between preview destinations', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    await tester.tap(find.byKey(const Key('lab_tab_1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lab_page_1')), findsOneWidget);
    expect(find.text('账户与净资产'), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('lab_quick_entry_visibility')),
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<AnimatedScale>(find.byKey(const Key('lab_quick_entry_scale')))
          .scale,
      0,
    );
  });

  testWidgets('navigation and hover surfaces are clipped as capsules', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    final material = tester.widget<Material>(
      find.byKey(const Key('lab_nav_material')),
    );
    expect(material.shape, isA<StadiumBorder>());
    expect(material.clipBehavior, Clip.antiAlias);

    final navDecoration =
        tester.widget<Ink>(find.byKey(const Key('lab_nav_ink'))).decoration
            as BoxDecoration;
    final indicatorDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('lab_nav_indicator')),
                )
                .decoration
            as BoxDecoration;
    final indicatorPosition = tester.widget<Positioned>(
      find.byKey(const Key('lab_nav_indicator_position')),
    );
    expect(navDecoration.gradient, isNull);
    expect(indicatorDecoration.gradient, isNull);
    expect(indicatorPosition.top, 3);
    expect(indicatorPosition.bottom, 3);

    final capsuleRect = tester.getRect(
      find.byKey(const Key('lab_nav_capsule')),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const Key('lab_nav_indicator')),
    );
    expect(
      indicatorRect.top - capsuleRect.top,
      closeTo(capsuleRect.bottom - indicatorRect.bottom, 0.1),
    );

    final quickEntryMaterial = tester.widget<Material>(
      find.byKey(const Key('lab_quick_entry_material')),
    );
    expect(quickEntryMaterial.shape, isA<CircleBorder>());
    expect(quickEntryMaterial.color, Colors.transparent);
    expect(quickEntryMaterial.clipBehavior, Clip.antiAlias);

    final quickEntryDecoration =
        tester
                .widget<Ink>(find.byKey(const Key('lab_quick_entry_ink')))
                .decoration
            as BoxDecoration;
    expect(quickEntryDecoration.gradient, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('lab_quick_entry_visibility')),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('selected destination uses neutral foreground in both themes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    Color selectedIconColor() {
      final tab = find.byKey(const Key('lab_tab_0'));
      final icon = tester.widget<Icon>(
        find.descendant(of: tab, matching: find.byType(Icon)).first,
      );
      return icon.color!;
    }

    var tabContext = tester.element(find.byKey(const Key('lab_tab_0')));
    expect(
      selectedIconColor(),
      Theme.of(tabContext).colorScheme.onSurface.withValues(alpha: 0.94),
    );

    await tester.tap(find.byKey(const Key('theme_toggle')));
    await tester.pumpAndSettle();

    tabContext = tester.element(find.byKey(const Key('lab_tab_0')));
    expect(
      selectedIconColor(),
      Theme.of(tabContext).colorScheme.onSurface.withValues(alpha: 0.94),
    );
  });

  testWidgets('pressing the current slider gives a subtle compression', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    final capsuleRect = tester.getRect(
      find.byKey(const Key('lab_nav_capsule')),
    );
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + capsuleRect.width / 8, capsuleRect.center.dy),
    );
    await tester.pump();

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('lab_nav_indicator_scale')),
          )
          .scale,
      0.94,
    );
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('lab_nav_indicator_scale')),
          )
          .duration,
      const Duration(milliseconds: 160),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const Key('lab_nav_indicator_scale')),
          )
          .scale,
      1,
    );
  });

  testWidgets('a tap on a tab boundary always resolves to one tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    final capsuleRect = tester.getRect(
      find.byKey(const Key('lab_nav_capsule')),
    );
    final slotWidth = capsuleRect.width / 4;
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + slotWidth, capsuleRect.center.dy),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final resolvedPageCount =
        find.byKey(const Key('lab_page_0')).evaluate().length +
        find.byKey(const Key('lab_page_1')).evaluate().length;
    expect(resolvedPageCount, 1);
    final indicatorRect = tester.getRect(
      find.byKey(const Key('lab_nav_indicator')),
    );
    final firstCenter = capsuleRect.left + slotWidth * 0.5;
    final secondCenter = capsuleRect.left + slotWidth * 1.5;
    final nearestCenterDistance = <double>[
      (indicatorRect.center.dx - firstCenter).abs(),
      (indicatorRect.center.dx - secondCenter).abs(),
    ].reduce((a, b) => a < b ? a : b);
    expect(nearestCenterDistance, lessThan(0.5));
  });

  testWidgets(
    'pressing a distant tab moves toward the finger without jumping',
    (tester) async {
      await tester.pumpWidget(
        const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
      );

      final capsuleRect = tester.getRect(
        find.byKey(const Key('lab_nav_capsule')),
      );
      final slotWidth = capsuleRect.width / 4;
      final firstCenter = capsuleRect.left + slotWidth * 0.5;
      final fourthCenter = capsuleRect.left + slotWidth * 3.5;
      final gesture = await tester.startGesture(
        Offset(fourthCenter, capsuleRect.center.dy),
      );
      await tester.pump();

      expect(
        tester.getRect(find.byKey(const Key('lab_nav_indicator'))).center.dx,
        closeTo(firstCenter, 0.5),
      );

      await tester.pump(const Duration(milliseconds: 40));
      final movingCenter = tester
          .getRect(find.byKey(const Key('lab_nav_indicator')))
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

      expect(find.byKey(const Key('lab_page_2')), findsOneWidget);
    },
  );

  testWidgets('hover changes content color without painting a background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    final tab = find.byKey(const Key('lab_tab_3'));
    final iconFinder = find
        .descendant(of: tab, matching: find.byType(Icon))
        .first;
    final tabContext = tester.element(tab);
    final scheme = Theme.of(tabContext).colorScheme;

    expect(
      tester.widget<Icon>(iconFinder).color,
      scheme.onSurface.withValues(alpha: 0.48),
    );
    final ink = tester.widget<InkWell>(find.byKey(const Key('lab_tab_ink_我的')));
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

  testWidgets('dragging the glass slider selects a destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    final capsuleRect = tester.getRect(
      find.byKey(const Key('lab_nav_capsule')),
    );
    final gesture = await tester.startGesture(
      Offset(capsuleRect.left + capsuleRect.width / 8, capsuleRect.center.dy),
    );
    await gesture.moveTo(
      Offset(
        capsuleRect.left + capsuleRect.width * 5 / 8,
        capsuleRect.center.dy,
      ),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lab_page_2')), findsOneWidget);
    expect(find.byKey(const Key('glass_test_content')), findsOneWidget);
    expect(find.text('玻璃背景测试'), findsOneWidget);
    expect(find.byKey(const Key('glass_test_hero')), findsOneWidget);
    expect(find.byKey(const Key('glass_test_footer')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('lab_quick_entry_visibility')),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('quick entry remains a separate primary action', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.navigation),
    );

    await tester.tap(find.byKey(const Key('lab_quick_entry')));
    await tester.pump();

    expect(find.text('预览：打开快速记账'), findsOneWidget);
  });
}
