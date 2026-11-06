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

  // Release 正文的唯一来源；CI 直接把它当 body，缺文件时在打 tag 之前就停下。
  final releaseNotes = File('${root.path}/docs/release-notes/${next.tag}.md');
  if (!releaseNotes.existsSync() || releaseNotes.lengthSync() == 0) {
    throw ScriptException(
      '缺少发布说明：docs/release-notes/${next.tag}.md\n'
      '按 docs/release-notes/_template.md 写好再发版；CI 会把它当 Release 正文。',
    );
  }
  success('发布说明就位：docs/release-notes/${next.tag}.md');

  // CHANGELOG 是用户可见变化的唯一清单；版本段缺失说明这版还没写变更记录。
  final changelog = File('${root.path}/CHANGELOG.md').readAsStringSync();
  if (!changelog.contains('## [${next.name}]')) {
    throw ScriptException('CHANGELOG.md 缺少 ## [${next.name}] 段；先记录用户可见变化再发版。');
  }
  success('CHANGELOG 段就位：## [${next.name}]');

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
    info(
      '  1. 切出 release/${next.tag}，写入 pubspec.yaml 与 lib/app/app_version.dart',
    );
    info(
      '  2. dart format . && flutter pub get && flutter analyze && flutter test',
    );
    info('  3. 提交 chore: release ${next.tag} 并推送分支');
    info('  4. 开 PR，等检查通过后合并（main 受保护分支）');
    info('  5. git tag ${next.tag} && git push origin ${next.tag}');
    info('');
    success('dry-run 结束：未做任何改动。');
    return 0;
  }

  final gh = await capture(
    <String>['gh', '--version'],
    allowFailure: true,
    workingDirectory: root,
  );
  if (gh.exitCode != 0) {
    throw ScriptException('找不到 gh CLI：合并受保护分支需要它，请安装并 gh auth login。');
  }

  // main 是受保护分支：发版提交必须走 PR，合并后才能在历史上打 tag；
  // 直接 push main 会被分支保护拒绝。
  final branch = 'release/${next.tag}';
  step('切出发版分支');
  await run(<String>['git', 'checkout', '-b', branch], workingDirectory: root);

  step('写入版本号');
  writeRepoVersion(root, next);
  success('pubspec.yaml / app_version.dart 已更新');

  step('质量门禁');
  await run(<String>['dart', 'format', '.'], workingDirectory: root);
  await run(<String>['flutter', 'pub', 'get'], workingDirectory: root);
  await run(<String>['flutter', 'analyze'], workingDirectory: root);
  await run(<String>['flutter', 'test'], workingDirectory: root);

  step('提交、开 PR、合并、打标签');
  await run(<String>['git', 'add', '-A'], workingDirectory: root);
  await run(<String>[
    'git',
    'commit',
    '-m',
    'chore: release ${next.tag}',
  ], workingDirectory: root);
  final sha = await capture(<String>[
    'git',
    'rev-parse',
    'HEAD',
  ], workingDirectory: root);
  await run(<String>[
    'git',
    'push',
    '-u',
    'origin',
    branch,
  ], workingDirectory: root);
  await run(<String>[
    'gh',
    'pr',
    'create',
    '--fill',
    '--base',
    'main',
  ], workingDirectory: root);
  info('等待 PR 检查（格式、analyze、测试都在 PR 上跑）…');
  await run(<String>[
    'gh',
    'pr',
    'checks',
    '--watch',
    '--interval',
    '20',
  ], workingDirectory: root);
  await run(<String>[
    'gh',
    'pr',
    'merge',
    '--merge',
    '--delete-branch',
  ], workingDirectory: root);

  await run(<String>['git', 'checkout', 'main'], workingDirectory: root);
  await run(<String>['git', 'pull', '--ff-only'], workingDirectory: root);
  await capture(
    <String>['git', 'branch', '-D', branch],
    allowFailure: true,
    workingDirectory: root,
  );
  await run(<String>[
    'git',
    'tag',
    next.tag,
    sha.stdout.trim(),
  ], workingDirectory: root);
  await run(<String>[
    'git',
    'push',
    'origin',
    next.tag,
  ], workingDirectory: root);

  success('已合并 PR 并推送 ${next.tag}（${next.label}）');
  info('CI 将构建 APK/AAB 并创建预发布；真机验收后在 GitHub 提升为正式版。');
  return 0;
}
