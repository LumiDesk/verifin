import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式 Manifest 明确禁用 Android 系统备份', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
  });
}
