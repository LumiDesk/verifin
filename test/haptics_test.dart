// 触感统一入口：语义档位、全局闸门与控制器同步。
//
// 平台通道级断言只在这里做一次：业务侧的 widget 测试通过 [VeriHaptics.debugSink]
// 记录语义档位，避免每个用例都去 mock `SystemChannels.platform`。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/haptics.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestDatabases();

  late List<MethodCall> platformCalls;

  void mockPlatform({Object? Function(MethodCall call)? handler}) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        platformCalls.add(call);
      }
      return handler?.call(call);
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  setUp(() {
    VeriHaptics.reset();
    platformCalls = <MethodCall>[];
  });

  tearDown(VeriHaptics.reset);

  group('语义档位', () {
    test('四档各自映射到对应平台原语', () async {
      mockPlatform();

      VeriHaptics.tick();
      VeriHaptics.tap();
      VeriHaptics.commit();
      VeriHaptics.emphasis();
      await pumpEventQueue();

      expect(
        platformCalls.map((call) => call.method),
        everyElement('HapticFeedback.vibrate'),
      );
      expect(platformCalls.map((call) => call.arguments), <Object?>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('关闭闸门后不产生任何平台调用', () async {
      mockPlatform();
      VeriHaptics.enabled = false;

      VeriHaptics.tick();
      VeriHaptics.tap();
      VeriHaptics.commit();
      VeriHaptics.emphasis();
      await pumpEventQueue();

      expect(platformCalls, isEmpty);
    });

    test('preview 在闸门关闭时仍给出一次确认', () async {
      mockPlatform();
      VeriHaptics.enabled = false;

      VeriHaptics.preview();
      await pumpEventQueue();

      expect(platformCalls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('debugSink 记录语义档位且不经过平台通道', () async {
      mockPlatform();
      final kinds = <VeriHaptic>[];
      VeriHaptics.debugSink = kinds.add;

      VeriHaptics.tick();
      VeriHaptics.commit();
      await pumpEventQueue();

      expect(kinds, <VeriHaptic>[VeriHaptic.tick, VeriHaptic.commit]);
      expect(platformCalls, isEmpty);
    });

    test('平台通道抛错时静默降级，不影响调用方', () async {
      mockPlatform(
        handler: (_) => throw PlatformException(code: 'unavailable'),
      );

      expect(() => VeriHaptics.tap(), returnsNormally);
      await pumpEventQueue();
    });
  });

  group('控制器同步', () {
    test('载入时把偏好镜像到闸门', () async {
      final store = LocalKeyValueStore();
      store.write(VeriHaptics.storageKey, 'false');
      await makeController(store);

      expect(VeriHaptics.enabled, isFalse);
    });

    test('直接 setter 立即同步', () async {
      final controller = await makeController();
      expect(VeriHaptics.enabled, isTrue);

      controller.setHapticsEnabled(false);
      expect(VeriHaptics.enabled, isFalse);

      controller.setHapticsEnabled(true);
      expect(VeriHaptics.enabled, isTrue);
    });

    test('初始化数据把触感恢复为开启', () async {
      final controller = await makeController();
      controller.setHapticsEnabled(false);
      expect(VeriHaptics.enabled, isFalse);

      expect(await controller.resetAllData(), isTrue);
      expect(controller.hapticsEnabled, isTrue);
      expect(VeriHaptics.enabled, isTrue);
    });
  });
}
