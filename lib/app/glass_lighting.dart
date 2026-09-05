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
    this.brightness = Brightness.light,
    this.activity = 0,
    this.motion = 0,
  });
  final double radius;
  final Brightness brightness;
  double get peakOpacity => brightness == Brightness.dark ? 0.22 : 0.46;
  final double activity;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 2) return;
    final rect = (Offset.zero & size).deflate(0.7);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metric = path.computeMetrics().first;
    // 把整条轮廓组成连续的透明度网格，两次绘制完成柔光与细高光。
    // 不为每 2dp 小段建立 MaskFilter 离屏任务：一张普通卡片原本就会
    // 产生数百次独立模糊，多个卡片同时显示时会放大原生 GPU 资源压力。
    final samples = (metric.length / 2).ceil().clamp(12, 1024);
    final points = <Offset>[];
    final normals = <Offset>[];
    final lights = <double>[];
    for (var i = 0; i <= samples; i++) {
      final tangent = metric.getTangentForOffset(
        i == samples ? 0 : metric.length * i / samples,
      )!;
      final normal = Offset(tangent.vector.dy, -tangent.vector.dx);
      points.add(tangent.position);
      normals.add(normal);
      lights.add(
        veriGlassEdgeLight(
          Offset(
            tangent.position.dx / size.width,
            tangent.position.dy / size.height,
          ),
          normal,
          motion: motion,
        ),
      );
    }
    void drawRibbon(double halfWidth, double opacity) {
      const offsets = [-1.0, -0.5, 0.0, 0.5, 1.0];
      const weights = [0.0, 0.35, 1.0, 0.35, 0.0];
      final positions = <Offset>[];
      final colors = <Color>[];
      final indices = <int>[];
      for (var i = 0; i < points.length; i++) {
        for (var j = 0; j < offsets.length; j++) {
          positions.add(points[i] + normals[i] * (offsets[j] * halfWidth));
          colors.add(
            Colors.white.withValues(
              alpha: (lights[i] * opacity * weights[j]).clamp(0, 1),
            ),
          );
          if (i < samples && j < offsets.length - 1) {
            final a = i * offsets.length + j;
            final b = a + offsets.length;
            indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
          }
        }
      }
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      );
      canvas.drawVertices(vertices, BlendMode.dst, Paint());
      vertices.dispose();
    }

    drawRibbon(3.8 + activity * 1.6, peakOpacity * 0.20 + activity * 0.04);
    drawRibbon(0.85 + activity * 0.5, peakOpacity + activity * 0.10);
  }

  @override
  bool shouldRepaint(VeriGlassLightPainter oldDelegate) =>
      brightness != oldDelegate.brightness ||
      radius != oldDelegate.radius ||
      activity != oldDelegate.activity ||
      motion != oldDelegate.motion;
}
