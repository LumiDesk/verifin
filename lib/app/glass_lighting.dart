import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 归一化边界位置与法线决定高光：左上/右下强，另外两个角衰减到零。
double veriGlassEdgeLight(Offset point, Offset normal, {double motion = 0}) {
  final angle = math.pi / 4 + motion.clamp(-1.0, 1.0) * 0.32;
  final facing = normal.dx * -math.cos(angle) + normal.dy * -math.sin(angle);
  final diagonal = (point.dx + point.dy - 1).abs().clamp(0.0, 1.0);
  return math.pow(facing.abs(), 2.2).toDouble() *
      math.pow(diagonal, 0.65).toDouble() *
      (facing >= 0 ? 1 : 0.88);
}

/// 沿曲面边缘绘制局部柔光与细高光，不绘制整圈均匀描边。
class VeriGlassLightPainter extends CustomPainter {
  const VeriGlassLightPainter({
    required this.radius,
    this.borderRadius,
    this.brightness = Brightness.light,
    this.activity = 0,
    this.motion = 0,
    this.opacity = 1,
  });
  final double radius;

  /// 显式圆角；缺省时用 [radius] 生成四角等圆角。底部弹窗传入只圆顶部的圆角。
  final BorderRadius? borderRadius;
  final Brightness brightness;
  double get peakOpacity => brightness == Brightness.dark ? 0.22 : 0.46;
  final double activity;
  final double motion;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 2 || opacity <= 0) return;
    // 轮廓采样（Path 求长 + 逐点切线）只跟尺寸与圆角有关，缓存后拖动导航时
    // 每帧不必再重建上千个切点；只有光照强度随 motion 重算。
    final outline = _outlineFor(
      size: size,
      radius: radius,
      borderRadius: borderRadius,
    );
    final points = outline.points;
    final normals = outline.normals;
    final lights = <double>[
      for (var i = 0; i < points.length; i++)
        veriGlassEdgeLight(
          Offset(points[i].dx / size.width, points[i].dy / size.height),
          normals[i],
          motion: motion,
        ),
    ];
    void drawRibbon(double halfWidth, double opacity) {
      const offsets = [-1.0, -0.5, 0.0, 0.5, 1.0];
      const weights = [0.0, 0.35, 1.0, 0.35, 0.0];
      final positions = <Offset>[];
      final colors = <Color>[];
      for (var i = 0; i < points.length; i++) {
        for (var j = 0; j < offsets.length; j++) {
          positions.add(points[i] + normals[i] * (offsets[j] * halfWidth));
          colors.add(
            Colors.white.withValues(
              alpha: (lights[i] * opacity * weights[j]).clamp(0, 1),
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
  bool shouldRepaint(VeriGlassLightPainter oldDelegate) =>
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

  /// 顶点网格的三角形索引，只与采样数有关。
  final List<int> indices;
}

/// 缓存条目上限：卡片尺寸种类有限，超限直接清空，避免无限增长。
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
  // 把整条轮廓组成连续的透明度网格，两次绘制完成柔光与细高光。
  // 不为每 2dp 小段建立 MaskFilter 离屏任务：一张普通卡片原本就会
  // 产生数百次独立模糊，多个卡片同时显示时会放大原生 GPU 资源压力。
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
