import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/reminder/reminder_settings.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/reminder_settings_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  group('ReminderSettings', () {
    test('encode/decode round trips', () {
      const settings = ReminderSettings(enabled: true, hour: 8, minute: 30);
      final decoded = ReminderSettings.decode(settings.encode());
      expect(decoded, settings);
    });

    test('decode of null/garbage falls back to disabled', () {
      expect(ReminderSettings.decode(null), ReminderSettings.disabled);
      expect(ReminderSettings.decode(''), ReminderSettings.disabled);
      expect(ReminderSettings.decode('not json'), ReminderSettings.disabled);
    });

    test('decode clamps out-of-range hour/minute', () {
      final decoded = ReminderSettings.decode(
        '{"enabled":true,"hour":30,"minute":90}',
      );
      expect(decoded.hour, 23);
      expect(decoded.minute, 59);
    });

    test('timeLabel pads to HH:mm', () {
      const settings = ReminderSettings(hour: 9, minute: 5);
      expect(settings.timeLabel, '09:05');
    });

    test('nextFireTime rolls to tomorrow when time already passed', () {
      const settings = ReminderSettings(enabled: true, hour: 9, minute: 0);
      final afternoon = DateTime(2026, 5, 1, 15, 0);
      expect(settings.nextFireTime(afternoon), DateTime(2026, 5, 2, 9, 0));

      final morning = DateTime(2026, 5, 1, 7, 0);
      expect(settings.nextFireTime(morning), DateTime(2026, 5, 1, 9, 0));
    });
  });

  testWidgets('提醒设置页开关与时间持久化', (WidgetTester tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);

    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const ReminderSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 初始未开启，不显示提醒时间行。
    expect(find.text('每日提醒'), findsOneWidget);
    expect(find.text('提醒时间'), findsNothing);

    // 打开开关后出现时间行，但保存前不写 Controller/KV。
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('提醒时间'), findsOneWidget);
    expect(controller.reminderSettings.enabled, isFalse);
    expect(
      ReminderSettings.decode(store.read('verifin.reminder.v1')).enabled,
      isFalse,
    );

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(controller.reminderSettings.enabled, isTrue);
    expect(
      ReminderSettings.decode(store.read('verifin.reminder.v1')).enabled,
      isTrue,
    );

    controller.dispose();
  });
}
