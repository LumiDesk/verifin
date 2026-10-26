import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/startup/startup_coordinator.dart';

void main() {
  test('按任务顺序推进，完成后进入 ready 并记录各阶段耗时', () async {
    var now = DateTime(2026, 1, 1);
    final executed = <StartupStage>[];
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        for (final stage in <StartupStage>[
          StartupStage.preferences,
          StartupStage.database,
          StartupStage.controller,
        ])
          (
            stage: stage,
            run: () async {
              executed.add(stage);
              now = now.add(const Duration(milliseconds: 20));
            },
          ),
      ],
      clock: () => now,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();

    expect(executed, <StartupStage>[
      StartupStage.preferences,
      StartupStage.database,
      StartupStage.controller,
    ]);
    expect(coordinator.stage, StartupStage.ready);
    expect(coordinator.isRunning, isFalse);
    expect(coordinator.error, isNull);
    expect(coordinator.failedStage, isNull);
    expect(coordinator.timings.length, 3);
    expect(
      coordinator.timings[StartupStage.database],
      const Duration(milliseconds: 20),
    );
    expect(coordinator.timingSummary, contains('database=20ms'));
  });

  test('阶段抛错时记录失败阶段并停止后续任务', () async {
    final executed = <StartupStage>[];
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (
          stage: StartupStage.preferences,
          run: () async => executed.add(StartupStage.preferences),
        ),
        (
          stage: StartupStage.database,
          run: () async {
            executed.add(StartupStage.database);
            throw StateError('database locked');
          },
        ),
        (
          stage: StartupStage.controller,
          run: () async => executed.add(StartupStage.controller),
        ),
      ],
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();

    expect(executed, <StartupStage>[
      StartupStage.preferences,
      StartupStage.database,
    ], reason: '失败后不应继续执行后续阶段');
    expect(coordinator.failedStage, StartupStage.database);
    expect(coordinator.stage, StartupStage.database);
    expect(coordinator.error, isA<StateError>());
    expect(coordinator.errorStack, isNotNull);
    expect(coordinator.isRunning, isFalse);
  });

  testWidgets('阶段超过阈值置 stalled，完成后自动清除', (tester) async {
    final gate = Completer<void>();
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (stage: StartupStage.controller, run: () => gate.future),
      ],
      stallThreshold: const Duration(milliseconds: 100),
    );
    addTearDown(coordinator.dispose);

    final started = coordinator.start();
    await tester.pump(const Duration(milliseconds: 150));
    expect(coordinator.stalled, isTrue);
    expect(coordinator.stage, StartupStage.controller);

    gate.complete();
    await started;
    expect(coordinator.stalled, isFalse);
    expect(coordinator.stage, StartupStage.ready);
  });

  testWidgets('abandon 后在途任务结束才回收资源，且旧结果不覆盖状态', (tester) async {
    final gate = Completer<void>();
    var released = 0;
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (stage: StartupStage.controller, run: () => gate.future),
      ],
      releaseResources: () async => released += 1,
    );
    addTearDown(coordinator.dispose);

    unawaited(coordinator.start());
    await tester.pump();
    expect(coordinator.isRunning, isTrue);

    coordinator.abandon();
    expect(coordinator.abandoned, isTrue);
    expect(coordinator.isRunning, isFalse);
    expect(released, 0, reason: '在途任务尚未结束，不能提前释放其资源');

    gate.complete();
    await tester.pump();
    expect(released, 1);
    expect(coordinator.stage, isNot(StartupStage.ready));
  });

  test('没有在途任务时 abandon 立即释放资源且只释放一次', () async {
    var released = 0;
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[(stage: StartupStage.preferences, run: () async {})],
      releaseResources: () async => released += 1,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    expect(coordinator.stage, StartupStage.ready);

    coordinator.abandon();
    coordinator.abandon();
    await Future<void>.delayed(Duration.zero);
    expect(released, 1);
  });

  test('释放失败通过回调上报，不影响后续状态', () async {
    Object? reported;
    final coordinator = StartupCoordinator(
      tasks: <StartupTask>[
        (
          stage: StartupStage.preferences,
          run: () async => throw StateError('x'),
        ),
      ],
      releaseResources: () async => throw StateError('release failed'),
      onReleaseError: (error, _) => reported = error,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    coordinator.abandon();
    await Future<void>.delayed(Duration.zero);

    expect(reported, isA<StateError>());
    expect(coordinator.failedStage, StartupStage.preferences);
  });
}
