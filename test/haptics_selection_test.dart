// 选择类触感：底栏、分段控件、开关、期间步进与通用单选弹层。
//
// 这些都是全应用共享的高频入口，覆盖一次即可保证所有调用点一致；
// 断言只记录语义档位，平台映射由 `test/haptics_test.dart` 负责。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/haptics.dart';
import 'package:verifin/pages/sheets.dart';

import 'support/test_harness.dart';

void main() {
  late List<VeriHaptic> played;

  setUp(() {
    VeriHaptics.reset();
    played = <VeriHaptic>[];
    VeriHaptics.debugSink = played.add;
  });

  tearDown(VeriHaptics.reset);

  group('分段控件', () {
    Widget control({
      required String selected,
      ValueChanged<String>? onChanged,
    }) {
      return zhMaterialApp(
        home: Scaffold(
          body: VeriSegmentedControl<String>(
            values: const <String>['支出', '收入'],
            selected: selected,
            labelOf: (value) => value,
            onChanged: onChanged,
          ),
        ),
      );
    }

    testWidgets('切到另一个选项发一次 tick，点当前项不发', (tester) async {
      String? picked;
      await tester.pumpWidget(
        control(selected: '支出', onChanged: (value) => picked = value),
      );

      // rolling 会把选中项渲染两份，按文字定位会命中被 IgnorePointer 的副本；
      // 直接按整块控件的左右半区点击。
      final rect = tester.getRect(find.byType(VeriSegmentedControl<String>));
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
      expect(played, isEmpty);
      expect(picked, isNull);

      await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
      expect(played, <VeriHaptic>[VeriHaptic.tick]);
      expect(picked, '收入');
    });

    testWidgets('禁用时不发触感', (tester) async {
      await tester.pumpWidget(control(selected: '支出'));

      final rect = tester.getRect(find.byType(VeriSegmentedControl<String>));
      await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));

      expect(played, isEmpty);
    });
  });

  group('开关行', () {
    Widget row({required bool value, ValueChanged<bool>? onChanged}) {
      return zhMaterialApp(
        home: Scaffold(
          body: CompactSwitchRow(
            icon: Icons.touch_app_outlined,
            title: const Text('触感反馈'),
            value: value,
            onChanged: onChanged,
          ),
        ),
      );
    }

    testWidgets('点整行与点开关各发一次 tap', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(row(value: false, onChanged: changes.add));

      await tester.tap(find.text('触感反馈'));
      expect(played, <VeriHaptic>[VeriHaptic.tap]);
      expect(changes, <bool>[true]);

      await tester.tap(find.byType(Switch));
      expect(played, <VeriHaptic>[VeriHaptic.tap, VeriHaptic.tap]);
      expect(changes, <bool>[true, true]);
    });

    testWidgets('禁用时不发触感', (tester) async {
      await tester.pumpWidget(row(value: false));

      await tester.tap(find.text('触感反馈'));

      expect(played, isEmpty);
    });
  });

  group('期间步进', () {
    testWidgets('前后翻页发 tick，到边界不发', (tester) async {
      var previous = 0;
      var next = 0;
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(
            body: MonthSwitcher(
              label: '2026年11月',
              onPrevious: () => previous += 1,
              onNext: () => next += 1,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(played, <VeriHaptic>[VeriHaptic.tick, VeriHaptic.tick]);

      await tester.pumpWidget(
        zhMaterialApp(
          home: const Scaffold(body: MonthSwitcher(label: '2026年11月')),
        ),
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.tap(find.byIcon(Icons.chevron_right));

      expect(played, <VeriHaptic>[VeriHaptic.tick, VeriHaptic.tick]);
    });
  });

  group('通用单选弹层', () {
    testWidgets('选中项后发一次 tick', (tester) async {
      await tester.pumpWidget(
        zhMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showOptionSheet<String>(
                    context: context,
                    title: '选择',
                    values: const <String>['甲', '乙'],
                    selected: '甲',
                    labelOf: (value) => value,
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();

      expect(played, <VeriHaptic>[VeriHaptic.tick]);
    });
  });

  group('底部导航', () {
    testWidgets('点其他 Tab 发一次 tick，点当前 Tab 不发', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('main_nav_item_1')));
      await tester.pumpAndSettle();
      expect(played, <VeriHaptic>[VeriHaptic.tick]);

      played.clear();
      await tester.tap(find.byKey(const Key('main_nav_item_1')));
      await tester.pumpAndSettle();
      expect(played, isEmpty);
    });
  });
}
