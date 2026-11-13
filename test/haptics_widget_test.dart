// 触点级触感：迁移后的组件必须只经 VeriHaptics 发，并且受全局开关控制。
//
// 断言用 [VeriHaptics.debugSink] 记录语义档位；平台通道的映射由
// `test/haptics_test.dart` 单独覆盖一次，这里不重复 mock 通道。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/haptics.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/pages/app_lock_page.dart';

import 'support/test_harness.dart';

void main() {
  late List<VeriHaptic> played;

  setUp(() {
    VeriHaptics.reset();
    played = <VeriHaptic>[];
    VeriHaptics.debugSink = played.add;
  });

  tearDown(VeriHaptics.reset);

  LedgerEntry expenseEntry() => LedgerEntry(
    id: 'entry_1',
    bookId: defaultLedgerBookId,
    type: EntryType.expense,
    amount: 12.5,
    categoryId: 'dining',
    accountId: '',
    note: '午饭',
    occurredAt: DateTime(2026, 11, 13, 12),
  );

  group('数字键盘', () {
    Future<void> pumpPad(WidgetTester tester) async {
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(body: NumberPadSheet(title: '金额')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('数字键 tap、确认键 commit', (tester) async {
      await pumpPad(tester);

      await tester.tap(find.byKey(const Key('number_key_1')));
      expect(played, <VeriHaptic>[VeriHaptic.tap]);

      // 输入后需要一帧让确认键从禁用变为可用。
      await tester.pump();
      await tester.tap(find.byKey(const Key('number_pad_ok')));
      expect(played, <VeriHaptic>[VeriHaptic.tap, VeriHaptic.commit]);
    });

    testWidgets('关闭闸门后按键不产生触感', (tester) async {
      VeriHaptics.enabled = false;
      await pumpPad(tester);

      await tester.tap(find.byKey(const Key('number_key_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('number_pad_ok')));

      expect(played, isEmpty);
    });
  });

  group('应用锁输入', () {
    testWidgets('PIN 数字键 tap，空输入退格不触发', (tester) async {
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(body: PinInputView(onCompleted: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pin_backspace')));
      expect(played, isEmpty);

      await tester.tap(find.byKey(const Key('pin_key_1')));
      expect(played, <VeriHaptic>[VeriHaptic.tap]);
    });

    testWidgets('关闭闸门后 PIN 按键不产生触感', (tester) async {
      VeriHaptics.enabled = false;
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(body: PinInputView(onCompleted: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pin_key_1')));
      expect(played, isEmpty);
    });
  });

  group('资产分区卡', () {
    Widget card({VoidCallback? onToggle, ReorderCallback? onReorder}) {
      return zhMaterialApp(
        home: Scaffold(
          body: AccountSectionCard(
            title: '现金',
            accounts: const <Account>[],
            balances: const <Account, double>{},
            onToggleCollapsed: onToggle,
            onReorderAccounts: onReorder,
          ),
        ),
      );
    }

    testWidgets('展开/折叠每个手势只发一次 tap', (tester) async {
      var toggles = 0;
      await tester.pumpWidget(card(onToggle: () => toggles += 1));

      await tester.tap(find.text('现金'));

      expect(toggles, 1);
      expect(played, <VeriHaptic>[VeriHaptic.tap]);
    });

    testWidgets('一次拖动只发两次 tap（抓住 + 落下），不再有第三次', (tester) async {
      await tester.pumpWidget(card(onReorder: (_, _) {}));

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderStart!(0);
      list.onReorderItem!(0, 1);

      expect(played, <VeriHaptic>[VeriHaptic.tap, VeriHaptic.tap]);
    });

    testWidgets('关闭闸门后折叠与拖动都不产生触感', (tester) async {
      VeriHaptics.enabled = false;
      await tester.pumpWidget(card(onToggle: () {}, onReorder: (_, _) {}));

      await tester.tap(find.text('现金'));
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderStart!(0);
      list.onReorderItem!(0, 1);

      expect(played, isEmpty);
    });
  });

  group('交易行', () {
    testWidgets('长按由 VeriHaptics 发 tap，并关闭 Material 自带震动', (tester) async {
      var longPressed = 0;
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(
            body: TransactionTile(
              expenseEntry(),
              accounts: const <Account>[],
              categories: const <Category>[],
              onLongPress: () => longPressed += 1,
            ),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(TransactionTile),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.enableFeedback, isFalse);

      await tester.longPress(find.byType(TransactionTile));

      expect(longPressed, 1);
      expect(played, <VeriHaptic>[VeriHaptic.tap]);
    });

    testWidgets('关闭闸门后长按不产生触感', (tester) async {
      VeriHaptics.enabled = false;
      await tester.pumpWidget(
        zhMaterialApp(
          home: Scaffold(
            body: TransactionTile(
              expenseEntry(),
              accounts: const <Account>[],
              categories: const <Category>[],
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(TransactionTile));

      expect(played, isEmpty);
    });
  });
}
