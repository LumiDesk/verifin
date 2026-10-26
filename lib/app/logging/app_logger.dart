import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../local_storage/local_storage.dart';

/// 软件日志级别。
enum AppLogLevel {
  info,
  warning,
  error;

  String get storageValue => name;

  static AppLogLevel fromStorage(String? value) {
    return AppLogLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => AppLogLevel.info,
    );
  }
}

/// 一条软件日志记录：时间、级别、来源、消息。
@immutable
class AppLogRecord {
  const AppLogRecord({
    required this.time,
    required this.level,
    required this.message,
    this.source,
    this.stack,
  });

  final DateTime time;
  final AppLogLevel level;
  final String message;
  final String? source;
  final String? stack;

  Map<String, Object?> toJson() => <String, Object?>{
    'time': time.toIso8601String(),
    'level': level.storageValue,
    'message': message,
    if (source != null && source!.isNotEmpty) 'source': source,
    if (stack != null && stack!.isNotEmpty) 'stack': stack,
  };

  static AppLogRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final time = DateTime.tryParse(raw['time'] as String? ?? '');
    final message = raw['message'] as String?;
    if (time == null || message == null) return null;
    return AppLogRecord(
      time: time,
      level: AppLogLevel.fromStorage(raw['level'] as String?),
      message: message,
      source: raw['source'] as String?,
      stack: raw['stack'] as String?,
    );
  }
}

/// 应用内轻量日志：记录错误与关键事件到环形缓冲（最近 [_maxRecords] 条），
/// 持久化到 KV（设备本地、不进 JSON 备份），供「软件日志」页查看/复制/分享，
/// 方便用户反馈问题时提供诊断线索。
class AppLogger extends ChangeNotifier {
  AppLogger(this._store) : _storageKey = _mainStorageKey {
    _load();
  }

  /// 组件配置页（独立 Flutter 引擎）专用的 logger。
  ///
  /// 两个引擎同时整表写 `verifin.logs.v1` 会互相覆盖，所以配置引擎只写
  /// [widgetConfigStorageKey]；主引擎下次启动时合并进主日志并清掉该键，
  /// 用户仍然只需要看「软件日志」一处。
  AppLogger.widgetConfiguration(this._store)
    : _storageKey = widgetConfigStorageKey {
    _load();
  }

  static const String _mainStorageKey = 'verifin.logs.v1';

  /// 组件配置引擎的旁路日志键（设备本地，不进备份）。
  static const String widgetConfigStorageKey = 'verifin.logs.widget_config.v1';

  static const int _maxRecords = 200;
  static const int _maxStackCharacters = 12000;

  final LocalKeyValueStore _store;
  final String _storageKey;

  /// 最新在前。
  final List<AppLogRecord> _records = <AppLogRecord>[];

  /// 只读视图，最新记录在前。
  List<AppLogRecord> get records =>
      UnmodifiableListView<AppLogRecord>(_records);

  bool get isEmpty => _records.isEmpty;

  void info(String message, {String? source}) =>
      log(AppLogLevel.info, message, source: source);

  void warning(String message, {String? source}) =>
      log(AppLogLevel.warning, message, source: source);

  /// 记录一条错误；可附带原始异常对象（会拼接到消息末尾）。
  void error(
    String message, {
    String? source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final text = error == null ? message : '$message: $error';
    log(AppLogLevel.error, text, source: source, stackTrace: stackTrace);
  }

  void log(
    AppLogLevel level,
    String message, {
    String? source,
    StackTrace? stackTrace,
  }) {
    _add(
      AppLogRecord(
        time: DateTime.now(),
        level: level,
        message: message,
        source: source,
        stack: _normalizeStack(stackTrace?.toString()),
      ),
    );
  }

  /// 追加一条**已带原始时间戳**的记录。
  ///
  /// 供启动早期缓冲回放使用：`main()` 在 KV 打开前就把错误攒进
  /// `StartupErrorSink`，logger 可用后按原时间回放，日志里不会出现「所有
  /// 启动错误都发生在同一秒」的失真。正常记录仍走 [log]。
  void append(AppLogRecord record) {
    _add(
      AppLogRecord(
        time: record.time,
        level: record.level,
        message: record.message,
        source: record.source,
        stack: _normalizeStack(record.stack),
      ),
    );
  }

  void _add(AppLogRecord record) {
    _records.insert(0, record);
    if (_records.length > _maxRecords) {
      _records.removeRange(_maxRecords, _records.length);
    }
    _persist();
    notifyListeners();
  }

  static String? _normalizeStack(String? raw) {
    final trimmed = raw?.trimRight();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.length <= _maxStackCharacters
        ? trimmed
        : '${trimmed.substring(0, _maxStackCharacters)}\n[stack truncated]';
  }

  void clear() {
    if (_records.isEmpty) return;
    _records.clear();
    _persist();
    notifyListeners();
  }

  /// 导出为可复制/分享的纯文本，最新在前。
  String exportText() {
    final buffer = StringBuffer();
    for (var i = 0; i < _records.length; i += 1) {
      if (i > 0) buffer.writeln();
      buffer.writeln(exportRecord(_records[i]));
    }
    return buffer.toString().trimRight();
  }

  /// 单条记录的纯文本（时间 + 级别 + 来源 + 消息 + stack），供「复制这条」使用。
  static String exportRecord(AppLogRecord record) {
    final ts = record.time.toIso8601String();
    final src = (record.source == null || record.source!.isEmpty)
        ? ''
        : ' [${record.source}]';
    final buffer = StringBuffer()
      ..writeln('$ts ${record.level.name.toUpperCase()}$src ${record.message}');
    final stack = record.stack;
    if (stack != null && stack.isNotEmpty) {
      for (final line in stack.split('\n')) {
        buffer.writeln('  $line');
      }
    }
    return buffer.toString().trimRight();
  }

  void _load() {
    final raw = _store.read(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final record = AppLogRecord.fromJson(item);
            if (record != null) _records.add(record);
          }
          if (_records.length > _maxRecords) {
            _records.removeRange(_maxRecords, _records.length);
          }
        }
      } catch (_) {
        _store.delete(_storageKey);
      }
    }
    if (_storageKey == _mainStorageKey) {
      _mergeWidgetConfigurationLogs();
    }
  }

  /// 合并组件配置引擎写的旁路日志，并删除该键。
  ///
  /// 配置引擎与主引擎极少同时存活；即便同时写，按「时间 + 级别 + 来源 + 文本」
  /// 去重也不会让合并结果出现重复行。解析失败时直接丢弃旁路日志，不污染主日志。
  void _mergeWidgetConfigurationLogs() {
    final raw = _store.read(widgetConfigStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _store.delete(widgetConfigStorageKey);
        return;
      }
      final signatures = _records.map(_signatureOf).toSet();
      final merged = <AppLogRecord>[];
      for (final item in decoded) {
        final record = AppLogRecord.fromJson(item);
        if (record != null && signatures.add(_signatureOf(record))) {
          merged.add(record);
        }
      }
      if (merged.isNotEmpty) {
        _records
          ..addAll(merged)
          ..sort((a, b) => b.time.compareTo(a.time));
        if (_records.length > _maxRecords) {
          _records.removeRange(_maxRecords, _records.length);
        }
        _persist();
      }
      _store.delete(widgetConfigStorageKey);
    } catch (_) {
      _store.delete(widgetConfigStorageKey);
    }
  }

  static String _signatureOf(AppLogRecord record) =>
      '${record.time.toIso8601String()}|${record.level.name}|'
      '${record.source ?? ''}|${record.message}';

  void _persist() {
    _store.write(
      _storageKey,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
  }
}
