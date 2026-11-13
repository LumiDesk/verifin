import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 触感的语义档位。业务代码只选择语义，具体落到哪个平台原语由
/// [VeriHaptics] 单点决定。
///
/// 档位从轻到重：`tick` < `tap` < `commit` < `emphasis`。四档全部使用
/// Android 长期可用的 `HapticFeedback` 原语；**不使用** API 30 才生效的
/// success / warning / error 通知常量——低版本会静默不执行且没有回退，
/// 会出现「新机器有反馈、旧机器没有」的设备差异。
enum VeriHaptic {
  /// 最轻的选择刻度：底栏切 Tab、分段控件、期间步进、选择器确认、图表点选。
  ///
  /// Android 映射 `CLOCK_TICK`。少数机型几乎不可感知；若真机评审确认，
  /// 只需在 [VeriHaptics] 的映射里改一行，调用点不用动。
  tick,

  /// 轻动作确认：数字键、开关、展开/折叠、拖动开始与落下、记账按钮。
  tap,

  /// 明确命令成功：保存记账、新建实体、还款、导入、备份、解锁。
  commit,

  /// 破坏性或失败：删除完成、校验失败、恢复失败、解锁失败。
  emphasis,
}

/// 全应用唯一的触感入口。
///
/// 业务代码**不得直接调用 `HapticFeedback`**（`test/haptics_usage_test.dart`
/// 守住这条约定）。是否启用由 `VeriFinController` 单向同步到 [enabled]，
/// 因此调用点不需要 `BuildContext`，也能覆盖独立 Flutter 引擎
/// （桌面组件配置页）。
///
/// 约定：
/// - 一次用户手势最多两次触感（拖动：开始 + 落下）；
/// - 只给**状态真的变化**的交互、以及**显式命令**的结果，静默自动保存不震；
/// - 触感是可选反馈：平台不支持或系统禁用时静默降级，不抛异常、不写日志。
abstract final class VeriHaptics {
  /// 设置开关在设备 KV 里的键；与 `VeriFinController` 共用同一个常量。
  static const String storageKey = 'verifin.haptics.v1';

  /// 运行时闸门。Controller 在载入、设置保存、导入、回滚与初始化数据时同步。
  static bool enabled = true;

  /// 测试注入：只记录语义档位，不经过平台通道。
  @visibleForTesting
  static void Function(VeriHaptic kind)? debugSink;

  static void tick() => fire(VeriHaptic.tick);

  static void tap() => fire(VeriHaptic.tap);

  static void commit() => fire(VeriHaptic.commit);

  static void emphasis() => fire(VeriHaptic.emphasis);

  /// 仅用于「刚打开触感开关」这一下：此时开关值还没落盘、闸门仍是关的，
  /// 需要绕过闸门给用户一次确认。其它场景一律用 [tick] / [tap] 等语义方法。
  static void preview() => _emit(VeriHaptic.tap);

  /// 按闸门发送。业务代码优先使用上面的语义方法；这里留给需要动态档位的场景。
  static void fire(VeriHaptic kind) {
    if (!enabled) {
      return;
    }
    _emit(kind);
  }

  static void _emit(VeriHaptic kind) {
    final sink = debugSink;
    if (sink != null) {
      sink(kind);
      return;
    }
    unawaited(_platformCall(kind));
  }

  /// 语义 → 平台原语。真机上若某一档不可感知，只改这里。
  ///
  /// Android 实际常量（Flutter 3.47）：`selectionClick` → `CLOCK_TICK`、
  /// `lightImpact` → `VIRTUAL_KEY`、`mediumImpact` → `KEYBOARD_TAP`、
  /// `heavyImpact` → `CONTEXT_CLICK`。
  static Future<void> _platformCall(VeriHaptic kind) async {
    try {
      switch (kind) {
        case VeriHaptic.tick:
          await HapticFeedback.selectionClick();
        case VeriHaptic.tap:
          await HapticFeedback.lightImpact();
        case VeriHaptic.commit:
          await HapticFeedback.mediumImpact();
        case VeriHaptic.emphasis:
          await HapticFeedback.heavyImpact();
      }
    } on Object {
      // 触感是可选反馈：平台通道缺失、设备不支持或系统关闭触感时静默降级。
      // 不写日志，避免每次点击都往环形缓冲里刷一条。
    }
  }

  /// 测试用：恢复默认闸门并清掉注入，避免用例之间互相污染。
  @visibleForTesting
  static void reset() {
    enabled = true;
    debugSink = null;
  }
}
