import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
  double yLabelWidth = 30,
}) {
  const rightInset = 8.0;
  const bottomInset = 22.0;
  return Rect.fromLTWH(
    hasYLabels ? yLabelWidth : 0,
    0,
    size.width - (hasYLabels ? yLabelWidth + rightInset : rightInset),
    size.height - (hasXLabels ? bottomInset : 0),
  );
}

/// 柱状图绘图区(与 [BarChartPainter] 的内边距保持一致)。
Rect barChartRect(
  Size size, {
  required bool hasXLabels,
  required bool hasYLabels,
  double yLabelWidth = 30,
}) {
  const rightInset = 4.0;
  return Rect.fromLTWH(
    hasYLabels ? yLabelWidth : 0,
    0,
    size.width - (hasYLabels ? yLabelWidth + rightInset : 0),
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
/// [textScaler] 是系统字号缩放:画布文字不经过 Theme,必须由调用方显式传入。
void drawChartTooltip(
  Canvas canvas,
  Size size,
  Offset anchor,
  ChartTooltip tooltip, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  const padding = 8.0;
  const dotSize = 6.0;
  final titlePainter = TextPainter(
    text: TextSpan(
      text: tooltip.title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.70),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
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
          textScaler: textScaler,
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

  // 气泡整体夹紧在画布矩形内:先按锚点摆位,再分别夹紧左右与上下。
  // 上方的夹紧必须取 max(边界),否则气泡高于画布时 top 会变成负值、画出画布。
  final canvasRect = Offset.zero & size;
  const edge = 2.0;
  var left = anchor.dx - bubbleWidth / 2;
  left = left.clamp(
    canvasRect.left + edge,
    math.max(canvasRect.left + edge, canvasRect.right - bubbleWidth - edge),
  );
  var top = anchor.dy - bubbleHeight - 10;
  if (top < canvasRect.top + edge) {
    top = anchor.dy + 12;
  }
  top = top.clamp(
    canvasRect.top + edge,
    math.max(canvasRect.top + edge, canvasRect.bottom - bubbleHeight - edge),
  );

  final bubble = RRect.fromRectAndRadius(
    Rect.fromLTWH(left, top, bubbleWidth, bubbleHeight),
    const Radius.circular(7),
  );
  // 固定深色底:浅色、深色与图片背景上都要可读,不随主题切换。
  canvas.drawRRect(bubble, Paint()..color = veriInk.withValues(alpha: 0.92));
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
    this.textScaler = TextScaler.noScaling,
  });

  final Color color;
  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final bool glow;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  /// 画布文字不经过 Theme 的 textTheme,系统字号缩放必须显式传入。
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = trendChartRect(
      size,
      hasXLabels: xLabels.isNotEmpty,
      hasYLabels: yLabels.isNotEmpty,
      yLabelWidth: chartYAxisLabelWidth(yLabels, textScaler),
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

    // 空数据不画曲线,也不再用 [0,0,0,0] 补一条假的平线:调用方在无数据时渲染 EmptyState。
    if (values.isEmpty) {
      _drawGrid(canvas, chartRect, yLabels.length, gridPaint, axisColor);
      _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor, textScaler);
      return;
    }

    // 序列可能包含负值(如负债账户余额),按 [min, max] 区间归一化;
    // 全为非负时与按最大值归一化完全一致。
    final maxValue = math.max(values.reduce(math.max), 0.0);
    final minValue = math.min(values.reduce(math.min), 0.0);
    final range = math.max(maxValue - minValue, 1.0);
    double yFor(double value) =>
        chartRect.bottom -
        ((value - minValue) / range * chartRect.height * chartValueScale);
    // 网格线与纵轴刻度共用同一组高度分数(见 _drawLabels):分数 0 与 1 就是本序列的
    // min 与 max,中间的刻度按同一区间线性取值,读数因此始终落在对应网格线上。
    _drawGrid(canvas, chartRect, yLabels.length, gridPaint, axisColor);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i += 1) {
      final x = values.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (values.length - 1);
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartRect.bottom);
        fillPath.lineTo(x, y);
      } else {
        final previousX =
            chartRect.left + chartRect.width * (i - 1) / (values.length - 1);
        final previousY = yFor(values[i - 1]);
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
    for (var i = 0; i < values.length; i += 1) {
      if (minValue >= 0 && values[i] <= 0) {
        continue;
      }
      final x = values.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * i / (values.length - 1);
      canvas.drawCircle(Offset(x, yFor(values[i])), 2.2, pointPaint);
    }

    _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor, textScaler);

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < values.length) {
      final x = values.length == 1
          ? chartRect.left
          : chartRect.left + chartRect.width * selected / (values.length - 1);
      final y = yFor(values[selected]);
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
        drawChartTooltip(
          canvas,
          size,
          Offset(x, y),
          tooltip!,
          textScaler: textScaler,
        );
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
        oldDelegate.tooltip != tooltip ||
        oldDelegate.textScaler != textScaler;
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
    this.textScaler = TextScaler.noScaling,
    required this.brightness,
  });

  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  /// 画布文字不经过 Theme 的 textTheme,系统字号缩放必须显式传入。
  final TextScaler textScaler;

  /// 画布不经过 Theme,语义色需按当前明暗取实际值,必须由调用方显式传入。
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = barChartRect(
      size,
      hasXLabels: xLabels.isNotEmpty,
      hasYLabels: yLabels.isNotEmpty,
      yLabelWidth: chartYAxisLabelWidth(yLabels, textScaler),
    );
    // 兜底用中性灰（在深浅背景上都可辨），避免调用方漏传 labelColor 时浅色下白轴看不见。
    final axisColor = labelColor ?? Colors.grey.withValues(alpha: 0.45);
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[veriRoyal, veriSemanticFor(brightness, veriBlue)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    // 有选中柱子时,其余柱子弱化,突出当前数据。
    final dimmedBarPaint = Paint()
      ..color = veriSemanticFor(brightness, veriBlue).withValues(alpha: 0.30);

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    // 网格线与纵轴刻度共用同一组高度分数(见 _drawLabels),刻度读数落在对应网格线上;
    // 底边已有轴线,故从 i=1 起画。
    final gridCount = yLabels.length >= 2 ? yLabels.length : 4;
    for (var i = 1; i < gridCount; i += 1) {
      final y = _yAtFraction(chartRect, _axisFraction(i, gridCount));
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint..color = axisColor.withValues(alpha: 0.10),
      );
    }

    // 空数据只画坐标轴与标签、不画柱子（reduce/除以 length 对空列表会抛异常），
    // 与折线图对空数据的处理对齐。
    if (values.isEmpty) {
      _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor, textScaler);
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
    _drawLabels(canvas, chartRect, xLabels, yLabels, axisColor, textScaler);

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
      drawChartTooltip(canvas, size, anchor, tooltip!, textScaler: textScaler);
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
        oldDelegate.tooltip != tooltip ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.brightness != brightness;
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
    this.semanticsLabel,
  });

  final Color color;
  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final bool glow;

  /// 为选中的数据点构建气泡内容。
  final ChartTooltip Function(int index) tooltipOf;

  /// 整图的无障碍摘要；缺省时按数据点数量生成通用说明。
  final String? semanticsLabel;

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
    // 画布文字不经过 Theme,系统字号缩放必须显式读取 MediaQuery。
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        Rect chartRect() => trendChartRect(
          size,
          hasXLabels: widget.xLabels.isNotEmpty,
          hasYLabels: widget.yLabels.isNotEmpty,
          yLabelWidth: chartYAxisLabelWidth(widget.yLabels, textScaler),
        );
        final tooltip = _selectedIndex == null
            ? null
            : widget.tooltipOf(_selectedIndex!);
        final chart = GestureDetector(
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
              tooltip: tooltip,
              textScaler: textScaler,
            ),
            child: const SizedBox.expand(),
          ),
        );
        // 无障碍摘要：选中数据点时用气泡里已本地化的文字，否则给出整图概览。
        final label = tooltip == null
            ? widget.semanticsLabel ??
                  AppLocalizations.of(
                    context,
                  ).chartTrendSemantics(widget.values.length)
            : _tooltipSemanticsLabel(tooltip);
        return Semantics(container: true, label: label, child: chart);
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
    this.semanticsLabel,
  });

  final List<double> values;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;
  final ChartTooltip Function(int index) tooltipOf;

  /// 整图的无障碍摘要；缺省时按数据项数量生成通用说明。
  final String? semanticsLabel;

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
    // 画布文字不经过 Theme,系统字号缩放必须显式读取 MediaQuery。
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        Rect chartRect() => barChartRect(
          size,
          hasXLabels: widget.xLabels.isNotEmpty,
          hasYLabels: widget.yLabels.isNotEmpty,
          yLabelWidth: chartYAxisLabelWidth(widget.yLabels, textScaler),
        );
        final tooltip = _selectedIndex == null
            ? null
            : widget.tooltipOf(_selectedIndex!);
        final chart = GestureDetector(
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
              tooltip: tooltip,
              textScaler: textScaler,
              brightness: Theme.of(context).brightness,
            ),
            child: const SizedBox.expand(),
          ),
        );
        // 无障碍摘要：选中柱子时用气泡里已本地化的文字，否则给出整图概览。
        final label = tooltip == null
            ? widget.semanticsLabel ??
                  AppLocalizations.of(
                    context,
                  ).chartBarSemantics(widget.values.length)
            : _tooltipSemanticsLabel(tooltip);
        return Semantics(container: true, label: label, child: chart);
      },
    );
  }
}

