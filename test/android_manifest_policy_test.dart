import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式 Manifest 明确禁用 Android 系统备份', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('桌面只注册固定模板 Provider，并统一接入 home_widget 配置 Activity', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".WidgetConfigurationActivity"'));
    expect(manifest, contains('HomeWidgetScheduledUpdateReceiver'));
    expect(manifest, contains('android:name=".QuickEntryWidgetProvider"'));
    expect(manifest, contains('android:name=".BudgetWidgetProvider"'));
    expect(manifest, contains('android:name=".NetWorthWidgetProvider"'));
    expect(manifest, contains('android:name=".TrendWidgetProvider"'));
  });
}
