import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/platform_bridge.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/shell.dart';
import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  Future<void> pumpShell(WidgetTester tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const VeriFinShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('数字区域打开首页；加号打开键盘；再次点数字关闭旧键盘', (tester) async {
    await pumpShell(tester);
    await AppWidgetBridge.handleRoute({'route': 'app'});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('number_pad_ok')), findsNothing);
    // The entry route awaits dismissal of the keypad.
    final entry = AppWidgetBridge.handleRoute({'route': 'entry'});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('number_pad_ok')), findsOneWidget);
    await AppWidgetBridge.handleRoute({'route': 'app'});
    await tester.pumpAndSettle();
    await entry;
    expect(find.byKey(const Key('number_pad_ok')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续两次组件快捷记账路由只打开一层数字键盘', (tester) async {
    await pumpShell(tester);

    final first = AppWidgetBridge.handleRoute({'route': 'entry'});
    await tester.pumpAndSettle();
    expect(find.byType(NumberPadSheet), findsOneWidget);

    // 组件 PendingIntent 被连点 / 磁贴与组件同时到达：第二次投递必须复用第一层，
    // 不能叠出第二个一模一样的键盘（正是「卡在记账页面」的来源）。
    final second = AppWidgetBridge.handleRoute({'route': 'entry'});
    await tester.pumpAndSettle();
    expect(find.byType(NumberPadSheet), findsOneWidget);

    // 点遮罩关闭键盘；两笔请求一起结束。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await first;
    await second;

    expect(find.byType(NumberPadSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连点快捷记账按钮也只打开一层数字键盘', (tester) async {
    await pumpShell(tester);
    final fab = find.byKey(const Key('quick_entry_fab'));
    // 同一帧内两次点击：第一次尚未走到 push 帧，第二次仍命中按钮。
    await tester.tap(fab);
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.byType(NumberPadSheet), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(NumberPadSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
