import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'glass_lighting.dart';

export 'app_theme.dart' show VeriGlassBackdrop;

/// Android 的逐段模糊高光已改为连续网格，并完成 release/R8 真机验收。
/// 仅开放 Android；其他尚未验收的平台仍不加载高级绘制资源。
bool get veriAdvancedMaterialAvailable =>
    defaultTargetPlatform == TargetPlatform.android;

/// 纯展示层依赖；偏好由根组件注入，不让绘制组件访问 Controller/KV。
class VeriMaterialScope extends InheritedWidget {
  const VeriMaterialScope({
    super.key,
    required this.advanced,
    required super.child,
  });
  final bool advanced;
  static bool advancedOf(BuildContext context) =>
      veriAdvancedMaterialAvailable &&
      veriGlassDesignPreview &&
      (context
              .dependOnInheritedWidgetOfExactType<VeriMaterialScope>()
              ?.advanced ??
          false);
  @override
  bool updateShouldNotify(VeriMaterialScope oldWidget) =>
      advanced != oldWidget.advanced;
}

/// 共用玻璃内容表面：背景模糊、中性填色和根据边缘法线绘制的方向高光。
/// 导航透镜的纹理采样另由 navigation_glass_lens.dart 负责。
class VeriGlassSurface extends StatelessWidget {
  const VeriGlassSurface({
    super.key,
    required this.child,
    this.radius = veriCardRadius,
    this.grouped = true,
    this.tint,
    this.enabled = true,
    this.reveal = 1,
  });
  final Widget child;
  final double radius;
  final bool grouped;
  final Color? tint;
  final bool enabled;

  /// 表面单独消退，不能用父级 Opacity 把背景模糊一起放入离屏层。
  final double reveal;

  @override
  Widget build(BuildContext context) {
    if (!veriGlassDesignPreview || !enabled) return child;
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final visibility = reveal.clamp(0.0, 1.0);
    final surface = highContrast
        ? veriContentSurfaceColor(brightness)
        : tint ?? veriGlassTint(brightness, overlay: !grouped);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: surface.a * visibility),
        borderRadius: borderRadius,
        border: highContrast
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3 * visibility),
              )
            : null,
      ),
      child: child,
    );
    final filtered = highContrast
        ? content
        : grouped
        ? BackdropFilter.grouped(
            blendMode: BlendMode.src,
            filter: ui.ImageFilter.blur(
              sigmaX: 16 * visibility,
              sigmaY: 16 * visibility,
            ),
            child: content,
          )
        : BackdropFilter(
            blendMode: BlendMode.src,
            filter: ui.ImageFilter.blur(
              sigmaX: 16 * visibility,
              sigmaY: 16 * visibility,
            ),
            child: content,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: (dark ? 0.18 : 0.055) * visibility,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter:
            highContrast || !VeriMaterialScope.advancedOf(context)
            ? null
            : VeriGlassLightPainter(
                radius: radius,
                brightness: brightness,
                opacity: visibility,
              ),
        child: ClipRRect(borderRadius: borderRadius, child: filtered),
      ),
    );
  }
}
