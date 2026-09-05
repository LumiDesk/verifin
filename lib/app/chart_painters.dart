import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 数值只画到图表高度的这个比例,顶部留白;网格线和纵轴刻度按同一比例
/// 定位,保证刻度读数与曲线/柱高一致。
const double chartValueScale = 0.86;

/// 图表点击后展示的数据气泡内容。
class ChartTooltip {
  const ChartTooltip({required this.title, required this.lines});

  final String title;
  final List<ChartTooltipLine> lines;
}

class ChartTooltipLine {
  const ChartTooltipLine({required this.text, this.color});

  final String text;

  /// 多序列图表用于区分序列的小圆点颜色;单序列可省略。
  final Color? color;
}

/// 曲线图绘图区(与 [TrendLinePainter] 的内边距保持一致)。
Rect trendChartRect(
  Size size, {
  required bool hasXLabels,
  required bool hasYLabels,
}) {
  const leftInset = 30.0;
  const rightInset = 8.0;
  const bottomInset = 22.0;
  return Rect.fromLTWH(
    hasYLabels ? leftInset : 0,
    0,
    size.width - (hasYLabels ? leftInset + rightInset : rightInset),
    size.height - (hasXLabels ? bottomInset : 0),
  );
}

/// 柱状图绘图区(与 [BarChartPainter] 的内边距保持一致)。
Rect barChartRect(
  Size size, {
  required bool hasXLabels,
  required bool hasYLabels,
}) {
  const leftInset = 30.0;
  const rightInset = 4.0;
  return Rect.fromLTWH(
    hasYLabels ? leftInset : 0,
    0,
    size.width - (hasYLabels ? leftInset + rightInset : 0),
    size.height - (hasXLabels ? 22 : 0),
  );
}

/// 命中曲线图上离点击横坐标最近的数据点;点击落在图表区外返回 null。
int? chartNearestIndex(Offset position, Rect chartRect, int count) {
  if (count <= 0 || !chartRect.inflate(14).contains(position)) {
    return null;
  }
  if (count == 1) {
    return 0;
  }
  final ratio = ((position.dx - chartRect.left) / chartRect.width).clamp(
    0.0,
    1.0,
  );
  return (ratio * (count - 1)).round();
}

/// 命中柱状图(等宽槽位)的柱子下标;点击落在图表区外返回 null。
int? chartSlotIndex(Offset position, Rect chartRect, int count) {
  if (count <= 0 || !chartRect.inflate(10).contains(position)) {
    return null;
  }
  final gap = chartRect.width / count;
  return ((position.dx - chartRect.left) / gap).floor().clamp(0, count - 1);
}

