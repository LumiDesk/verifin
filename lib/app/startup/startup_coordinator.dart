import 'dart:async';

import 'package:flutter/foundation.dart';

/// 启动阶段。只用于进度展示与日志，不承载业务语义。
///
/// 顺序即界面上的推进顺序；新增阶段时同步补一条本地化文案
/// （`startupStage*`）。
enum StartupStage {
  preferences,
  database,
  controller,
  recurring,
  warmUp,
  ready,
}

/// 一个启动任务：在 [stage] 期间执行 [run]，抛错即视为启动失败。
typedef StartupTask = ({StartupStage stage, Future<void> Function() run});

/// 串行执行启动任务，暴露进度、单阶段看门狗、失败原因与重试。
///
/// 设计取舍：
/// - **不做硬性超时终止**。卡住的阶段仍可能稍后完成，这里只把「超过
///   [stallThreshold] 仍未完成」上报为 [stalled]，由界面给出阶段、耗时与重试
///   入口；盲目杀掉一次可能成功的初始化只会让用户更难恢复。
/// - **每轮启动有独立 run id**。[abandon] 后旧任务即使晚到也不会覆盖新状态，
///   其创建的资源由 [releaseResources] 在任务结束后回收。
/// - 本类不依赖 Flutter UI、不写日志：调用方监听状态变化自行记录。
class StartupCoordinator extends ChangeNotifier {
  StartupCoordinator({
    required List<StartupTask> tasks,
    this.stallThreshold = const Duration(seconds: 8),
    Future<void> Function()? releaseResources,
    void Function(Object error, StackTrace stackTrace)? onReleaseError,
    DateTime Function()? clock,
  }) : _tasks = List<StartupTask>.unmodifiable(tasks),
       _clock = clock ?? DateTime.now {
    _releaseResources = releaseResources;
    _onReleaseError = onReleaseError;
  }

  final List<StartupTask> _tasks;
  late final Future<void> Function()? _releaseResources;
  late final void Function(Object error, StackTrace stackTrace)?
  _onReleaseError;
  final DateTime Function() _clock;

  /// 单阶段超过该时长仍未完成时置 [stalled]，界面据此提示并允许重试。
  final Duration stallThreshold;

  int _runId = 0;
  bool _inFlight = false;
  bool _abandoned = false;
  bool _released = false;
  bool _disposed = false;
  bool _running = false;
  StartupStage _stage = StartupStage.preferences;
  StartupStage? _failedStage;
  Object? _error;
  StackTrace? _errorStack;
  bool _stalled = false;
  DateTime? _startedAt;
  DateTime? _stageStartedAt;
  final Map<StartupStage, Duration> _timings = <StartupStage, Duration>{};
  Timer? _watchdog;

  bool get isRunning => _running;
  bool get abandoned => _abandoned;
  StartupStage get stage => _stage;
  StartupStage? get failedStage => _failedStage;
  Object? get error => _error;
  StackTrace? get errorStack => _errorStack;

  /// 当前阶段已超过 [stallThreshold]。
  bool get stalled => _stalled;

  /// 自本轮启动开始至今的时长。
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : _clock().difference(_startedAt!);

  /// 当前阶段已花费的时长（阶段结束后保留最后值）。
  Duration get stageElapsed => _stageStartedAt == null
      ? Duration.zero
      : _clock().difference(_stageStartedAt!);

  /// 已完成的各阶段耗时。
  Map<StartupStage, Duration> get timings =>
      Map<StartupStage, Duration>.unmodifiable(_timings);

  /// 一眼可读的阶段耗时摘要，供日志与诊断页使用。
  String get timingSummary => _timings.entries
      .map((entry) => '${entry.key.name}=${entry.value.inMilliseconds}ms')
      .join(', ');

  Future<void> start() async {
    final runId = ++_runId;
    _watchdog?.cancel();
    _watchdog = null;
    _running = true;
    _stalled = false;
    _failedStage = null;
    _error = null;
    _errorStack = null;
    _startedAt = _clock();
    _stageStartedAt = _startedAt;
    _timings.clear();
    _stage = _tasks.isEmpty ? StartupStage.ready : _tasks.first.stage;
    _notify();

    for (final task in _tasks) {
      if (!_isCurrent(runId)) {
        await _release();
        return;
      }
      _stage = task.stage;
      _stageStartedAt = _clock();
      _stalled = false;
      _watchdog?.cancel();
      _watchdog = Timer(stallThreshold, () {
        if (!_isCurrent(runId)) {
          return;
        }
        _stalled = true;
        _notify();
      });
      _notify();

      _inFlight = true;
      try {
        await task.run();
      } catch (error, stackTrace) {
        _inFlight = false;
        if (!_isCurrent(runId)) {
          await _release();
          return;
        }
        _stopWatchdog();
        _failedStage = task.stage;
        _error = error;
        _errorStack = stackTrace;
        _running = false;
        _stalled = false;
        _notify();
        return;
      }
      _inFlight = false;
      if (!_isCurrent(runId)) {
        await _release();
        return;
      }
      _stopWatchdog();
      _timings[task.stage] = _clock().difference(_stageStartedAt!);
      _notify();
    }

    if (!_isCurrent(runId)) {
      await _release();
      return;
    }
    _running = false;
    _stalled = false;
    _stage = StartupStage.ready;
    _stageStartedAt = _clock();
    _notify();
  }

  /// 放弃当前轮：在途任务的结果立即失效，资源待任务结束后回收；
  /// 没有在途任务时立刻回收。可重复调用。
  void abandon() {
    if (_abandoned) {
      return;
    }
    _abandoned = true;
    _runId += 1;
    _stopWatchdog();
    _running = false;
    _stalled = false;
    if (!_inFlight) {
      unawaited(_release());
    }
    _notify();
  }

  @override
  void dispose() {
    // 先标记已释放，避免 abandon() 在 dispose 期间再通知监听者。
    _disposed = true;
    abandon();
    _stopWatchdog();
    super.dispose();
  }

  bool _isCurrent(int runId) => !_abandoned && runId == _runId;

  Future<void> _release() async {
    if (_released) {
      return;
    }
    _released = true;
    final release = _releaseResources;
    if (release == null) {
      return;
    }
    try {
      await release();
    } catch (error, stackTrace) {
      _onReleaseError?.call(error, stackTrace);
    }
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}
