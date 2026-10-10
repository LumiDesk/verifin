// 仓库脚本（scripts/）共用的命令行工具：找仓库根、跑外部命令、输出与确认提示。
//
// 为什么脚本用 Dart 而不是 shell：Dart 是本项目必然存在的运行时（CI 固定 Flutter
// 3.47.2），跨平台只有一份实现，不需要 bash/python3/PowerShell 同时正确；并且
// `dart format` 与 `flutter analyze` 会把 scripts/ 一起纳入质量门禁。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 脚本执行失败。各入口脚本捕获后打印并返回非零退出码。
class ScriptException implements Exception {
  ScriptException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get _colorEnabled =>
    !Platform.environment.containsKey('NO_COLOR') && stdout.supportsAnsiEscapes;

String _paint(String text, String code) =>
    _colorEnabled ? '\u001B[${code}m$text\u001B[0m' : text;

/// 普通信息。
void info(String message) => stdout.writeln(message);

/// 阶段标题。
void step(String message) => stdout.writeln(_paint('▶ $message', '36'));

/// 成功结果。
void success(String message) => stdout.writeln(_paint('✓ $message', '32'));

/// 警告（不阻断）。
void warn(String message) => stdout.writeln(_paint('! $message', '33'));

/// 失败信息（写 stderr）。
void error(String message) => stderr.writeln(_paint('✗ $message', '31'));

/// 从当前目录向上寻找包含 `name: verifin` 的 pubspec.yaml 所在目录。
Directory findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final text = pubspec.readAsStringSync();
      if (RegExp(r'^name:\s*verifin\s*$', multiLine: true).hasMatch(text)) {
        return dir;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw ScriptException('未找到 verifin 仓库根目录；请在仓库内运行本脚本。');
    }
    dir = parent;
  }
}

/// 运行外部命令并实时转发 stdout/stderr；非零退出抛 [ScriptException]。
///
/// Windows 上必须 `runInShell`，否则无法解析 `flutter` / `gh` 这类 `.bat`/`.cmd`。
Future<void> run(List<String> command, {Directory? workingDirectory}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory?.path,
    runInShell: Platform.isWindows,
  );
  final out = process.stdout.pipe(stdout);
  final err = process.stderr.pipe(stderr);
  final code = await process.exitCode;
  await out;
  await err;
  if (code != 0) {
    throw ScriptException('命令失败（退出码 $code）：${command.join(' ')}');
  }
}

/// 运行外部命令并捕获 stdout；[allowFailure] 为假时非零退出抛 [ScriptException]。
Future<({int exitCode, String stdout, String stderr})> capture(
  List<String> command, {
  bool allowFailure = false,
  Directory? workingDirectory,
}) async {
  const utf8Loose = Utf8Codec(allowMalformed: true);
  final result = await Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory?.path,
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8Loose,
    stderrEncoding: utf8Loose,
  );
  final output = (
    exitCode: result.exitCode,
    stdout: (result.stdout as String?) ?? '',
    stderr: (result.stderr as String?) ?? '',
  );
  if (result.exitCode != 0 && !allowFailure) {
    final detail = output.stderr.trim();
    throw ScriptException(
      '命令失败（退出码 ${result.exitCode}）：${command.join(' ')}'
      '${detail.isEmpty ? '' : '\n$detail'}',
    );
  }
  return output;
}

/// PATH 上是否存在某个可执行文件。
bool hasCommand(String executable) {
  return resolveCommand(executable) != null;
}

/// 返回 PATH 上第一个匹配的可执行文件完整路径（找不到返回 null）。
String? resolveCommand(String executable) {
  const utf8Loose = Utf8Codec(allowMalformed: true);
  final finder = Platform.isWindows ? 'where' : 'which';
  final result = Process.runSync(
    finder,
    <String>[executable],
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8Loose,
    stderrEncoding: utf8Loose,
  );
  if (result.exitCode != 0) {
    return null;
  }
  final first = ((result.stdout as String?) ?? '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  return first.isEmpty ? null : first;
}

/// 交互确认：必须输入 `yes`（避免误触回车就执行破坏性操作）。
bool confirm(String question) {
  stdout.write('$question 输入 yes 继续：');
  final answer = stdin.readLineSync()?.trim();
  return answer == 'yes';
}

/// 目录/文件占用的字节数（不存在返回 0）。
int pathSize(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    return 0;
  }
  if (type == FileSystemEntityType.file) {
    return File(path).lengthSync();
  }
  var total = 0;
  for (final entity in Directory(
    path,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += entity.lengthSync();
      } on FileSystemException {
        // 权限/竞态导致的个别文件读不到时忽略，只用于估算释放空间。
      }
    }
  }
  return total;
}

/// 人类可读的字节数。
String formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// 删除路径（文件或目录），不存在时返回 false。
bool deletePath(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  switch (type) {
    case FileSystemEntityType.notFound:
      return false;
    case FileSystemEntityType.directory:
      Directory(path).deleteSync(recursive: true);
      return true;
    default:
      File(path).deleteSync();
      return true;
  }
}
