import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalKeyValueStore {
  /// 仅供测试：不接 SharedPreferences 的纯内存实现，进程重启即丢。
  /// **真实平台一律用 [create]**——误用此构造会静默丢失全部偏好。
  @visibleForTesting
  LocalKeyValueStore() : _preferences = null;

  LocalKeyValueStore._(this._preferences);

  final SharedPreferences? _preferences;
  final Map<String, String> _memory = <String, String>{};

  // 追踪未完成的异步落盘，供 [flush] 在应用切后台时等待其完成。
  final Set<Future<void>> _pending = <Future<void>>{};
  final List<(Object, StackTrace)> _pendingErrors = <(Object, StackTrace)>[];

  static Future<LocalKeyValueStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalKeyValueStore._(preferences);
  }

  String? read(String key) => _preferences?.getString(key) ?? _memory[key];

  void write(String key, String value) {
    _memory[key] = value;
    final preferences = _preferences;
    if (preferences != null) {
      _track(preferences.setString(key, value));
    }
  }

  /// 编辑页显式保存使用的可等待写入。只有平台确认写入成功后才更新内存镜像；
  /// 失败会抛出，让页面保留草稿而不是误报成功。
  Future<void> writeAndFlush(String key, String value) async {
    final preferences = _preferences;
    if (preferences != null) {
      final succeeded = await preferences.setString(key, value);
      if (!succeeded) {
        throw StateError('Failed to persist local preference');
      }
    }
    _memory[key] = value;
  }

  void delete(String key) {
    _memory.remove(key);
    final preferences = _preferences;
    if (preferences != null) {
      _track(preferences.remove(key));
    }
  }

  Future<void> deleteAndFlush(String key) async {
    final preferences = _preferences;
    if (preferences != null) {
      final succeeded = await preferences.remove(key);
      if (!succeeded) {
        throw StateError('Failed to delete local preference');
      }
    }
    _memory.remove(key);
  }

  void _track(Future<void> op) {
    final future = op.catchError((Object error, StackTrace stackTrace) {
      // fire-and-forget 调用不能把异常重新抛到未捕获 Zone；先记录，等 [flush]
      // 汇总抛出，由 Controller 统一写日志并展示“保存失败”。
      _pendingErrors.add((error, stackTrace));
    });
    _pending.add(future);
    unawaited(future.whenComplete(() => _pending.remove(future)));
  }

  /// 等待所有挂起的写入落盘。应用切到后台（paused/hidden）时调用，确保 setString
  /// 在进程可能被系统回收前完成刷盘——尤其是应用锁 / 隐私同意这类关键偏好，
  /// 否则「设完 PIN 立刻杀进程」可能丢失最后一次写入。
  Future<void> flush() async {
    await Future.wait(_pending.toList());
    if (_pendingErrors.isEmpty) {
      return;
    }
    final (error, stackTrace) = _pendingErrors.removeAt(0);
    _pendingErrors.clear();
    Error.throwWithStackTrace(error, stackTrace);
  }
}
