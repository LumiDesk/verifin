import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class TrendLinePainter extends CustomPainter {
  const TrendLinePainter({
    required this.color,
    required this.values,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    this.glow = false,
  });

  final Color color;
  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 34.0;
    const bottomInset = 22.0;
    final chartRect = Rect.fromLTWH(
      yLabels.isEmpty ? 0 : leftInset,
      0,
      size.width - (yLabels.isEmpty ? 0 : leftInset),
      size.height - (xLabels.isEmpty ? 0 : bottomInset),
    );
    final axisColor = labelColor ?? Colors.white.withValues(alpha: 0.45);
    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
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
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }
    for (var i = 0; i < 6; i += 1) {
      final x = chartRect.left + chartRect.width * i / 5;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint..color = axisColor.withValues(alpha: 0.06),
      );
    }

    final normalized = values.isEmpty ? <double>[0, 0, 0, 0] : values;
    final maxValue = math.max(normalized.reduce(math.max), 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < normalized.length; i += 1) {
      final x = normalized.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (normalized.length - 1);
      final y =
          chartRect.bottom -
          (normalized[i] / maxValue * chartRect.height * 0.86);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartRect.bottom);
        fillPath.lineTo(x, y);
      } else {
        final previousX =
            chartRect.left +
            chartRect.width * (i - 1) / (normalized.length - 1);
        final previousY =
            chartRect.bottom -
            (normalized[i - 1] / maxValue * chartRect.height * 0.86);
        final dx = (x - previousX) / 2;
        path.cubicTo(previousX + dx, previousY, x - dx, y, x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(chartRect.right, chartRect.bottom)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    if (glow) {
      canvas.drawPath(path, glowPaint);
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < normalized.length; i += 1) {
      if (normalized[i] <= 0) {
        continue;
      }
      final x = normalized.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (normalized.length - 1);
      final y =
          chartRect.bottom -
          (normalized[i] / maxValue * chartRect.height * 0.86);
      canvas.drawCircle(Offset(x, y), 2.2, pointPaint);
    }

    _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor);
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.values != values ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.glow != glow;
  }
}

class BarChartPainter extends CustomPainter {
  const BarChartPainter({
    required this.values,
    this.xLabels = const <String>[],
    this.labelColor,
  });

  final List<double> values;
  final List<String> xLabels;
  final Color? labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - (xLabels.isEmpty ? 0 : 22),
    );
    final axisColor = labelColor ?? Colors.white.withValues(alpha: 0.45);
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[veriRoyal, veriBlue],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    final maxValue = math.max(values.reduce(math.max), 1);
    final gap = chartRect.width / values.length;
    for (var i = 0; i < values.length; i += 1) {
      final barHeight = values[i] / maxValue * chartRect.height * 0.86;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          chartRect.left + i * gap + gap * 0.25,
          chartRect.bottom - barHeight,
          gap * 0.5,
          barHeight,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, barPaint);
    }
    _drawLabels(canvas, chartRect, xLabels, const <String>[], axisColor);
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.labelColor != labelColor;
  }
}

class BudgetRingPainter extends CustomPainter {
  const BudgetRingPainter({
    required this.value,
    required this.trackColor,
    required this.progressColor,
  });

  final double value;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.10;
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: <Color>[progressColor, veriRoyal, progressColor],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1).toDouble(),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BudgetRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

void _drawLabels(
  Canvas canvas,
  Rect chartRect,
  List<String> xLabels,
  List<String> yLabels,
  Color labelColor,
) {
  final textStyle = TextStyle(color: labelColor, fontSize: 10);
  for (var i = 0; i < xLabels.length; i += 1) {
    final x = xLabels.length == 1
        ? chartRect.left
        : chartRect.left + chartRect.width * i / (xLabels.length - 1);
    final painter = TextPainter(
      text: TextSpan(text: xLabels[i], style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, chartRect.bottom + 6));
  }

  for (var i = 0; i < yLabels.length; i += 1) {
    final y = yLabels.length == 1
        ? chartRect.bottom
        : chartRect.bottom - chartRect.height * i / (yLabels.length - 1);
    final painter = TextPainter(
      text: TextSpan(text: yLabels[i], style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(chartRect.left - painter.width - 6, y - painter.height / 2),
    );
  }
}
