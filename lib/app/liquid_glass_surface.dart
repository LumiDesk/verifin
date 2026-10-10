import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 液态玻璃面板的填色：浅色偏白、深色偏黑，保持内容可见。
Color veriLiquidGlassTint(Brightness brightness) =>
    brightness == Brightness.dark
    ? Colors.white.withValues(alpha: 0.055)
    : Colors.white.withValues(alpha: 0.14);

/// 归一化边界位置与法线决定高光：左上/右下强，另外两个角衰减到零。
double veriLiquidGlassEdgeLight(
  Offset point,
  Offset normal, {
  double motion = 0,
}) {
  final angle = math.pi / 4 + motion.clamp(-1.0, 1.0) * 0.32;
  final facing = normal.dx * -math.cos(angle) + normal.dy * -math.sin(angle);
  final diagonal = (point.dx + point.dy - 1).abs().clamp(0.0, 1.0);
  return math.pow(facing.abs(), 2.2).toDouble() *
      math.pow(diagonal, 0.65).toDouble() *
      (facing >= 0 ? 1 : 0.88);
}

/// 沿曲面边缘绘制局部柔光与细高光，不绘制整圈均匀描边。
class VeriLiquidGlassLightPainter extends CustomPainter {
  const VeriLiquidGlassLightPainter({
    required this.radius,
    this.borderRadius,
    this.brightness = Brightness.light,
    this.activity = 0,
    this.motion = 0,
    this.opacity = 1,
  });

  final double radius;
  final BorderRadius? borderRadius;
  final Brightness brightness;
  final double activity;
  final double motion;
  final double opacity;

  double get peakOpacity => brightness == Brightness.dark ? 0.22 : 0.46;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 2 || opacity <= 0) {
      return;
    }
    final outline = _outlineFor(
      size: size,
      radius: radius,
      borderRadius: borderRadius,
    );
    final points = outline.points;
    final normals = outline.normals;
    final lights = <double>[
      for (var i = 0; i < points.length; i++)
        veriLiquidGlassEdgeLight(
          Offset(points[i].dx / size.width, points[i].dy / size.height),
          normals[i],
          motion: motion,
        ),
    ];

    void drawRibbon(double halfWidth, double strength) {
      const offsets = <double>[-1.0, -0.5, 0.0, 0.5, 1.0];
      const weights = <double>[0.0, 0.35, 1.0, 0.35, 0.0];
      final positions = <Offset>[];
      final colors = <Color>[];
      for (var i = 0; i < points.length; i++) {
        for (var j = 0; j < offsets.length; j++) {
          positions.add(points[i] + normals[i] * (offsets[j] * halfWidth));
          colors.add(
            Colors.white.withValues(
              alpha: (lights[i] * strength * weights[j]).clamp(0.0, 1.0),
            ),
          );
        }
      }
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: outline.indices,
      );
      canvas.drawVertices(vertices, BlendMode.dst, Paint());
      vertices.dispose();
    }

    drawRibbon(
      3.8 + activity * 1.6,
      (peakOpacity * 0.20 + activity * 0.04) * opacity,
    );
    drawRibbon(
      0.85 + activity * 0.5,
      (peakOpacity + activity * 0.10) * opacity,
    );
  }

  @override
  bool shouldRepaint(VeriLiquidGlassLightPainter oldDelegate) =>
      brightness != oldDelegate.brightness ||
      opacity != oldDelegate.opacity ||
      radius != oldDelegate.radius ||
      borderRadius != oldDelegate.borderRadius ||
      activity != oldDelegate.activity ||
      motion != oldDelegate.motion;
}

/// 轮廓采样结果：同一尺寸与圆角下 Path、弧长与切点都不变。
class _GlassOutline {
  const _GlassOutline({
    required this.points,
    required this.normals,
    required this.indices,
  });

  final List<Offset> points;
  final List<Offset> normals;
  final List<int> indices;
}

const int _glassOutlineCacheLimit = 24;
final Map<String, _GlassOutline> _glassOutlineCache = <String, _GlassOutline>{};

_GlassOutline _outlineFor({
  required Size size,
  required double radius,
  BorderRadius? borderRadius,
}) {
  final key =
      '${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}'
      '|$radius|${borderRadius ?? ''}';
  final cached = _glassOutlineCache[key];
  if (cached != null) {
    return cached;
  }
  final rect = (Offset.zero & size).deflate(0.7);
  final rrect = borderRadius == null
      ? RRect.fromRectAndRadius(rect, Radius.circular(radius))
      : RRect.fromRectAndCorners(
          rect,
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
          bottomLeft: borderRadius.bottomLeft,
          bottomRight: borderRadius.bottomRight,
        );
  // 把整条轮廓组成连续的透明度网格，两次绘制完成柔光与细高光；不为每 2dp
  // 小段建立 MaskFilter 离屏任务，避免放大原生 GPU 资源压力。
  final metric = (Path()..addRRect(rrect)).computeMetrics().first;
  final samples = (metric.length / 2).ceil().clamp(12, 1024);
  final points = <Offset>[];
  final normals = <Offset>[];
  for (var i = 0; i <= samples; i++) {
    final tangent = metric.getTangentForOffset(
      i == samples ? 0 : metric.length * i / samples,
    )!;
    points.add(tangent.position);
    normals.add(Offset(tangent.vector.dy, -tangent.vector.dx));
  }
  const offsetCount = 5;
  final indices = <int>[];
  for (var i = 0; i < samples; i++) {
    for (var j = 0; j < offsetCount - 1; j++) {
      final a = i * offsetCount + j;
      final b = a + offsetCount;
      indices.addAll(<int>[a, b, a + 1, a + 1, b, b + 1]);
    }
  }
  if (_glassOutlineCache.length >= _glassOutlineCacheLimit) {
    _glassOutlineCache.clear();
  }
  final outline = _GlassOutline(
    points: points,
    normals: normals,
    indices: indices,
  );
  _glassOutlineCache[key] = outline;
  return outline;
}

/// 共用玻璃内容表面：背景模糊、中性填色与沿边缘的方向高光。
///
/// 只服务于可选的液态玻璃底栏样式。
class VeriLiquidGlassSurface extends StatelessWidget {
  const VeriLiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = 999,
    this.borderRadius,
    this.grouped = false,
    this.tint,
    this.enabled = true,
    this.blurSigma = 16,
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final bool grouped;
  final Color? tint;
  final bool enabled;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final borderRadius = this.borderRadius ?? BorderRadius.circular(radius);
    final surface = highContrast
        ? veriContentSurfaceColor(brightness)
        : tint ?? veriLiquidGlassTint(brightness);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
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
    // 高对比度下不做模糊，直接用实色表面保证可读性。
    final filtered = highContrast
        ? content
        : grouped
        ? BackdropFilter.grouped(
            blendMode: BlendMode.srcOver,
            filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: content,
          )
        : BackdropFilter(
            blendMode: BlendMode.srcOver,
            filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: content,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: highContrast
            ? null
            : VeriLiquidGlassLightPainter(
                radius: radius,
                borderRadius: borderRadius,
                brightness: brightness,
              ),
        child: ClipRRect(borderRadius: borderRadius, child: filtered),
      ),
    );
  }
}
