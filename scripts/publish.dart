// 发布脚本：递增版本 → 质量门禁 → 提交/打标签/推送。
//
// 用法：
//   dart run scripts/publish.dart patch           # 1.18.20 → 1.18.21
//   dart run scripts/publish.dart minor
//   dart run scripts/publish.dart major
//   dart run scripts/publish.dart 1.2.3
//   dart run scripts/publish.dart patch --dry-run
//
// 推送标签会触发 CI 构建 APK/AAB 并创建 GitHub **预发布**；真机验收通过后在
// GitHub 上提升为正式版（Latest）。未被提升的预发布用
// `dart run scripts/prune_prereleases.dart` 清理。

import 'dart:io';

import 'package:args/args.dart';

import 'src/cli.dart';
import 'src/environment.dart';
import 'src/version.dart';

const String _usage = '''
用法：
  dart run scripts/publish.dart patch|minor|major|X.Y.Z [选项]

选项：
''';

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
    ..addFlag('dry-run', negatable: false, help: '只打印将要执行的步骤，不做任何改动')
    ..addFlag(
      'skip-version-check',
      negatable: false,
      help: '跳过「本机 Flutter 版本 == CI 固定版本」校验',
    );
  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (exception) {
    error(exception.message);
    info('$_usage${parser.usage}');
    return 1;
  }

  final root = findRepoRoot();
  final dryRun = options.flag('dry-run');

  if (options.rest.length != 1) {
    info('$_usage${parser.usage}');
    return 1;
  }
  final spec = options.rest.single;

  step('检查工作树');
  final status = await capture(<String>[
    'git',
    'status',
    '--porcelain',
  ], workingDirectory: root);
  if (status.stdout.trim().isNotEmpty) {
    if (!dryRun) {
      throw ScriptException('工作树不干净：发布提交会把无关改动一起带上。先提交或 stash。');
    }
    warn('工作树不干净（dry-run 只做检查，不写入）。');
  } else {
    success('工作树干净');
  }

  if (!options.flag('skip-version-check')) {
    step('校验 Flutter 版本');
    final pinned = ciPinnedFlutterVersion(root);
    final flutter = await flutterInfo();
    if (flutter == null) {
      throw ScriptException(
        'PATH 上找不到可用的 flutter。请把与 CI 一致的 Flutter 加入 PATH 后重试。',
      );
    }
    if (pinned == null) {
      warn('未能在 .github/workflows 里解析出 CI 固定的 Flutter 版本，跳过比对。');
    } else if (flutter.version != pinned) {
      throw ScriptException(
        '本机 Flutter ${flutter.version} 与 CI 固定版本 $pinned 不一致：'
        '本地通过不代表 CI 会通过（analyzer 的 lint 集合可能不同）。\n'
        '当前使用：${flutter.path}\n'
        '请切换/加入对应版本到 PATH 后重试，或加 --skip-version-check 强制继续。',
      );
    } else {
      success('Flutter ${flutter.version}（与 CI 一致）');
    }
  }

  step('计算下一个版本');
  final current = readRepoVersion(root);
  final next = current.bump(spec);
  info('  ${current.label} → ${next.label}（tag ${next.tag}）');

  for (final command in <List<String>>[
    <String>[
      'git',
      'rev-parse',
      '--verify',
      '--quiet',
      'refs/tags/${next.tag}',
    ],
  ]) {
    final local = await capture(
      command,
      allowFailure: true,
      workingDirectory: root,
    );
    if (local.exitCode == 0) {
      throw ScriptException('标签 ${next.tag} 已存在（本地）。');
    }
  }
  final remote = await capture(
    <String>[
      'git',
      'ls-remote',
      '--exit-code',
      '--tags',
      'origin',
      'refs/tags/${next.tag}',
    ],
    allowFailure: true,
    workingDirectory: root,
  );
  if (remote.exitCode == 0) {
    throw ScriptException('标签 ${next.tag} 已存在（origin）。');
  }
  success('标签可用');

  if (dryRun) {
    step('dry-run：将要执行');
    info('  1. 写入 pubspec.yaml 与 lib/app/app_version.dart：${next.label}');
    info(
      '  2. dart format . && flutter pub get && flutter analyze && flutter test',
    );
    info('  3. git add -A && git commit -m "chore: release ${next.tag}"');
    info(
      '  4. git tag ${next.tag} && git push origin main && git push origin ${next.tag}',
    );
    info('');
    success('dry-run 结束：未做任何改动。');
    return 0;
  }

  step('写入版本号');
  writeRepoVersion(root, next);
  success('pubspec.yaml / app_version.dart 已更新');

  step('质量门禁');
  await run(<String>['dart', 'format', '.'], workingDirectory: root);
  await run(<String>['flutter', 'pub', 'get'], workingDirectory: root);
  await run(<String>['flutter', 'analyze'], workingDirectory: root);
  await run(<String>['flutter', 'test'], workingDirectory: root);

  step('提交、打标签、推送');
  await run(<String>['git', 'add', '-A'], workingDirectory: root);
  await run(<String>[
    'git',
    'commit',
    '-m',
    'chore: release ${next.tag}',
  ], workingDirectory: root);
  await run(<String>['git', 'tag', next.tag], workingDirectory: root);
  await run(<String>['git', 'push', 'origin', 'main'], workingDirectory: root);
  await run(<String>[
    'git',
    'push',
    'origin',
    next.tag,
  ], workingDirectory: root);

  success('已推送 ${next.tag}（${next.label}）');
  info('CI 将构建 APK/AAB 并创建预发布；真机验收后在 GitHub 提升为正式版。');
  return 0;
}
