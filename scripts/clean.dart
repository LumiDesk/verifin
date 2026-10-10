// 清理本地构建产物与缓存，并报告释放的空间。
//
// 比直接 `flutter clean` 多做的事：一并清掉 Android 侧残留（Gradle / Kotlin / CMake
// 构建缓存）、支持 --dry-run 预览、打印各项占用与释放总量。
//
// 用法：
//   dart run scripts/clean.dart                 # 全清（之后需要 flutter pub get）
//   dart run scripts/clean.dart --keep-pub      # 保留 .dart_tool（不用重新 pub get）
//   dart run scripts/clean.dart --dry-run       # 只报告占用，不删除

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/cli.dart';

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
    ..addFlag('dry-run', negatable: false, help: '只报告占用，不删除')
    ..addFlag(
      'keep-pub',
      negatable: false,
      help: '保留 .dart_tool（不用重新 pub get）',
    );

  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (exception) {
    error(exception.message);
    info(parser.usage);
    return 1;
  }

  final root = findRepoRoot();
  final keepPub = options.flag('keep-pub');
  final dryRun = options.flag('dry-run');

  final targets = <String>[
    p.join(root.path, 'build'),
    if (!keepPub) p.join(root.path, '.dart_tool'),
    p.join(root.path, 'android', '.gradle'),
    p.join(root.path, 'android', '.kotlin'),
    p.join(root.path, 'android', 'app', '.cxx'),
  ];

  var freed = 0;
  var removed = 0;
  for (final target in targets) {
    final size = pathSize(target);
    final exists =
        size > 0 ||
        FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound;
    if (!exists) {
      continue;
    }
    final label = p.relative(target, from: root.path);
    if (dryRun) {
      info('  $label  ${formatBytes(size)}（dry-run，未删除）');
      continue;
    }
    step('删除 $label（${formatBytes(size)}）');
    deletePath(target);
    freed += size;
    removed++;
  }

  if (dryRun) {
    success('dry-run 结束：未做任何删除。');
    return 0;
  }
  if (removed == 0) {
    success('没有需要清理的构建产物。');
    return 0;
  }
  success('已清理 $removed 项，释放约 ${formatBytes(freed)}。');
  if (!keepPub) {
    info('提示：.dart_tool 已删除，下一次运行前先执行 `flutter pub get`。');
  }
  return 0;
}
