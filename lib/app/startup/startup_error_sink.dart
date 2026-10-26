import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

/// 启动早期的错误缓冲。
///
/// `main()` 在打开本地存储之前就要安装 `FlutterError.onError` 与 zone 兜底，
/// 而 [AppLogger] 依赖 KV 才存在。这里先把记录按**原始时间戳**攒在内存里，
/// 等 KV 打开、logger 构造完成后一次性回放——否则启动阶段的崩溃既进不了
/// 软件日志，也留不下任何可反馈的线索。
///
/// 只缓冲最近 [maxPending] 条：启动早期如果出现刷屏错误，旧记录价值迅速下降，
/// 不能让缓冲本身变成内存风险。
class StartupErrorSink {
  StartupErrorSink({this.maxPending = 50});

  final int maxPending;

  AppLogger? _logger;
  final List<AppLogRecord> _pending = <AppLogRecord>[];

  bool get hasLogger => _logger != null;

  /// 尚未回放的缓冲记录（按时间正序）。
  @visibleForTesting
  List<AppLogRecord> get pendingRecords =>
      List<AppLogRecord>.unmodifiable(_pending);

  /// 接到真实 logger 后回放缓冲记录；之后直接写 logger。
  ///
  /// 回放顺序：缓冲按时间正序，[AppLogger.append] 头插，最终仍是「最新在前」。
  void attach(AppLogger logger) {
    _logger = logger;
    if (_pending.isEmpty) {
      return;
    }
    final pending = List<AppLogRecord>.of(_pending);
    _pending.clear();
    for (final record in pending) {
      logger.append(record);
    }
  }

  void info(String message, {String? source}) =>
      _record(AppLogLevel.info, message, source: source);

  void warning(String message, {String? source}) =>
      _record(AppLogLevel.warning, message, source: source);

  void error(
    String message, {
    String? source,
    Object? error,
    StackTrace? stackTrace,
  }) => _record(
    AppLogLevel.error,
    message,
    source: source,
    error: error,
    stackTrace: stackTrace,
  );

  /// 把框架上报的错误（build/layout/paint、图片解码、插件 reportError）转成日志。
  ///
  /// 除了异常与 stack，还带上 `FlutterErrorDetails.context` 与
  /// `informationCollector`——它们是框架在「哪一行、哪个 Widget、哪个状态」上
  /// 给出的定位说明，比单句异常文本有用得多。
  void recordFlutterError(FlutterErrorDetails details) {
    final buffer = StringBuffer(details.exceptionAsString());
    final context = details.context;
    if (context != null) {
      _appendLine(buffer, 'Context: ${context.toDescription()}');
    }
    final collector = details.informationCollector;
    if (collector != null) {
      try {
        for (final node in collector()) {
          _appendLine(buffer, node.toDescription());
        }
      } catch (error, stackTrace) {
        // 收集器本身出错时保留原始异常信息，不要让诊断流程反过来吞掉它。
        _appendLine(buffer, 'Information collector failed: $error');
        _appendLine(buffer, '$stackTrace');
      }
    }
    _record(
      AppLogLevel.error,
      buffer.toString(),
      source: _flutterSource(details),
      stackTrace: details.stack,
    );
  }

  /// zone 兜底的未捕获异步错误。
  void recordUncaught(
    Object error,
    StackTrace stackTrace, {
    String source = 'zone',
  }) => _record(
    AppLogLevel.error,
    'Uncaught error',
    source: source,
    error: error,
    stackTrace: stackTrace,
  );

  void _record(
    AppLogLevel level,
    String message, {
    String? source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final text = error == null ? message : '$message: $error';
    final record = AppLogRecord(
      time: DateTime.now(),
      level: level,
      message: text,
      source: source,
      stack: stackTrace?.toString(),
    );
    final logger = _logger;
    if (logger != null) {
      logger.append(record);
      return;
    }
    if (_pending.length >= maxPending) {
      _pending.removeAt(0);
    }
    _pending.add(record);
  }

  static String _flutterSource(FlutterErrorDetails details) {
    final library = details.library;
    return library == null || library.isEmpty ? 'flutter' : 'flutter/$library';
  }

  static void _appendLine(StringBuffer buffer, String line) {
    if (line.trim().isEmpty) {
      return;
    }
    if (buffer.isNotEmpty) {
      buffer.write('\n');
    }
    buffer.write(line);
  }
}
