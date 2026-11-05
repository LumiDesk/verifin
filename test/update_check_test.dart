import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:verifin/app/external_links.dart';
import 'package:verifin/app/update/update_check.dart';

import 'support/test_harness.dart';

/// 从「我的」进设置页，并滚到「关于」组的检查更新行。
Future<void> _openSettings(WidgetTester tester) async {
  await tapBottomTab(tester, 3);
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('检查更新'), 200);
  await tester.ensureVisible(find.text('检查更新'));
  await tester.pumpAndSettle();
}

void main() {
  useTestDatabases();
  tearDown(() {
    debugUpdateCheckOverride = null;
    ExternalLinks.debugOpener = null;
  });

  group('版本比较', () {
    test('只比较数字段，忽略构建号与预发布后缀', () {
      expect(compareVersions('1.20.15', '1.20.15'), 0);
      expect(compareVersions('1.20.15+186', '1.20.15'), 0);
      expect(compareVersions('1.20.15-beta', '1.20.15'), 0);
      expect(compareVersions('1.20.16', '1.20.15'), greaterThan(0));
      expect(compareVersions('1.20.9', '1.20.15'), lessThan(0));
      expect(compareVersions('1.21', '1.20.99'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.20', '1.20.0'), 0);
    });

    test('当前版本号去掉展示前缀与构建号', () {
      expect(
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(currentAppVersionNumber()),
        isTrue,
      );
    });
  });

  group('解析 Release 响应', () {
    test('更新的 tag 返回可跳转版本', () {
      final result = parseLatestRelease(
        jsonEncode(<String, Object?>{'tag_name': 'v1.21.0'}),
        currentVersion: '1.20.15',
      );
      expect(result, isA<UpdateAvailable>());
      final available = result as UpdateAvailable;
      expect(available.release.tag, 'v1.21.0');
      expect(available.release.version, '1.21.0');
    });

    test('同版本、旧版本与无 v 前缀都按版本号判断', () {
      for (final tag in <String>['v1.20.15', '1.20.15', 'v1.20.14']) {
        final result = parseLatestRelease(
          jsonEncode(<String, Object?>{'tag_name': tag}),
          currentVersion: '1.20.15',
        );
        expect(result, isA<UpdateUpToDate>(), reason: tag);
      }
    });

    test('非法响应一律归为失败而不是崩溃', () {
      final cases = <String, UpdateCheckResult>{
        'not json': parseLatestRelease('{', currentVersion: '1.0.0'),
        'array payload': parseLatestRelease('[]', currentVersion: '1.0.0'),
        'missing tag': parseLatestRelease(
          jsonEncode(<String, Object?>{'name': 'x'}),
          currentVersion: '1.0.0',
        ),
        'blank tag': parseLatestRelease(
          jsonEncode(<String, Object?>{'tag_name': '  '}),
          currentVersion: '1.0.0',
        ),
      };
      for (final entry in cases.entries) {
        expect(entry.value, isA<UpdateCheckFailed>(), reason: entry.key);
      }
    });
  });

  group('Release 页面跳转', () {
    test('合法 tag 打开对应版本的 Release 页面', () async {
      final opened = <Uri>[];
      ExternalLinks.debugOpener = (url) async {
        opened.add(url);
        return true;
      };
      final openedResult = await ExternalLinks.openVerifinRelease('v1.21.0');
      expect(openedResult, isTrue);
      expect(
        opened.single.toString(),
        'https://github.com/LumiDesk/verifin/releases/tag/v1.21.0',
      );
    });

    test('非法 tag 回落到 Releases 列表，不拼任意地址', () async {
      final opened = <Uri>[];
      ExternalLinks.debugOpener = (url) async {
        opened.add(url);
        return true;
      };
      for (final tag in <String>['../../evil', 'v1.2;drop', '']) {
        await ExternalLinks.openVerifinRelease(tag);
      }
      expect(opened, everyElement(Uri.parse(ExternalLinks.verifinReleasesUrl)));
      expect(opened, hasLength(3));
    });
  });

  group('旧版安装包缓存清理', () {
    test('删除 cacheDir/updates，目录不存在时静默通过', () async {
      final root = Directory.systemTemp.createTempSync('verifin-update-cache');
      addTearDown(() {
        if (root.existsSync()) {
          root.deleteSync(recursive: true);
        }
      });
      final incoming = Directory(p.join(root.path, 'updates', 'incoming'))
        ..createSync(recursive: true);
      File(
        p.join(incoming.path, 'verifin-v1.20.15.apk'),
      ).writeAsBytesSync(<int>[1, 2, 3]);

      await purgeLegacyUpdateDownloads(cacheRoot: root);
      expect(Directory(p.join(root.path, 'updates')).existsSync(), isFalse);

      // 已经清空后再次调用不应抛错。
      await purgeLegacyUpdateDownloads(cacheRoot: root);
    });
  });

  group('设置页交互', () {
    testWidgets('发现新版本弹窗展示版本，并只在点「前往」时打开浏览器', (tester) async {
      final opened = <Uri>[];
      ExternalLinks.debugOpener = (url) async {
        opened.add(url);
        return true;
      };
      debugUpdateCheckOverride = () async =>
          const UpdateAvailable(UpdateRelease(tag: 'v9.9.9', version: '9.9.9'));

      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.textContaining('最新版本：v9.9.9'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('前往'), findsOneWidget);

      // 先验证「关闭」只关弹窗。
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(opened, isEmpty);

      // 再打开一次，点「前往」跳系统浏览器。
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('前往'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        opened.single.toString(),
        'https://github.com/LumiDesk/verifin/releases/tag/v9.9.9',
      );
    });

    testWidgets('已是最新时只给轻提示，不弹窗', (tester) async {
      debugUpdateCheckOverride = () async => const UpdateUpToDate();

      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('已是最新版本'), findsOneWidget);
    });

    testWidgets('检查失败时给出错误轻提示，不弹窗', (tester) async {
      debugUpdateCheckOverride = () async =>
          const UpdateCheckFailed('http 503');

      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('检查更新失败，请稍后再试。'), findsOneWidget);
    });

    testWidgets('浏览器打不开时给出错误轻提示', (tester) async {
      ExternalLinks.debugOpener = (url) async => false;
      debugUpdateCheckOverride = () async =>
          const UpdateAvailable(UpdateRelease(tag: 'v9.9.9', version: '9.9.9'));

      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('前往'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('没能打开浏览器，请稍后再试。'), findsOneWidget);
    });

    testWidgets('检查中禁用重复触发，完成后恢复', (tester) async {
      final completer = Completer<UpdateCheckResult>();
      var calls = 0;
      debugUpdateCheckOverride = () {
        calls += 1;
        return completer.future;
      };

      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pump();

      expect(calls, 1);
      expect(find.text('检查中...'), findsOneWidget);

      await tester.tap(find.text('检查更新'));
      await tester.pump();
      expect(calls, 1);

      completer.complete(const UpdateUpToDate());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('已是最新版本'), findsOneWidget);
      expect(find.text('检查中...'), findsNothing);
      expect(find.text('GitHub Release'), findsOneWidget);
    });
  });
}
