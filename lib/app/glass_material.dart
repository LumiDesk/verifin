import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';

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

/// Web/Android 共用的磨砂玻璃：裁切后的真实背景模糊、均匀中性填色和单层轮廓。
/// 不采集截图，不使用平台专属 Shader，不宣称模拟真实折射。
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
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.17 : 0.72),
        ),
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
      child: ClipRRect(borderRadius: borderRadius, child: filtered),
    );
  }
}
