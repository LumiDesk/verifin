import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 液态玻璃透镜是否可用。
///
/// `ImageFilter.shader` 只在 Impeller 下受支持，且本项目只交付 Android；
/// 任一条件不满足时样式退回纯玻璃面板，不影响条目与交互。
bool get veriLiquidGlassLensAvailable =>
    defaultTargetPlatform == TargetPlatform.android &&
    ui.ImageFilter.isShaderFilterSupported;

/// 全进程共享的透镜着色器程序。
///
/// 样式的 `buildBar` 是同步接口，因此程序在首次使用时异步加载，加载完成后由
/// 透镜组件重建一次；同一个 program 可为多个滤镜创建独立 shader 实例。
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
    if (_program != null || _unavailable || !veriLiquidGlassLensAvailable) {
      return Future<void>.value();
    }
    final future =
        ui.FragmentProgram.fromAsset('shaders/liquid_glass_lens.frag')
            .then<void>((program) {
              _program = program;
            })
            .catchError((Object _) {
              // 纯渲染降级：着色器载入失败时保留玻璃面板与全部交互，功能不受影响。
              _unavailable = true;
            });
    _loading = future;
    return future;
  }
}

/// 液态玻璃底栏的背景折射着色器程序。
///
/// 基于 QWEA0 的 AGSL 液态玻璃：对胶囊底下的页面内容（backdrop）
/// 做模糊 + 折射 + 色散 + 染色 + 边缘光，一次性在着色器内完成。与透镜着色器
/// 相互独立，任一不可用都退回纯模糊玻璃面板，不影响条目与交互。
abstract final class VeriLiquidGlassBarProgram {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static bool _unavailable = false;

  static ui.FragmentProgram? get program => _program;

  static Future<void> load() {
    final loading = _loading;
    if (loading != null) {
      return loading;
    }
    if (_program != null || _unavailable || !veriLiquidGlassLensAvailable) {
      return Future<void>.value();
    }
    final future = ui.FragmentProgram.fromAsset('shaders/liquid_glass_bar.frag')
        .then<void>((program) {
          _program = program;
        })
        .catchError((Object _) {
          // 折射着色器载入失败时降级为模糊玻璃面板，功能不受影响。
          _unavailable = true;
        });
    _loading = future;
    return future;
  }
}

/// 液态玻璃底栏选中项（图标与文字）的主题色变体。
///
/// 原生栏采样底下页面的亮暗后选用其中一档：[overLight] 用于浅底（深色字系），
/// [overDark] 用于深底（浅色字系）。两档保持主色的色相，只调整明度。
class VeriLiquidGlassAccentPair {
  const VeriLiquidGlassAccentPair({
    required this.overLight,
    required this.overDark,
  });

  /// 浅底用：主色压暗到对浅色画布达到可读对比度。
  final Color overLight;

  /// 深底用：主色提亮到对深色画布达到可读对比度。
  final Color overDark;
}

/// 文字可读性的对比度下限（WCAG AA，常规文字 4.5:1）。
const double veriLiquidGlassTextContrast = 4.5;

/// 每一步调整的明度增量（HSL 明度，0–1）。
const double _kLightnessStep = 0.02;

/// 最多调整的步数：覆盖整个明度区间，保证循环必然结束。
const int _kMaxLightnessSteps = 50;

/// WCAG 相对亮度对比度，范围 1–21。
double veriContrastRatio(Color a, Color b) {
  final lighter = math.max(a.computeLuminance(), b.computeLuminance());
  final darker = math.min(a.computeLuminance(), b.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}

/// 把 [primary] 只沿明度方向调整，直到对 [background] 达到对比度下限。
///
/// 黑与白对任一画布都远超下限，因此循环总能在有限步内结束。
Color _accentAgainst(
  Color primary,
  Color background, {
  required bool towardDark,
}) {
  final hsl = HSLColor.fromColor(primary);
  var lightness = hsl.lightness;
  var candidate = primary;
  for (var step = 0; step < _kMaxLightnessSteps; step++) {
    if (veriContrastRatio(candidate, background) >=
        veriLiquidGlassTextContrast) {
      break;
    }
    final delta = towardDark ? -_kLightnessStep : _kLightnessStep;
    lightness = math.min(1.0, math.max(0.0, lightness + delta));
    candidate = hsl.withLightness(lightness).toColor();
  }
  return candidate;
}

/// 由主题主色派生液态玻璃底栏选中项的两档颜色，与原生栏的采样结果配对使用。
VeriLiquidGlassAccentPair veriLiquidGlassAccentPair(Color primary) {
  return VeriLiquidGlassAccentPair(
    overLight: _accentAgainst(primary, veriCanvasLight, towardDark: true),
    overDark: _accentAgainst(primary, veriCanvasDark, towardDark: false),
  );
}
