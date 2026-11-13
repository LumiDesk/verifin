import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_version.dart';

/// 版本号有三个真源，`scripts/publish.*` 发版时一起改写：
/// `pubspec.yaml` 的 `version`、`lib/app/app_version.dart` 的 `appVersionLabel`、
/// `CHANGELOG.md` 顶部的版本段。手改漏一处不会报错，只会在发版后才暴露，
/// 因此把三者钉在一起。
///
/// 例外是发版流程的「已准备、待发版」窗口：发版材料（CHANGELOG 段 + 发布说明）
/// 会先经独立 PR 合入 `main`，此时 `CHANGELOG.md` 的顶段本来就会领先
/// `pubspec.yaml` 一个 patch，等 `scripts/publish.dart` 再递增版本。这个窗口必须
/// 严格限制为「恰好下一个 patch」且「发布说明已存在」，其余不一致仍然失败。
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
    final changelogVersion = topSection!.group(1)!;
    final pubspecName = pubspecVersion.split('+').first;

    if (changelogVersion != pubspecName) {
      final parts = pubspecName
          .split('.')
          .map(int.parse)
          .toList(growable: false);
      final preparedVersion = '${parts[0]}.${parts[1]}.${parts[2] + 1}';
      expect(
        changelogVersion,
        preparedVersion,
        reason:
            'CHANGELOG.md 顶部版本必须等于 pubspec.yaml，'
            '或恰好是下一个 patch（已准备、待发版）',
      );
      expect(
        File('docs/release-notes/v$changelogVersion.md').existsSync(),
        isTrue,
        reason:
            'CHANGELOG.md 领先 pubspec.yaml 时必须已有发布说明 '
            'docs/release-notes/v$changelogVersion.md',
      );
    }
  });
}
