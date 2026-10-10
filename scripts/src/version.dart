// 版本号读写与递增：pubspec.yaml 的 `version: X.Y.Z+B` 与 lib/app/app_version.dart
// 的展示文案。纯逻辑集中在这里，便于单测（见 test/scripts_version_test.dart）。

import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli.dart';

/// 形如 `1.18.20+161` 的版本号。
class RepoVersion {
  const RepoVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  String get name => '$major.$minor.$patch';

  String get label => '$name+$build';

  String get tag => 'v$name';

  /// 按 `patch` / `minor` / `major` / 显式 `X.Y.Z` 计算下一个版本；构建号一律 +1。
  RepoVersion bump(String spec) {
    switch (spec) {
      case 'patch':
        return RepoVersion(
          major: major,
          minor: minor,
          patch: patch + 1,
          build: build + 1,
        );
      case 'minor':
        return RepoVersion(
          major: major,
          minor: minor + 1,
          patch: 0,
          build: build + 1,
        );
      case 'major':
        return RepoVersion(
          major: major + 1,
          minor: 0,
          patch: 0,
          build: build + 1,
        );
    }
    final explicit = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(spec);
    if (explicit == null) {
      throw ScriptException('版本参数非法：$spec（可用 patch / minor / major / 1.2.3）');
    }
    return RepoVersion(
      major: int.parse(explicit.group(1)!),
      minor: int.parse(explicit.group(2)!),
      patch: int.parse(explicit.group(3)!),
      build: build + 1,
    );
  }

  /// 解析 `X.Y.Z+B`（不接受前导 `v`）。
  static RepoVersion parseLabel(String label) {
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$',
    ).firstMatch(label.trim());
    if (match == null) {
      throw ScriptException('版本号格式不正确：$label（应为 X.Y.Z+B）');
    }
    return RepoVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  /// 从 pubspec.yaml 文本里解析 `version:` 行。
  static RepoVersion parsePubspec(String pubspecText) {
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspecText);
    if (match == null) {
      throw ScriptException('pubspec.yaml 里找不到 `version: X.Y.Z+B` 行。');
    }
    return parseLabel(match.group(1)!);
  }
}

File _pubspecFile(Directory root) => File(p.join(root.path, 'pubspec.yaml'));

File _appVersionFile(Directory root) =>
    File(p.join(root.path, 'lib', 'app', 'app_version.dart'));

/// 读取仓库当前版本。
RepoVersion readRepoVersion(Directory root) =>
    RepoVersion.parsePubspec(_pubspecFile(root).readAsStringSync());

/// 读取 app_version.dart 里的展示文案。
String readAppVersionLabel(Directory root) {
  final text = _appVersionFile(root).readAsStringSync();
  final match = RegExp(
    r"const String appVersionLabel = '([^']*)';",
  ).firstMatch(text);
  if (match == null) {
    throw ScriptException('lib/app/app_version.dart 里找不到 appVersionLabel。');
  }
  return match.group(1)!;
}

/// 把新版本写回 pubspec.yaml 与 app_version.dart。
///
/// 只替换目标片段、其余内容（含既有换行风格）原样保留，并以无 BOM 的 UTF-8 写回，
/// 避免不同编辑器/平台引入编码或行尾差异。
void writeRepoVersion(Directory root, RepoVersion next) {
  final pubspec = _pubspecFile(root);
  final pubspecText = pubspec.readAsStringSync();
  final updatedPubspec = pubspecText.replaceFirst(
    RegExp(r'^version: [^\r\n]*', multiLine: true),
    'version: ${next.label}',
  );
  if (updatedPubspec == pubspecText) {
    throw ScriptException('pubspec.yaml 的 version 行未被更新。');
  }
  pubspec.writeAsStringSync(updatedPubspec);

  final appVersion = _appVersionFile(root);
  final appVersionText = appVersion.readAsStringSync();
  final updatedAppVersion = appVersionText.replaceFirst(
    RegExp(r"const String appVersionLabel = '[^']*';"),
    "const String appVersionLabel = '${next.tag}+${next.build}';",
  );
  if (updatedAppVersion == appVersionText) {
    throw ScriptException('lib/app/app_version.dart 的 appVersionLabel 未被更新。');
  }
  appVersion.writeAsStringSync(updatedAppVersion);
}
