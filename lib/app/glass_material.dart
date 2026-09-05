import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'glass_lighting.dart';

/// 实际绘制在内容后方的低饱和背景。颜色来自背景，不在玻璃前景伪造折射。
class VeriGlassBackdrop extends StatelessWidget {
  const VeriGlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!veriGlassDesignPreview) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  veriGlassCanvasTopDark,
                  veriPreviewCanvasDark,
                  veriGlassCanvasBottomDark,
                ]
              : const [
                  veriGlassCanvasTopLight,
                  veriPreviewCanvasLight,
                  veriGlassCanvasBottomLight,
                ],
          stops: const [0, 0.50, 1],
        ),
      ),
      child: child,
    );
  }
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
  });
  final Widget child;
  final double radius;
  final bool grouped;
  final Color? tint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!veriGlassDesignPreview || !enabled) return child;
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: highContrast
            ? veriContentSurfaceColor(brightness)
            : tint ?? veriGlassTint(brightness, overlay: !grouped),
        borderRadius: borderRadius,
        border: highContrast
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: child,
    );
    final filtered = highContrast
        ? content
        : grouped
        ? BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: content,
          )
        : BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: content,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.055),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: highContrast
            ? null
            : VeriGlassLightPainter(radius: radius),
        child: ClipRRect(borderRadius: borderRadius, child: filtered),
      ),
    );
  }
}
