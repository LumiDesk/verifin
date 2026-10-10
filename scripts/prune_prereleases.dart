// 清理仓库里堆积的 GitHub 预发布（pre-release）。
//
// 背景：`scripts/publish.dart` 每次由 CI 创建「预发布」，真机验收后再手工提升为正式版；
// 没被提升的预发布会一直堆在 Releases 页面。本脚本用来一次性清理它们。
//
// 用法：
//   dart run scripts/prune_prereleases.dart                 列出、确认后删除（保留 git 标签）
//   dart run scripts/prune_prereleases.dart --dry-run       只列出将被删除的版本
//   dart run scripts/prune_prereleases.dart --yes           跳过确认
//   dart run scripts/prune_prereleases.dart --cleanup-tag   连同 git 标签一起删除
//   dart run scripts/prune_prereleases.dart --include-latest
//   dart run scripts/prune_prereleases.dart --repo owner/repo
//
// 安全约定：
// - 只处理「预发布且非草稿」的 Release；正式版与草稿一概不动。
// - 默认跳过被标记为 Latest 的 Release（即使它是预发布）。
// - 默认只删 Release 页面与其附件，**保留 git 标签**——标签是各版本的归档来源
//   （见 AGENTS.md「文档、CHANGELOG 与交付」）。要连标签一起删时加 --cleanup-tag。
// - 删除不可撤销（附件会一并消失）；先用 --dry-run 核对列表。

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

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
    ..addFlag('dry-run', negatable: false, help: '只列出将被删除的版本')
    ..addFlag('yes', abbr: 'y', negatable: false, help: '跳过确认')
    ..addFlag('cleanup-tag', negatable: false, help: '连同 git 标签一起删除')
    ..addFlag('include-latest', negatable: false, help: '允许删除被标记为 Latest 的预发布')
    ..addOption('repo', help: '指定仓库（默认取当前目录）');

  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (exception) {
    error(exception.message);
    info(parser.usage);
    return 1;
  }

  if (!hasCommand('gh')) {
    throw ScriptException('未找到 gh CLI。请先安装并 `gh auth login`。');
  }

  final repo = options.option('repo');
  final repoArgs = <String>[
    if (repo != null) ...<String>['--repo', repo],
  ];
  final includeLatest = options.flag('include-latest');
  final cleanupTag = options.flag('cleanup-tag');
  final dryRun = options.flag('dry-run');

  step('读取远端 Release 列表');
  final listing = await capture(<String>[
    'gh',
    'release',
    'list',
    '--limit',
    '1000',
    '--json',
    'tagName,isPrerelease,isDraft,isLatest',
    ...repoArgs,
  ]);

  final List<Object?> releases;
  try {
    releases = jsonDecode(listing.stdout) as List<Object?>;
  } on FormatException {
    throw ScriptException('无法解析 gh 返回的 Release 列表。');
  }

  final targets = <String>[];
  var skippedLatest = 0;
  for (final entry in releases) {
    if (entry is! Map) {
      continue;
    }
    final isPrerelease = entry['isPrerelease'] == true;
    final isDraft = entry['isDraft'] == true;
    final isLatest = entry['isLatest'] == true;
    if (!isPrerelease || isDraft) {
      continue;
    }
    if (isLatest && !includeLatest) {
      skippedLatest++;
      continue;
    }
    final tag = entry['tagName'];
    if (tag is String && tag.isNotEmpty) {
      targets.add(tag);
    }
  }

  if (targets.isEmpty) {
    success('没有需要清理的预发布版本。');
    return 0;
  }

  info('将删除 ${targets.length} 个预发布版本：');
  for (final tag in targets) {
    info('  - $tag');
  }
  if (!cleanupTag) {
    info('（保留对应的 git 标签；要一起删除请加 --cleanup-tag）');
  }
  if (skippedLatest > 0) {
    info('（已跳过 $skippedLatest 个标记为 Latest 的版本；需要一并删除请加 --include-latest）');
  }

  if (dryRun) {
    success('dry-run 结束：未做任何删除。');
    return 0;
  }

  if (!options.flag('yes') && !confirm('确认删除这 ${targets.length} 个预发布？')) {
    info('已取消。');
    return 1;
  }

  var deleted = 0;
  for (final tag in targets) {
    final result = await capture(<String>[
      'gh',
      'release',
      'delete',
      tag,
      '--yes',
      if (cleanupTag) '--cleanup-tag',
      ...repoArgs,
    ], allowFailure: true);
    if (result.exitCode == 0) {
      deleted++;
      info('  已删除 $tag');
    } else {
      warn('删除失败：$tag（${result.stderr.trim()}）');
    }
  }

  if (deleted == targets.length) {
    success('完成：已删除 $deleted/${targets.length} 个预发布版本。');
    return 0;
  }
  error('完成：仅删除 $deleted/${targets.length} 个预发布版本。');
  return 1;
}
