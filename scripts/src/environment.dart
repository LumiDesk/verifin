// 本机工具链探测：Flutter、Android SDK、Java、adb、gh。
//
// 这里只做「发现 + 判定」，不做安装；安装步骤与官方来源见
// docs/dev/android-development.md。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli.dart';

/// 从 .github/workflows/*.yml 读 CI 固定的 Flutter 版本（单一事实来源）。
String? ciPinnedFlutterVersion(Directory root) {
  final dir = Directory(p.join(root.path, '.github', 'workflows'));
  if (!dir.existsSync()) {
    return null;
  }
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.yml') && !file.path.endsWith('.yaml')) {
      continue;
    }
    final match = RegExp(
      r"flutter-version:\s*'?([0-9]+\.[0-9]+\.[0-9]+)'?",
    ).firstMatch(file.readAsStringSync());
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

/// PATH 上的 flutter：完整路径、安装根目录与版本。
Future<({String path, String? root, String version})?> flutterInfo() async {
  final path = resolveCommand('flutter');
  if (path == null) {
    return null;
  }
  final result = await capture(<String>[
    'flutter',
    '--version',
    '--machine',
  ], allowFailure: true);
  if (result.exitCode != 0) {
    return null;
  }
  try {
    final json = jsonDecode(result.stdout) as Map<String, Object?>;
    final version = json['frameworkVersion'] as String?;
    if (version == null || version.isEmpty) {
      return null;
    }
    return (path: path, root: p.dirname(p.dirname(path)), version: version);
  } on FormatException {
    return null;
  }
}

/// 运行本脚本的 Dart 解析出的 Flutter 根目录（`<root>/bin/cache/dart-sdk/bin/dart`）。
///
/// 用于提示「你正在用哪个 Flutter 跑脚本」——与 PATH 上的 flutter 不一致本身就是
/// 一个常见坑（Gradle 会按 Flutter 写入的 local.properties 选 SDK）。
String? dartFlutterRoot() {
  final executable = Platform.resolvedExecutable;
  final parts = p.split(executable);
  final cacheIndex = parts.lastIndexOf('cache');
  if (cacheIndex < 2 || parts[cacheIndex - 1] != 'bin') {
    return null;
  }
  return p.joinAll(parts.sublist(0, cacheIndex - 1));
}

/// android/local.properties 里的 `flutter.sdk`（Flutter 自动维护，不提交）。
String? localPropertiesFlutterSdk(Directory root) {
  final file = File(p.join(root.path, 'android', 'local.properties'));
  if (!file.existsSync()) {
    return null;
  }
  final match = RegExp(
    r'^flutter\.sdk\s*=\s*(.+)$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  return match?.group(1)!.trim().replaceAll(r'\\', r'\');
}

/// 解析 Android SDK 位置：环境变量 → local.properties → 常见安装目录。
String? androidSdkPath(Directory root) {
  for (final key in <String>['ANDROID_HOME', 'ANDROID_SDK_ROOT']) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty && Directory(value).existsSync()) {
      return value;
    }
  }
  final local = localPropertiesAndroidSdk(root);
  if (local != null && Directory(local).existsSync()) {
    return local;
  }
  for (final candidate in _commonSdkPaths()) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

/// android/local.properties 里的 `sdk.dir`。
String? localPropertiesAndroidSdk(Directory root) {
  final file = File(p.join(root.path, 'android', 'local.properties'));
  if (!file.existsSync()) {
    return null;
  }
  final match = RegExp(
    r'^sdk\.dir\s*=\s*(.+)$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  return match?.group(1)!.trim().replaceAll(r'\\', r'\');
}

/// SDK 是否真的可用：`platforms/` 与 `build-tools/` 都必须有内容。
///
/// 只看目录存在会漏掉「目录建了但 sdkmanager 从没装过东西」的情况。
({bool usable, List<String> missing}) validateAndroidSdk(String sdkPath) {
  final missing = <String>[];
  for (final name in <String>['platforms', 'build-tools']) {
    final dir = Directory(p.join(sdkPath, name));
    final hasContent =
        dir.existsSync() && dir.listSync().whereType<Directory>().isNotEmpty;
    if (!hasContent) {
      missing.add(name);
    }
  }
  return (usable: missing.isEmpty, missing: missing);
}

/// adb 路径：PATH 优先，其次 `<sdk>/platform-tools/adb`。
String? adbPath(String? sdkPath) {
  final fromPath = resolveCommand('adb');
  if (fromPath != null) {
    return fromPath;
  }
  if (sdkPath != null) {
    final candidate = p.join(
      sdkPath,
      'platform-tools',
      Platform.isWindows ? 'adb.exe' : 'adb',
    );
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

/// `java -version`（输出在 stderr）解析出主版本号。
Future<({int major, String raw})?> javaVersion() async {
  if (!hasCommand('java')) {
    return null;
  }
  final result = await capture(<String>[
    'java',
    '-version',
  ], allowFailure: true);
  final raw = '${result.stderr}\n${result.stdout}'.trim();
  final match = RegExp(r'version "(\d+)(?:\.(\d+))?').firstMatch(raw);
  if (match == null) {
    return null;
  }
  final first = int.parse(match.group(1)!);
  // Java 8 及以前是 1.8 这种形式，主版本取第二段。
  final major = first == 1 && match.group(2) != null
      ? int.parse(match.group(2)!)
      : first;
  return (major: major, raw: raw.split('\n').first.trim());
}

List<String> _commonSdkPaths() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final candidates = <String>[
    if (Platform.environment['LOCALAPPDATA'] != null)
      p.join(Platform.environment['LOCALAPPDATA']!, 'Android', 'Sdk'),
    if (home != null) p.join(home, 'Android', 'Sdk'),
    if (home != null) p.join(home, 'Library', 'Android', 'sdk'),
    if (Platform.isWindows) r'C:\Dev\android-sdk',
    if (Platform.isWindows) r'C:\Android\Sdk',
    '/usr/lib/android-sdk',
  ];
  return candidates;
}
