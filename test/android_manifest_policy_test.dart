import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式 Manifest 明确禁用 Android 系统备份', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('桌面只注册固定模板小组件，不注册用户自定义 Provider', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('android:name=".UserWidgetProvider"')));
    expect(
      manifest,
      isNot(contains('android:name=".UserWidgetConfigureActivity"')),
    );
    expect(manifest, contains('android:name=".QuickEntryWidgetProvider"'));
    expect(manifest, contains('android:name=".BudgetWidgetProvider"'));
    expect(manifest, contains('android:name=".NetWorthWidgetProvider"'));
    expect(manifest, contains('android:name=".TrendWidgetProvider"'));
  });
}
