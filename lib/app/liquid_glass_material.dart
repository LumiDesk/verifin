import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 液态玻璃折射着色器是否可用。
///
/// `ImageFilter.shader` 只在 Impeller 下受支持，且本项目只交付 Android；
/// 任一条件不满足时样式整体退回「模糊玻璃」，不做折射。
bool get veriLiquidGlassRefractionAvailable =>
    defaultTargetPlatform == TargetPlatform.android &&
    ui.ImageFilter.isShaderFilterSupported;

/// 全进程共享的折射着色器程序。
///
/// 样式自身的 `buildBar` 是同步接口，因此程序在首次使用时异步加载，加载完成后
/// 由绘制组件重建一次；同一个 program 可为多个滤镜创建独立 shader 实例。
abstract final class VeriLiquidGlassProgram {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static bool _unavailable = false;

  static ui.FragmentProgram? get program => _program;

  static Future<void> load() {
    final loading = _loading;
    if (loading != null) {
      return loading;
    }
    if (_program != null ||
        _unavailable ||
        !veriLiquidGlassRefractionAvailable) {
      return Future<void>.value();
    }
    final future =
        ui.FragmentProgram.fromAsset('shaders/liquid_glass_refraction.frag')
            .then<void>((program) {
              _program = program;
            })
            .catchError((Object _) {
              // 纯渲染降级：着色器载入失败时保留模糊玻璃与全部交互，功能不受影响。
              _unavailable = true;
            });
    _loading = future;
    return future;
  }
}
