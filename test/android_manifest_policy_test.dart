import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式 Manifest 明确禁用 Android 系统备份', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('用户设计小组件声明为完整的 AppWidgetProvider', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".UserWidgetProvider"'));
    expect(
      manifest,
      isNot(
        contains('android:name=".UserWidgetProvider" android:enabled="false"'),
      ),
    );
    expect(manifest, contains('android:resource="@xml/user_widget_info"'));
    expect(manifest, contains('android.appwidget.action.APPWIDGET_UPDATE'));
  });
}
