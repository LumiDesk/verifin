// 命令类触感：只有显式命令与它的结果才给反馈，静默自动保存不给。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_lock.dart';
import 'package:verifin/app/haptics.dart';
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

  group('快速记账', () {
    testWidgets('显式保存成功后发一次 commit', (tester) async {
      await pumpApp(tester);
      await addTestAccount(tester, '现金账户');
      await tapBottomTab(tester, 0);
      await createQuickEntry(tester);

      // 数字键盘确认已经发过 commit，这里只看保存这一步。
      played.clear();
      await tester.tap(find.byKey(const Key('save_entry_button')));
      await tester.pumpAndSettle();

      expect(played, <VeriHaptic>[VeriHaptic.commit]);
    });
  });

  group('删除交易', () {
    testWidgets('确认删除成功后发一次 emphasis', (tester) async {
      await pumpApp(tester);
      await addTestAccount(tester, '现金账户');
      await tapBottomTab(tester, 0);
      await createQuickEntry(tester);
      await tester.tap(find.byKey(const Key('save_entry_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('餐饮').first);
      await tester.pumpAndSettle();
      played.clear();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(played, <VeriHaptic>[VeriHaptic.emphasis]);
    });
  });

  group('解锁', () {
    Widget lockScreen({
      required AppLockConfig config,
      required VoidCallback onUnlocked,
    }) {
      return zhMaterialApp(
        home: AppLockScreen(config: config, onUnlocked: onUnlocked),
      );
    }

    Future<void> enterPin(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('解锁成功发 commit，失败发 emphasis', (tester) async {
      var unlocked = 0;
      await tester.pumpWidget(
        lockScreen(
          config: AppLockConfig.fromSecret(
            kind: AppLockKind.pin,
            secret: '123456',
          ),
          onUnlocked: () => unlocked += 1,
        ),
      );

      await enterPin(tester, '000000');
      expect(unlocked, 0);
      expect(played.last, VeriHaptic.emphasis);

      played.clear();
      await enterPin(tester, '123456');
      expect(unlocked, 1);
      expect(played.last, VeriHaptic.commit);
    });
  });
}