/// 在 [anchor] 附近绘制数据气泡,自动上下翻转并夹紧在画布内。
/// 气泡固定使用深色底和浅色文字,保证在浅色、深色和图片背景上都可读。
void drawChartTooltip(
  Canvas canvas,
  Size size,
  Offset anchor,
  ChartTooltip tooltip,
) {
  const padding = 8.0;
  const dotSize = 6.0;
  final titlePainter = TextPainter(
    text: TextSpan(
      text: tooltip.title,
      style: const TextStyle(
        color: Color(0xB3FFFFFF),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final linePainters = <(ChartTooltipLine, TextPainter)>[
    for (final line in tooltip.lines)
      (
        line,
        TextPainter(
          text: TextSpan(
            text: line.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      ),
  ];

  var contentWidth = titlePainter.width;
  var contentHeight = titlePainter.height;
  for (final (line, painter) in linePainters) {
    final lineWidth = painter.width + (line.color == null ? 0 : dotSize + 5);
    contentWidth = math.max(contentWidth, lineWidth);
    contentHeight += painter.height + 3;
  }
  final bubbleWidth = contentWidth + padding * 2;
  final bubbleHeight = contentHeight + padding * 2;

  var left = anchor.dx - bubbleWidth / 2;
  left = left.clamp(2.0, math.max(2.0, size.width - bubbleWidth - 2));
  var top = anchor.dy - bubbleHeight - 10;
  if (top < 2) {
    top = math.min(anchor.dy + 12, size.height - bubbleHeight - 2);
  }

  final bubble = RRect.fromRectAndRadius(
    Rect.fromLTWH(left, top, bubbleWidth, bubbleHeight),
    const Radius.circular(7),
  );
  canvas.drawRRect(bubble, Paint()..color = const Color(0xEB1C2430));
  canvas.drawRRect(
    bubble,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  var dy = top + padding;
  titlePainter.paint(canvas, Offset(left + padding, dy));
  dy += titlePainter.height + 3;
  for (final (line, painter) in linePainters) {
    var dx = left + padding;
    if (line.color != null) {
      canvas.drawCircle(
        Offset(dx + dotSize / 2, dy + painter.height / 2),
        dotSize / 2,
        Paint()..color = line.color!,
      );
      dx += dotSize + 5;
    }
    painter.paint(canvas, Offset(dx, dy));
    dy += painter.height + 3;
  }
}

class TrendLinePainter extends CustomPainter {
  const TrendLinePainter({
    required this.color,
    required this.values,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    this.glow = false,
    this.selectedIndex,
    this.tooltip,
  });

  final Color color;
  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final bool glow;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = trendChartRect(
      size,
      hasXLabels: xLabels.isNotEmpty,
      hasYLabels: yLabels.isNotEmpty,
    );
    // 兜底用中性灰（在深浅背景上都可辨），避免调用方漏传 labelColor 时浅色下白轴看不见。
    final axisColor = labelColor ?? Colors.grey.withValues(alpha: 0.45);
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
      final y = chartRect.bottom - chartRect.height * chartValueScale * i / 3;
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
    // 序列可能包含负值(如负债账户余额),按 [min, max] 区间归一化;
    // 全为非负时与按最大值归一化完全一致。
    final maxValue = math.max(normalized.reduce(math.max), 0.0);
    final minValue = math.min(normalized.reduce(math.min), 0.0);
    final range = math.max(maxValue - minValue, 1.0);
    double yFor(double value) =>
        chartRect.bottom -
        ((value - minValue) / range * chartRect.height * chartValueScale);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < normalized.length; i += 1) {
      final x = normalized.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (normalized.length - 1);
      final y = yFor(normalized[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartRect.bottom);
        fillPath.lineTo(x, y);
      } else {
        final previousX =
            chartRect.left +
            chartRect.width * (i - 1) / (normalized.length - 1);
        final previousY = yFor(normalized[i - 1]);
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
      if (minValue >= 0 && normalized[i] <= 0) {
        continue;
      }
      final x = normalized.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (normalized.length - 1);
      canvas.drawCircle(Offset(x, yFor(normalized[i])), 2.2, pointPaint);
    }

    _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor);

    final selected = selectedIndex;
    if (values.isNotEmpty &&
        selected != null &&
        selected >= 0 &&
        selected < normalized.length) {
      final x = normalized.length == 1
          ? chartRect.left
          : chartRect.left +
                chartRect.width * selected / (normalized.length - 1);
      final y = yFor(normalized[selected]);
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.38)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      canvas.drawCircle(Offset(x, y), 2.3, Paint()..color = Colors.white);
      if (tooltip != null) {
        drawChartTooltip(canvas, size, Offset(x, y), tooltip!);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) {
    // values/xLabels/yLabels 由调用方每帧新建，用 listEquals 做按元素比较，
    // 避免内容不变时因列表实例不同而误判为「变了」触发无谓重绘。
    return oldDelegate.color != color ||
        !listEquals(oldDelegate.values, values) ||
        !listEquals(oldDelegate.xLabels, xLabels) ||
        !listEquals(oldDelegate.yLabels, yLabels) ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.glow != glow ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.tooltip != tooltip;
  }
}

class BarChartPainter extends CustomPainter {
  const BarChartPainter({
    required this.values,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    this.selectedIndex,
    this.tooltip,
  });

  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = barChartRect(
      size,
      hasXLabels: xLabels.isNotEmpty,
      hasYLabels: yLabels.isNotEmpty,
    );
    // 兜底用中性灰（在深浅背景上都可辨），避免调用方漏传 labelColor 时浅色下白轴看不见。
    final axisColor = labelColor ?? Colors.grey.withValues(alpha: 0.45);
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[veriRoyal, veriBlue],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    // 有选中柱子时,其余柱子弱化,突出当前数据。
    final dimmedBarPaint = Paint()..color = veriBlue.withValues(alpha: 0.30);

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    for (var i = 1; i < 4; i += 1) {
      final y = chartRect.bottom - chartRect.height * chartValueScale * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint..color = axisColor.withValues(alpha: 0.10),
      );
    }

    // 空数据只画坐标轴与标签、不画柱子（reduce/除以 length 对空列表会抛异常），
    // 与折线图对空数据的处理对齐。
    if (values.isEmpty) {
      _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor);
      return;
    }

    final maxValue = math.max(values.reduce(math.max), 1);
    final gap = chartRect.width / values.length;
    for (var i = 0; i < values.length; i += 1) {
      final barHeight =
          values[i] / maxValue * chartRect.height * chartValueScale;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          chartRect.left + i * gap + gap * 0.25,
          chartRect.bottom - barHeight,
          gap * 0.5,
          barHeight,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rect,
        selectedIndex == null || selectedIndex == i ? barPaint : dimmedBarPaint,
      );
    }
    _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor);

    final selected = selectedIndex;
    if (selected != null &&
        selected >= 0 &&
        selected < values.length &&
        tooltip != null) {
      final barHeight =
          values[selected] / maxValue * chartRect.height * chartValueScale;
      final anchor = Offset(
        chartRect.left + selected * gap + gap / 2,
        chartRect.bottom - barHeight,
      );
      drawChartTooltip(canvas, size, anchor, tooltip!);
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    // 同 TrendLinePainter：列表按元素比较，内容不变则不重绘。
    return !listEquals(oldDelegate.values, values) ||
        !listEquals(oldDelegate.xLabels, xLabels) ||
        !listEquals(oldDelegate.yLabels, yLabels) ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.tooltip != tooltip;
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
    // 用 GradientRotation 把渐变整体绕圆心转到「12 点起始」，而不是用 startAngle
    // 偏移色标：SweepGradient 的角度环绕断点（首尾相接处）恒在 +x 轴（3 点方向），
    // 仅靠 startAngle 挪动色标并不会挪动这个断点，于是断点两侧插值出的颜色不同，
    // 在右侧形成明显的黄/蓝分界线。GradientRotation 会连同断点一起旋转，使首尾相接
    // 处落在 12 点——那里首尾都是 progressColor，接缝因此不可见。
    final progressPaint = Paint()
      ..shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
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

/// 可交互曲线图:点击或横向滑动选中数据点,弹出数据气泡;
/// 再次点击同一点或点击图表区外取消。图表区域会拦截点击,
/// 不会触发外层卡片的跳转。
class InteractiveTrendChart extends StatefulWidget {
  const InteractiveTrendChart({
    super.key,
    required this.color,
    required this.values,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    this.glow = false,
    required this.tooltipOf,
  });

  final Color color;
  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final bool glow;

  /// 为选中的数据点构建气泡内容。
  final ChartTooltip Function(int index) tooltipOf;

  @override
  State<InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<InteractiveTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant InteractiveTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        Rect chartRect() => trendChartRect(
          size,
          hasXLabels: widget.xLabels.isNotEmpty,
          hasYLabels: widget.yLabels.isNotEmpty,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final index = chartNearestIndex(
              details.localPosition,
              chartRect(),
              widget.values.length,
            );
            setState(() {
              _selectedIndex = index == _selectedIndex ? null : index;
            });
          },
          onHorizontalDragUpdate: (details) {
            final index = chartNearestIndex(
              details.localPosition,
              chartRect(),
              widget.values.length,
            );
            if (index != null && index != _selectedIndex) {
              setState(() => _selectedIndex = index);
            }
          },
          child: CustomPaint(
            painter: TrendLinePainter(
              color: widget.color,
              values: widget.values,
              xLabels: widget.xLabels,
              yLabels: widget.yLabels,
              labelColor: widget.labelColor,
              glow: widget.glow,
              selectedIndex: _selectedIndex,
              tooltip: _selectedIndex == null
                  ? null
                  : widget.tooltipOf(_selectedIndex!),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// 可交互柱状图:点击或横向滑动选中柱子,弹出数据气泡。
class InteractiveBarChart extends StatefulWidget {
  const InteractiveBarChart({
    super.key,
    required this.values,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    required this.tooltipOf,
  });

  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final ChartTooltip Function(int index) tooltipOf;

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant InteractiveBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        Rect chartRect() => barChartRect(
          size,
          hasXLabels: widget.xLabels.isNotEmpty,
          hasYLabels: widget.yLabels.isNotEmpty,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final index = chartSlotIndex(
              details.localPosition,
              chartRect(),
              widget.values.length,
            );
            setState(() {
              _selectedIndex = index == _selectedIndex ? null : index;
            });
          },
          onHorizontalDragUpdate: (details) {
            final index = chartSlotIndex(
              details.localPosition,
              chartRect(),
              widget.values.length,
            );
            if (index != null && index != _selectedIndex) {
              setState(() => _selectedIndex = index);
            }
          },
          child: CustomPaint(
            painter: BarChartPainter(
              values: widget.values,
              xLabels: widget.xLabels,
              yLabels: widget.yLabels,
              labelColor: widget.labelColor,
              selectedIndex: _selectedIndex,
              tooltip: _selectedIndex == null
                  ? null
                  : widget.tooltipOf(_selectedIndex!),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
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
        : chartRect.bottom -
              chartRect.height * chartValueScale * i / (yLabels.length - 1);
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
