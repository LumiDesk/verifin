/// Android MethodChannel 桥（channel：`verifin/app`）。
///
/// 出站能力（Flutter → 原生）按域拆分到三个 part 文件（另有本文件的
/// [AppSecurityBridge]），各域互不相干；新增原生能力放进对应域（或新开一个 part），
/// 不要再堆回一个类：
/// - [AppCaptureBridge]（platform_bridge_capture.dart）：快速记账磁贴入口、
///   分享/外部采集内容消费；
/// - [AppWidgetBridge]（platform_bridge_widget.dart）：桌面小组件预览渲染、
///   实例计数与点击路由；
/// - [AppStorageBridge]（platform_bridge_storage.dart）：系统下载目录写出、
///   备份目录 SAF 读写；
/// - [AppSecurityBridge]（本文件）：FLAG_SECURE 防截屏。
///
/// 入站调用（原生 → Flutter）受「一个 channel 只能挂一个 MethodCall 处理器」
/// 约束，统一由本文件的 [_ensureInboundDispatcher] 分发到各域注册的回调。
library;

import 'package:flutter/services.dart';

part 'platform_bridge_capture.dart';
part 'platform_bridge_storage.dart';
part 'platform_bridge_widget.dart';

const MethodChannel _channel = MethodChannel('verifin/app');

/// 挂接唯一的入站分发器。可重复调用（幂等覆盖同一实现）；各域的回调槽位
/// （[_quickEntryHandler] 等）在对应 part 里定义，分发时按当前值动态读取。
void _ensureInboundDispatcher() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openQuickEntry') {
      final handler = _quickEntryHandler;
      if (handler == null) {
        // Native keeps the pending flag until Shell mounts and consumes it.
        return;
      }
      // Consume before opening the UI so a process restart while the editor is
      // open cannot replay the same quick-entry intent on next launch.
      await AppCaptureBridge.consumeInitialQuickEntryIntent();
      await handler();
      return;
    }
    if (call.method == 'openSharedCapture') {
      await _sharedCaptureHandler?.call();
      return;
    }
    if (call.method == 'openWidgetRoute') {
      final args = Map<String, Object?>.from(
        call.arguments as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
      );
      if (!AppWidgetBridge.hasRouteHandler) {
        // Native keeps the pending route until Shell consumes it after the
        // consent/onboarding/app-lock gates become ready.
        return;
      }
      // Use the natively stored value as the single source of truth and clear
      // it atomically before navigating, avoiding duplicate route delivery.
      final route = await AppWidgetBridge.consumeInitialRoute() ?? args;
      await AppWidgetBridge.handleRoute(route);
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
