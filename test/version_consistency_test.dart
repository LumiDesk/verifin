import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';

/// 版本号有三个真源，`scripts/publish.*` 发版时一起改写：
/// `pubspec.yaml` 的 `version`、`lib/app/app_version.dart` 的 `appVersionLabel`、
/// `CHANGELOG.md` 顶部的版本段。手改漏一处不会报错，只会在发版后才暴露，
/// 因此把三者钉在一起。
void main() {
  test('pubspec、app_version 与 CHANGELOG 的版本号一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionLine = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(versionLine, isNotNull, reason: 'pubspec.yaml 缺少 version 行');
    final pubspecVersion = versionLine!.group(1)!;

    expect(
      appVersionLabel,
      'v$pubspecVersion',
      reason: 'lib/app/app_version.dart 的 appVersionLabel 与 pubspec.yaml 不一致',
    );

    final changelog = File('CHANGELOG.md').readAsStringSync();
    final topSection = RegExp(
      r'^##\s*\[(\d+\.\d+\.\d+)\]',
      multiLine: true,
    ).firstMatch(changelog);
    expect(topSection, isNotNull, reason: 'CHANGELOG.md 缺少 x.y.z 版本段');
    expect(
      topSection!.group(1),
      pubspecVersion.split('+').first,
      reason: 'CHANGELOG.md 顶部版本与 pubspec.yaml 不一致',
    );
  });
}
