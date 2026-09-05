import 'dart:math' as math;

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
    this.activity = 0,
    this.motion = 0,
  });
  final double radius;
  final double activity;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 2) return;
    final rect = (Offset.zero & size).deflate(0.7);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metric = path.computeMetrics().first;
    const step = 2.0;
    for (var distance = 0.0; distance < metric.length; distance += step) {
      final tangent = metric.getTangentForOffset(distance + 0.1);
      if (tangent == null) continue;
      final light = veriGlassEdgeLight(
        Offset(
          tangent.position.dx / size.width,
          tangent.position.dy / size.height,
        ),
        Offset(tangent.vector.dy, -tangent.vector.dx),
        motion: motion,
      );
      if (light < 0.008) continue;
      final segment = metric.extractPath(
        distance,
        math.min(distance + step + 0.5, metric.length),
      );
      canvas.drawPath(
        segment,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 + activity * 1.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 + activity)
          ..color = Colors.white.withValues(
            alpha: (light * (0.17 + activity * 0.16)).clamp(0, 1),
          ),
      );
      canvas.drawPath(
        segment,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.85 + activity * 0.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(
            alpha: (light * (0.82 + activity * 0.18)).clamp(0, 1),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(VeriGlassLightPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      activity != oldDelegate.activity ||
      motion != oldDelegate.motion;
}
