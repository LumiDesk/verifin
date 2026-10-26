import 'dart:async';
import 'dart:io';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/app_database.dart';
import '../../data/ledger_repository.dart';
import '../../local_storage/local_storage.dart';
import '../attachments/attachment_store.dart';
import '../logging/app_logger.dart';
import '../models.dart';
import '../veri_fin_controller.dart';
import 'startup_coordinator.dart';
import 'startup_error_sink.dart';

/// 一次启动尝试所创建的资源。
///
/// 每次 [AppStartup.createCoordinator] 都配一份新的 session：重试时旧 session
/// 被放弃并回收，新旧两轮不会互相覆盖同一批对象。
class StartupSession {
  LocalKeyValueStore? store;
  AppLogger? logger;
  AppDatabase? database;
  VeriFinController? controller;

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final controller = this.controller;
    this.controller = null;
    controller?.dispose();
    final database = this.database;
    this.database = null;
    if (database != null) {
      try {
        await database.close();
      } catch (_) {
        // 连接可能已关闭或从未真正打开：重试路径上的清理失败不阻断新一轮启动，
        // 真正的数据风险由 sqflite 自己保证（close 失败不会损坏库文件）。
      }
    }
    store = null;
    logger = null;
  }
}

/// 生产启动序列：偏好 → 数据库 → 控制器 → 补记周期账 → 可选的界面预热。
///
/// 与旧 `main()` 的区别只在**执行时机**：这段现在发生在首帧之后的启动页上，
/// 并且每个阶段都有看门狗与日志；顺序与副作用保持原样（补记仍先于备份/
/// 小组件推送的挂钩，后者由 `VeriFinApp.initState` 触发）。
class AppStartup {
  AppStartup({
    required this.errors,
    required this.systemIsEnglish,
    this.stallThreshold = const Duration(seconds: 8),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final StartupErrorSink errors;
  final bool systemIsEnglish;
  final Duration stallThreshold;
  final DateTime Function() _clock;

  StartupSession? _currentSession;

  /// 当前一轮启动创建的控制器；仅在 [StartupStage.ready] 之后读取。
  ///
  /// 取自「当前这一轮的 session」，重试后旧一轮晚到的控制器不会被误当成新结果。
  VeriFinController? get controller => _currentSession?.controller;

  StartupCoordinator createCoordinator() {
    final session = StartupSession();
    _currentSession = session;
    final tasks = <StartupTask>[
      (
        stage: StartupStage.preferences,
        run: () async {
          final store = await LocalKeyValueStore.create();
          session.store = store;
          final logger = AppLogger(store);
          session.logger = logger;
          // 从这里开始，启动错误直接落盘；之前的记录由 sink 回放。
          errors.attach(logger);
        },
      ),
      (
        stage: StartupStage.database,
        run: () async {
          session.database = await AppDatabase.open();
        },
      ),
      (
        stage: StartupStage.controller,
        run: () async {
          final store = session.store;
          final database = session.database;
          if (store == null || database == null) {
            throw StateError('启动顺序错误：偏好或数据库尚未就绪');
          }
          final supportDirectory = await getApplicationSupportDirectory();
          final controller = await VeriFinController.create(
            store,
            repository: SqliteLedgerRepository(database),
            attachmentStore: FileAttachmentStore(
              root: Directory(p.join(supportDirectory.path, 'attachments')),
            ),
            logger: session.logger,
            systemIsEnglish: systemIsEnglish,
          );
          session.controller = controller;
        },
      ),
      (
        stage: StartupStage.recurring,
        run: () async {
          final controller = session.controller;
          if (controller == null) {
            throw StateError('启动顺序错误：控制器尚未就绪');
          }
          await controller.applyDueRecurring(_clock());
        },
      ),
      (stage: StartupStage.warmUp, run: () => _warmUpGlass(session)),
    ];

    final coordinator = StartupCoordinator(
      tasks: tasks,
      stallThreshold: stallThreshold,
      releaseResources: session.dispose,
      onReleaseError: (error, stackTrace) => errors.error(
        'Startup resource cleanup failed',
        source: 'startup',
        error: error,
        stackTrace: stackTrace,
      ),
      clock: _clock,
    );
    _attachDiagnostics(coordinator);
    return coordinator;
  }

  /// 把状态变化写进软件日志：卡住、失败与各阶段耗时都留痕。
  void _attachDiagnostics(StartupCoordinator coordinator) {
    var stalledStage = StartupStage.ready;
    var failureLogged = false;
    var readyLogged = false;
    coordinator.addListener(() {
      if (coordinator.stalled && coordinator.stage != stalledStage) {
        stalledStage = coordinator.stage;
        errors.warning(
          'Startup stalled at ${coordinator.stage.name} after '
          '${coordinator.stageElapsed.inMilliseconds}ms '
          '(threshold ${stallThreshold.inMilliseconds}ms)',
          source: 'startup',
        );
      }
      final failure = coordinator.error;
      if (failure != null && !failureLogged) {
        failureLogged = true;
        errors.error(
          'Startup failed at ${coordinator.failedStage?.name ?? 'unknown'}',
          source: 'startup',
          error: failure,
          stackTrace: coordinator.errorStack,
        );
      }
      if (coordinator.stage == StartupStage.ready && !readyLogged) {
        readyLogged = true;
        errors.info(
          'Startup ready in ${coordinator.elapsed.inMilliseconds}ms '
          '(${coordinator.timingSummary})',
          source: 'startup',
        );
      }
    });
  }

  /// 液态玻璃底栏只在用户确实选用该样式时预热着色器。
  ///
  /// 它只影响首帧前的着色器编译，库本身在渲染时也会按需加载；因此这里**限时**
  /// 等待，超时就继续启动，绝不让一个可选的视觉预热卡住整个应用。
  Future<void> _warmUpGlass(StartupSession session) async {
    final controller = session.controller;
    if (controller == null) {
      return;
    }
    if (controller.navigationStylePreference !=
        NavigationStylePreference.liquidGlass) {
      errors.info(
        'Startup: liquid glass warm-up skipped '
        '(style=${controller.navigationStylePreference.name})',
        source: 'startup',
      );
      return;
    }
    try {
      await LiquidGlassWidgets.initialize(
        enablePerformanceMonitor: false,
      ).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      errors.warning(
        'Startup: liquid glass shader warm-up timed out; '
        'shaders will load on demand',
        source: 'startup',
      );
    } catch (error, stackTrace) {
      errors.error(
        'Startup: liquid glass shader warm-up failed',
        source: 'startup',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
