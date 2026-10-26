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
  AppLogger(this._store) {
    _load();
  }

  static const String _storageKey = 'verifin.logs.v1';
  static const int _maxRecords = 200;
  static const int _maxStackCharacters = 12000;

  final LocalKeyValueStore _store;

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
      final r = _records[i];
      final ts = r.time.toIso8601String();
      final src = (r.source == null || r.source!.isEmpty)
          ? ''
          : ' [${r.source}]';
      buffer.writeln('$ts ${r.level.name.toUpperCase()}$src ${r.message}');
      final stack = r.stack;
      if (stack != null && stack.isNotEmpty) {
        for (final line in stack.split('\n')) {
          buffer.writeln('  $line');
        }
      }
    }
    return buffer.toString().trimRight();
  }

  void _load() {
    final raw = _store.read(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        final record = AppLogRecord.fromJson(item);
        if (record != null) _records.add(record);
      }
      if (_records.length > _maxRecords) {
        _records.removeRange(_maxRecords, _records.length);
      }
    } catch (_) {
      _store.delete(_storageKey);
    }
  }

  void _persist() {
    _store.write(
      _storageKey,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
  }
}
