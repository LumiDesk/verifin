import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_lock.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/app_lock_page.dart';

import 'support/test_harness.dart';

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_key_$digit')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  useTestDatabases();

  group('AppLockConfig', () {
    test('hashes secret with salt and verifies without storing plaintext', () {
      final config = AppLockConfig.fromSecret(
        kind: AppLockKind.pin,
        secret: '123456',
      );
      expect(config.enabled, isTrue);
      expect(config.secretHash, isNotEmpty);
      expect(config.secretHash.contains('123456'), isFalse);
      expect(config.verify('123456'), isTrue);
      expect(config.verify('654321'), isFalse);
    });

    test('survives json round-trip', () {
      final config = AppLockConfig.fromSecret(
        kind: AppLockKind.pin,
        secret: '111222',
        biometricEnabled: true,
      );
      final restored = AppLockConfig.fromJson(config.toJson());
      expect(restored.kind, AppLockKind.pin);
      expect(restored.biometricEnabled, isTrue);
      expect(restored.verify('111222'), isTrue);
    });

    test('none config is disabled and never verifies', () {
      const config = AppLockConfig.none();
      expect(config.enabled, isFalse);
      expect(config.verify('123456'), isFalse);
    });
  });

  group('controller app lock', () {
    test('set, verify, disable and persist across reload', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      expect(controller.appLockEnabled, isFalse);

      controller.setAppLock(kind: AppLockKind.pin, secret: '246810');
      expect(controller.appLockEnabled, isTrue);
      expect(controller.appLockKind, AppLockKind.pin);
      expect(controller.verifyAppLock('246810'), isTrue);
      expect(controller.verifyAppLock('000000'), isFalse);

      // 同 store 重新载入（模拟重启）仍锁定。
      final reloaded = await makeController(store);
      expect(reloaded.appLockEnabled, isTrue);
      expect(reloaded.verifyAppLock('246810'), isTrue);

      reloaded.disableAppLock();
      expect(reloaded.appLockEnabled, isFalse);
      final afterDisable = await makeController(store);
      expect(afterDisable.appLockEnabled, isFalse);
    });

    test('reset keeps the app lock configured', () async {
      final controller = await makeController();
      controller.setAppLock(kind: AppLockKind.pin, secret: '135790');
      controller.resetAllData();
      expect(controller.appLockEnabled, isTrue);
      expect(controller.verifyAppLock('135790'), isTrue);
    });

    test(
      'biometric requires a lock and clears when lock is disabled',
      () async {
        final store = LocalKeyValueStore();
        final controller = await makeController(store);

        // 未启用应用锁时不能开启生物识别。
        controller.setBiometricUnlockEnabled(true);
        expect(controller.biometricUnlockEnabled, isFalse);

        controller.setAppLock(kind: AppLockKind.pin, secret: '112233');
        controller.setBiometricUnlockEnabled(true);
        expect(controller.biometricUnlockEnabled, isTrue);

        // 持久化：重载后仍开启。
        final reloaded = await makeController(store);
        expect(reloaded.biometricUnlockEnabled, isTrue);

        // 关闭应用锁同时关闭生物识别。
        reloaded.disableAppLock();
        expect(reloaded.biometricUnlockEnabled, isFalse);
      },
    );
  });

  testWidgets('enables PIN lock from settings', (WidgetTester tester) async {
    final controller = await pumpApp(tester);

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_lock_pin')));
    await tester.pumpAndSettle();

    await _enterPin(tester, '123456'); // 首次输入
    await _enterPin(tester, '123456'); // 确认

    expect(controller.appLockEnabled, isTrue);
    expect(controller.appLockKind, AppLockKind.pin);
    expect(controller.verifyAppLock('123456'), isTrue);
  });

  testWidgets('hides fingerprint switch when biometrics unavailable', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setAppLock(kind: AppLockKind.pin, secret: '778899');
    await pumpApp(tester, store);
    await tester.pumpAndSettle();
    await _enterPin(tester, '778899'); // 先解锁冷启动锁屏

    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用锁'));
    await tester.pumpAndSettle();

    expect(find.text('锁定方式与密码'), findsOneWidget);
    // 测试宿主没有生物识别，指纹开关不应出现。
    expect(find.text('指纹解锁'), findsNothing);
  });

  testWidgets('unlocks with a pattern gesture', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setAppLock(kind: AppLockKind.pattern, secret: '0-1-2-4-8');
    await pumpApp(tester, store);
    await tester.pumpAndSettle();

    expect(find.text('输入密码'), findsOneWidget);
    expect(find.text('请绘制图案解锁'), findsOneWidget);

    final area = find.byKey(const Key('pattern_area'));
    final topLeft = tester.getTopLeft(area);
    Offset dot(int index) =>
        topLeft + patternDotCenter(index, kPatternAreaSize);

    final gesture = await tester.startGesture(dot(0));
    // 先移出触摸 slop（仍在 0 号点命中范围内）触发 panStart。
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    for (final index in <int>[1, 2, 4, 8]) {
      await gesture.moveTo(dot(index));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('输入密码'), findsNothing);
  });

  testWidgets('locks on background and unlocks with correct PIN', (
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    controller.setAppLock(kind: AppLockKind.pin, secret: '424242');
    await pumpApp(tester, store);
    await tester.pumpAndSettle();

    // 冷启动即锁定。
    expect(find.text('输入密码'), findsOneWidget);

    // 错误密码给出提示，仍锁定。
    await _enterPin(tester, '000000');
    expect(find.text('验证失败，请重试'), findsOneWidget);
    expect(find.text('输入密码'), findsOneWidget);

    // 正确密码解锁。
    await _enterPin(tester, '424242');
    expect(find.text('输入密码'), findsNothing);

    // 退到后台再回前台重新锁定。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('输入密码'), findsOneWidget);
  });
}
