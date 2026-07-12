/// Android MethodChannel 桥（channel：`verifin/app`）。
///
/// 出站能力（Flutter → 原生）按域拆分为四个 Bridge 类，各在自己的 part 文件里、
/// 互不相干，新增原生能力放进对应域（或新开一个 part），不要再堆回一个类：
/// - [AppCaptureBridge]（platform_bridge_capture.dart）：快速记账磁贴入口、
///   分享/外部采集内容消费；
/// - [AppUpdateBridge]（platform_bridge_update.dart）：GitHub Release 更新
///   检查与下载；
/// - [AppWidgetBridge]（platform_bridge_widget.dart）：桌面小组件数据推送与
///   一键固定；
/// - [AppStorageBridge]（platform_bridge_storage.dart）：系统下载目录写出、
///   备份目录 SAF 读写；
/// - [AppSecurityBridge]（本文件）：FLAG_SECURE 防截屏。
///
/// 入站调用（原生 → Flutter）受「一个 channel 只能挂一个 MethodCall 处理器」
/// 约束，统一由本文件的 [_ensureInboundDispatcher] 分发到各域注册的回调。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'platform_bridge_capture.dart';
part 'platform_bridge_storage.dart';
part 'platform_bridge_update.dart';
part 'platform_bridge_widget.dart';

const MethodChannel _channel = MethodChannel('verifin/app');

/// 挂接唯一的入站分发器。可重复调用（幂等覆盖同一实现）；各域的回调槽位
/// （[_quickEntryHandler] 等）在对应 part 里定义，分发时按当前值动态读取。
void _ensureInboundDispatcher() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openQuickEntry') {
      await _quickEntryHandler?.call();
      return;
    }
    if (call.method == 'openSharedCapture') {
      await _sharedCaptureHandler?.call();
      return;
    }
    if (call.method == 'updateDownloadProgress') {
      final args = Map<String, Object?>.from(
        call.arguments as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      );
      AppUpdateBridge.updateProgress.value = UpdateDownloadProgress.fromMap(
        args,
      );
    }
  });
}

/// 应用安全相关的原生能力。
class AppSecurityBridge {
  AppSecurityBridge._();

  /// 开关 FLAG_SECURE：开启后应用内容不可截屏/录屏、且从最近任务缩略图中隐藏。
  /// 启用应用锁时打开，保护账户余额等敏感信息。非 Android 平台静默忽略。
  static Future<void> setSecureFlag(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecureFlag', {'secure': secure});
    } on MissingPluginException {
      // 非 Android / 测试宿主：无原生实现，忽略。
    } on PlatformException {
      // 原生调用失败不应影响功能。
    }
  }
}
