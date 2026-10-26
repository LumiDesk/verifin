import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/startup/startup_coordinator.dart';
import 'package:verifin/app/startup/startup_error_sink.dart';
import 'package:verifin/app/startup/verifin_bootstrap.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Clipboard.setData 走 SystemChannels.platform；测试宿主没有真实实现，
    // 这里给它一个成功的空响应，让「复制诊断」走通。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpBootstrap(
    WidgetTester tester, {
    required StartupErrorSink errors,
    required StartupCoordinator Function() createCoordinator,
  }) {
    tester.binding.platformDispatcher.localesTestValue = <Locale>[
      const Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    return tester.pumpWidget(
      VeriFinBootstrap(
        errors: errors,
        createCoordinator: createCoordinator,
        buildApp: () =>
            const MaterialApp(home: Scaffold(body: Text('APP_READY'))),
      ),
    );
  }

  testWidgets('首帧先显示启动页，初始化完成后切换到应用', (tester) async {
    final gate = Completer<void>();
    final errors = StartupErrorSink();
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (stage: StartupStage.database, run: () => gate.future),
      ],
    );

    await pumpBootstrap(
      tester,
      errors: errors,
      createCoordinator: () => coordinator,
    );

    expect(find.text('正在准备账本'), findsOneWidget);
    expect(find.text('打开账本数据库'), findsOneWidget);
    expect(find.text('APP_READY'), findsNothing);
    expect(
      errors.pendingRecords.any(
        (record) => record.message.contains('first frame rendered'),
      ),
      isTrue,
      reason: '首帧渲染后应留下启动日志，便于把「已出帧」与「还没出帧」区分开',
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('APP_READY'), findsOneWidget);
    expect(find.text('正在准备账本'), findsNothing);
  });

  testWidgets('失败页显示阶段与错误，可复制诊断并重试', (tester) async {
    final errors = StartupErrorSink();
    var created = 0;
    final failing = StartupCoordinator(
      tasks: <StartupTask>[
        (
          stage: StartupStage.controller,
          run: () async => throw StateError('controller failed'),
        ),
      ],
    );
    final succeeding = StartupCoordinator(tasks: const <StartupTask>[]);

    await pumpBootstrap(
      tester,
      errors: errors,
      createCoordinator: () {
        created += 1;
        return created == 1 ? failing : succeeding;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('启动没有完成'), findsOneWidget);
    expect(find.text('载入账本数据'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    final details = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data;
    expect(details, contains('controller failed'));

    await tester.tap(find.text('复制诊断信息'));
    await tester.pump();
    await tester.pump();
    expect(find.text('已复制'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(created, 2);
    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('阶段超时显示慢启动提示与重试，随后仍可正常进入', (tester) async {
    final gate = Completer<void>();
    final errors = StartupErrorSink();
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (stage: StartupStage.controller, run: () => gate.future),
      ],
      stallThreshold: const Duration(milliseconds: 100),
    );

    await pumpBootstrap(
      tester,
      errors: errors,
      createCoordinator: () => coordinator,
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('启动比平时慢'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('载入账本数据'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('数据库阶段失败时沿用「数据可能还在」的说明', (tester) async {
    final errors = StartupErrorSink();
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (
          stage: StartupStage.database,
          run: () async => throw StateError('locked'),
        ),
      ],
    );

    await pumpBootstrap(
      tester,
      errors: errors,
      createCoordinator: () => coordinator,
    );
    await tester.pumpAndSettle();

    expect(find.text('无法打开数据'), findsOneWidget);
    expect(find.textContaining('不要清除应用数据'), findsWidgets);
    expect(find.textContaining('重新安装最新版本'), findsOneWidget);
  });
}
