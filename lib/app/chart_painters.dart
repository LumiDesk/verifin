import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class TrendLinePainter extends CustomPainter {
  const TrendLinePainter({required this.color, required this.values});

  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    for (var i = 0; i < 4; i += 1) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final normalized = values.isEmpty ? <double>[0, 0, 0, 0] : values;
    final maxValue = math.max(normalized.reduce(math.max), 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < normalized.length; i += 1) {
      final x = normalized.length == 1
          ? 0.0
          : size.width * i / (normalized.length - 1);
      final y = size.height - (normalized[i] / maxValue * size.height * 0.86);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(size.width, size.height)
      ..close();
    canvas
      ..drawPath(fillPath, fillPaint)
      ..drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class BarChartPainter extends CustomPainter {
  const BarChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[veriRoyal, veriBlue],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    final maxValue = math.max(values.reduce(math.max), 1);
    final gap = size.width / values.length;
    for (var i = 0; i < values.length; i += 1) {
      final barHeight = values[i] / maxValue * size.height * 0.86;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * gap + gap * 0.25,
          size.height - barHeight,
          gap * 0.5,
          barHeight,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
