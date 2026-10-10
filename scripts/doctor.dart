// 本机开发环境自检：Flutter 版本是否与 CI 一致、Android SDK/JDK/adb/gh 是否可用、
// 工作树是否干净。用于在真机调试或发版前一次性确认环境，避免「本地绿、CI 红」或
// 「构建到一半才发现 SDK 没装」。
//
// 用法：
//   dart run scripts/doctor.dart            # 基础自检
//   dart run scripts/doctor.dart --devices  # 附带 adb 设备列表
//
// 缺失工具的官方安装步骤见 docs/dev/android-development.md。

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/cli.dart';
import 'src/environment.dart';

enum _Level { pass, warn, fail }

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await _run(arguments);
  } on ScriptException catch (exception) {
    error(exception.message);
    exitCode = 1;
  }
}

Future<int> _run(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('devices', negatable: false, help: '同时查询 adb 已连接设备');

  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (exception) {
    error(exception.message);
    info(parser.usage);
    return 1;
  }

  final root = findRepoRoot();
  final results = <({String label, _Level level, String detail})>[];
  void add(String label, _Level level, String detail) =>
      results.add((label: label, level: level, detail: detail));

  step('自检 ${root.path}');

  // ---- Git / 工作树 ----
  if (!hasCommand('git')) {
    add('Git', _Level.fail, '未找到 git');
  } else {
    final branch = await capture(
      <String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
      allowFailure: true,
      workingDirectory: root,
    );
    final status = await capture(
      <String>['git', 'status', '--porcelain'],
      allowFailure: true,
      workingDirectory: root,
    );
    final dirty = status.stdout.trim().isNotEmpty;
    add(
      'Git',
      _Level.pass,
      '分支 ${branch.stdout.trim()}${dirty ? '（有未提交改动）' : '（工作树干净）'}',
    );
  }

  // ---- Flutter 版本必须与 CI 固定版本一致 ----
  final pinned = ciPinnedFlutterVersion(root);
  final flutter = await flutterInfo();
  if (flutter == null) {
    add('Flutter', _Level.fail, 'PATH 上找不到可用的 flutter');
  } else if (pinned == null) {
    add(
      'Flutter',
      _Level.warn,
      '${flutter.version}（${flutter.path}）；未能解析出 CI 固定版本',
    );
  } else if (flutter.version == pinned) {
    add('Flutter', _Level.pass, '${flutter.version}（与 CI 一致）');
  } else {
    add(
      'Flutter',
      _Level.fail,
      '本机 ${flutter.version} ≠ CI 固定 $pinned\n    ${flutter.path}\n'
          '    analyzer 的 lint 集合随版本变化，本地通过不代表 CI 通过。',
    );
  }

  // ---- 脚本运行时与 PATH 上的 Flutter 是否同一份 ----
  final scriptRoot = dartFlutterRoot();
  if (scriptRoot != null && flutter != null && flutter.root != null) {
    final same = p.normalize(scriptRoot) == p.normalize(flutter.root!);
    add(
      '脚本运行时',
      same ? _Level.pass : _Level.warn,
      same
          ? scriptRoot
          : '本脚本由 $scriptRoot 运行，与 PATH 上的 Flutter（${flutter.root}）不是同一份',
    );
  }

  // ---- local.properties 记录的 Flutter 路径 ----
  final localFlutter = localPropertiesFlutterSdk(root);
  if (localFlutter != null &&
      flutter != null &&
      flutter.root != null &&
      p.normalize(localFlutter) != p.normalize(flutter.root!)) {
    add(
      'local.properties',
      _Level.warn,
      'flutter.sdk=$localFlutter 与 PATH 上的 Flutter 不是同一份；'
          'Android 构建会用到另一个版本。删除该文件后重新 `flutter pub get` 即可写回当前 Flutter。',
    );
  }

  // ---- JDK ----
  final java = await javaVersion();
  if (java == null) {
    add('Java', _Level.fail, '未找到 java（CI 使用 Java 17）');
  } else if (java.major < 17) {
    add('Java', _Level.fail, '${java.raw}（需要 17 及以上）');
  } else {
    add('Java', _Level.pass, java.raw);
  }

  // ---- Android SDK ----
  final sdk = androidSdkPath(root);
  if (sdk == null) {
    add(
      'Android SDK',
      _Level.fail,
      '未找到：设置 ANDROID_HOME，或在 android/local.properties 写 sdk.dir',
    );
  } else {
    final validation = validateAndroidSdk(sdk);
    if (validation.usable) {
      add('Android SDK', _Level.pass, sdk);
    } else {
      add(
        'Android SDK',
        _Level.fail,
        '$sdk 缺少 ${validation.missing.join(' / ')} 内容（目录存在但为空）；'
            '按 docs/dev/android-development.md 用 sdkmanager 安装 platform-tools 与对应的 platforms/build-tools',
      );
    }
  }

  // ---- adb ----
  final adb = adbPath(sdk);
  if (adb == null) {
    add('adb', _Level.warn, '未找到（真机调试/安装需要）');
  } else {
    add('adb', _Level.pass, adb);
    if (options.flag('devices')) {
      final devices = await capture(<String>[
        adb,
        'devices',
        '-l',
      ], allowFailure: true);
      final lines = devices.stdout
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where(
            (line) => line.isNotEmpty && !line.startsWith('List of devices'),
          )
          .toList();
      add(
        '已连接设备',
        lines.isEmpty ? _Level.warn : _Level.pass,
        lines.isEmpty ? '未检测到设备' : lines.join('\n    '),
      );
    }
  }

  // ---- gh CLI（发布与清理预发布用） ----
  if (!hasCommand('gh')) {
    add('gh CLI', _Level.warn, '未找到（发布、清理预发布需要）');
  } else {
    final auth = await capture(<String>[
      'gh',
      'auth',
      'status',
    ], allowFailure: true);
    add(
      'gh CLI',
      auth.exitCode == 0 ? _Level.pass : _Level.warn,
      auth.exitCode == 0 ? '已登录' : '未登录（先执行 gh auth login）',
    );
  }

  info('');
  for (final result in results) {
    final text = '${result.label}：${result.detail}';
    switch (result.level) {
      case _Level.pass:
        success(text);
      case _Level.warn:
        warn(text);
      case _Level.fail:
        error(text);
    }
  }

  final failures = results.where((r) => r.level == _Level.fail).length;
  final warnings = results.where((r) => r.level == _Level.warn).length;
  info('');
  if (failures > 0) {
    error(
      '$failures 项未通过、$warnings 项警告。'
      '缺失工具的安装步骤见 docs/dev/android-development.md。',
    );
    return 1;
  }
  success('全部通过${warnings > 0 ? '（$warnings 项警告）' : ''}。');
  return 0;
}