/// 纵轴网格线与刻度共用的高度分数:第 [index] 条位于 index/(count-1);
/// 只有一条(或没有刻度)时贴在底边。
double _axisFraction(int index, int count) =>
    count <= 1 ? 0.0 : index / (count - 1);

/// 按高度分数求纵坐标,分数 1 是数值区顶部。
double _yAtFraction(Rect chartRect, double fraction) =>
    chartRect.bottom - chartRect.height * chartValueScale * fraction;

/// 水平网格线与竖向参考网格:水平线数量与纵轴刻度一致,
/// 保证刻度读数落在对应的网格线上。
void _drawGrid(
  Canvas canvas,
  Rect chartRect,
  int labelCount,
  Paint gridPaint,
  Color axisColor,
) {
  final horizontalCount = labelCount >= 2 ? labelCount : 4;
  for (var i = 0; i < horizontalCount; i += 1) {
    final y = _yAtFraction(chartRect, _axisFraction(i, horizontalCount));
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
}

/// 选中数据点的无障碍摘要:直接复用气泡里已本地化的标题与数值文本。
String _tooltipSemanticsLabel(ChartTooltip tooltip) => <String>[
  tooltip.title,
  ...tooltip.lines.map((line) => line.text),
].join(', ');

/// 根据纵轴实际标签宽度预留左侧空间，短标签保持紧凑，长金额才扩大绘图区边距。
double chartYAxisLabelWidth(List<String> labels, TextScaler textScaler) {
  if (labels.isEmpty) {
    return 0;
  }
  final style = const TextStyle(fontSize: 10);
  var maxWidth = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    maxWidth = math.max(maxWidth, painter.width);
  }
  return math.max(30, maxWidth + 6);
}

void _drawLabels(
  Canvas canvas,
  Rect chartRect,
  List<String> xLabels,
  List<String> yLabels,
  Color labelColor,
  TextScaler textScaler,
) {
  final textStyle = TextStyle(color: labelColor, fontSize: 10);
  for (var i = 0; i < xLabels.length; i += 1) {
    final x =
        chartRect.left + chartRect.width * _axisFraction(i, xLabels.length);
    final painter = TextPainter(
      text: TextSpan(text: xLabels[i], style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, chartRect.bottom + 6));
  }

  for (var i = 0; i < yLabels.length; i += 1) {
    final y = _yAtFraction(chartRect, _axisFraction(i, yLabels.length));
    final painter = TextPainter(
      text: TextSpan(text: yLabels[i], style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    painter.paint(
      canvas,
      Offset(chartRect.left - painter.width - 6, y - painter.height / 2),
    );
  }
}
