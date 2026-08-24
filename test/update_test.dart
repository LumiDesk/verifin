import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/platform_bridge.dart';

import 'support/test_harness.dart';

const MethodChannel _channel = MethodChannel('verifin/app');

Map<String, Object?> _updateResult(String status) => <String, Object?>{
  'status': status,
  'message': switch (status) {
    'available' => '发现新版本 v9.9.9，可以下载并安装。',
    'downloaded' => '新版本 v9.9.9 已下载，可以立即安装。',
    _ => '已打开安装确认。',
  },
  'currentVersion': '1.15.1',
  'latestVersion': 'v9.9.9',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTestDatabases();

  test('并发下载请求复用同一个原生任务', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final download = Completer<Object?>();
    var downloadCalls = 0;
    messenger.setMockMethodCallHandler(_channel, (call) {
      if (call.method == 'downloadLatestUpdate') {
        downloadCalls += 1;
        return download.future;
      }
      return Future<Object?>.value(null);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
    });

    final first = AppUpdateBridge.downloadLatestUpdate();
    final second = AppUpdateBridge.downloadLatestUpdate();
    await Future<void>.delayed(Duration.zero);

    expect(downloadCalls, 1);
    expect(identical(first, second), isTrue);

    download.complete(_updateResult('installing'));
    final results = await Future.wait(<Future<UpdateCheckResult>>[
      first,
      second,
    ]);
    expect(
      results.map((result) => result.status),
      everyElement(UpdateCheckStatus.installing),
    );
  });

  testWidgets('下载期间不能关闭弹窗，重开后复用已下载安装包', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final download = Completer<Object?>();
    var downloadCalls = 0;
    var installCalls = 0;
    var cached = false;
    messenger.setMockMethodCallHandler(_channel, (call) {
      switch (call.method) {
        case 'checkLatestRelease':
          return Future<Object?>.value(
            _updateResult(cached ? 'downloaded' : 'available'),
          );
        case 'downloadLatestUpdate':
          downloadCalls += 1;
          return download.future;
        case 'installDownloadedUpdate':
          installCalls += 1;
          return Future<Object?>.value(_updateResult('installing'));
        case 'consumeQuickEntryIntent':
          return Future<Object?>.value(false);
        default:
          return Future<Object?>.value(null);
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
    });

    await pumpApp(tester);
    await tapBottomTab(tester, 3);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('检查更新'), 160);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('下载新版本'));
    await tester.pump();
    expect(downloadCalls, 1);
    expect(find.text('下载中'), findsOneWidget);

    // showDialog 的遮罩点击与 Android 系统返回都不能在下载时移除弹窗。
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(downloadCalls, 1);

    cached = true;
    download.complete(_updateResult('installing'));
    await tester.pumpAndSettle();
    expect(find.text('立即安装'), findsOneWidget);

    // 关闭并重新检查时，原生返回 downloaded，UI 直接恢复「立即安装」而非重下。
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('立即安装'), findsOneWidget);
    expect(find.text('下载新版本'), findsNothing);
    expect(downloadCalls, 1);

    await tester.tap(find.text('立即安装'));
    await tester.pumpAndSettle();
    expect(installCalls, 1);
  });
}
