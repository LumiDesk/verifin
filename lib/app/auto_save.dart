import 'dart:async';

import 'package:flutter/widgets.dart';

import 'logging/app_logger.dart';

/// 自动保存的可见状态。成功不提示，只有 [failed] 需要页面给用户反馈。
enum AutoSaveState { idle, saving, failed }

/// 自动保存协调器：防抖、合并连续改动、串行提交，并支持退出前冲刷。
///
/// 页面把「当前草稿写入持久化」的闭包交给它，之后每次用户改动调用
/// [schedule] 即可。它保证：
/// - 短时间内的多次改动只提交最后一次（[schedule] 重新计时）；
/// - 保存进行中又有改动时，当前保存完成后会用最新草稿再提交一次；
/// - 保存失败时保留「还有未保存改动」的状态，供返回守卫决定是否放行；
/// - [flush] 可取消防抖并等待/触发最后一次保存，供失焦与返回使用。
///
/// 协调器不读 Controller、不碰数据库；保存闭包决定写哪里。闭包返回 `false`
/// 表示这次保存没有落库（校验失败或持久化失败），协调器会进入 [failed]。
class AutoSave extends ChangeNotifier {
  AutoSave({
    required Future<bool> Function() save,
    this.logger,
    this.debounce = const Duration(milliseconds: 500),
    // 命名参数不能以下划线开头，无法用 initializing formal 直接初始化私有字段。
    // ignore: prefer_initializing_formals
  }) : _save = save;

  final Future<bool> Function() _save;

  /// 保存闭包抛出未捕获异常时记录；控制器内部的持久化错误通常已经由
  /// `onPersistError` 记录并提示，这里只兜底页面闭包自身的异常。
  final AppLogger? logger;

  /// 文本输入停止多久后提交。离散控件调用 [schedule] 时可传 `immediate: true`。
  final Duration debounce;

  Timer? _timer;
  bool _running = false;
  bool _disposed = false;
  bool _failed = false;
  int _revision = 0;
  int _savedRevision = 0;
  Future<bool>? _inFlight;
  AutoSaveState _state = AutoSaveState.idle;

  AutoSaveState get state => _state;

  /// 是否还有改动没有成功落库（包括正在保存的改动）。
  bool get hasPendingWork => _revision != _savedRevision || _running;

  /// 最近一次提交是否失败；失败后 [hasPendingWork] 仍为 true，直到重试成功。
  bool get hasFailed => _failed;

  /// 标记一次改动。`immediate` 用于开关、选择器等离散操作；文本输入用默认防抖。
  void schedule({bool immediate = false}) {
    if (_disposed) {
      return;
    }
    _revision += 1;
    if (_running) {
      // 当前保存循环结束时会发现 revision 变了，自动再提交一次。
      return;
    }
    _timer?.cancel();
    if (immediate) {
      _timer = null;
      unawaited(_run());
      return;
    }
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_run());
    });
  }

  /// 取消防抖并提交所有未落库的改动；返回最终是否成功。
  Future<bool> flush() {
    _timer?.cancel();
    _timer = null;
    if (_disposed) {
      return Future<bool>.value(false);
    }
    final inFlight = _inFlight;
    if (_running && inFlight != null) {
      return _flushAfter(inFlight);
    }
    if (_revision == _savedRevision) {
      return Future<bool>.value(true);
    }
    return _run();
  }

  Future<bool> _flushAfter(Future<bool> inFlight) async {
    final result = await inFlight;
    if (!result || _disposed) {
      return result;
    }
    if (_revision == _savedRevision) {
      return true;
    }
    // 等待期间又出现了新改动，再提交一次。
    return _run();
  }

  Future<bool> _run() {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    final existing = _inFlight;
    if (_running && existing != null) {
      return existing;
    }
    _timer?.cancel();
    _timer = null;
    _running = true;
    final completer = Completer<bool>();
    _inFlight = completer.future;
    unawaited(_runLoop(completer));
    return completer.future;
  }

  Future<void> _runLoop(Completer<bool> completer) async {
    var result = true;
    try {
      while (!_disposed) {
        final target = _revision;
        _setState(AutoSaveState.saving);
        result = await _invokeSave();
        if (!result) {
          _failed = true;
          _setState(AutoSaveState.failed);
          break;
        }
        _failed = false;
        _savedRevision = target;
        if (_revision == target) {
          _setState(AutoSaveState.idle);
          break;
        }
      }
    } finally {
      _running = false;
      _inFlight = null;
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
  }

  Future<bool> _invokeSave() async {
    try {
      return await _save();
    } on Object catch (error, stackTrace) {
      logger?.error(
        '自动保存失败',
        source: 'autosave',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _setState(AutoSaveState state) {
    if (_disposed || _state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// 把 [TextEditingController] 的文本变化接到自动保存上。
///
/// 输入法组合期间（拼音、日文等 `composing` 有效）不触发，避免把半截
/// 拼音写进库；组合结束后再按正常防抖提交。返回的函数用于移除监听。
VoidCallback bindAutoSaveText(
  TextEditingController controller,
  VoidCallback onChange,
) {
  void listener() {
    if (controller.value.composing.isValid) {
      return;
    }
    onChange();
  }

  controller.addListener(listener);
  return () => controller.removeListener(listener);
}
