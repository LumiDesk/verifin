import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'series_math.dart';

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

/// 曲线图绘图区（与预算趋势图共用的内边距约定）。
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

/// 柱状图绘图区（与预算趋势图共用的内边距约定）。
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
///
/// 绘制由 `fl_chart` 承担（原自绘画布已移除）；对外 API 保持不变，
/// 因此各页面调用点无需改动。触摸回调把 fl_chart 的响应换算回数据点下标，
/// 气泡文案仍由 [tooltipOf] 决定。
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
    if (!listEquals(oldWidget.values, widget.values) &&
        _selectedIndex != null &&
        _selectedIndex! >= widget.values.length) {
      _selectedIndex = null;
    }
  }

  void _handleTouch(FlTouchEvent event, LineTouchResponse? response) {
    final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
    if (index == null) {
      if (event is FlTapUpEvent && _selectedIndex != null) {
        setState(() => _selectedIndex = null);
      }
      return;
    }
    // 再次点按同一个点取消选中，与旧画布版一致。
    if (event is FlTapUpEvent && index == _selectedIndex) {
      setState(() => _selectedIndex = null);
      return;
    }
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final scheme = Theme.of(context).colorScheme;
    final labelColor =
        widget.labelColor ?? scheme.onSurface.withValues(alpha: 0.45);
    final semantics =
        widget.semanticsLabel ??
        AppLocalizations.of(context).chartTrendSemantics(values.length);

    if (values.isEmpty) {
      return Semantics(label: semantics, child: const SizedBox.expand());
    }

    // 与旧画布一致：零基线参与缩放，负值（负债）也能正确显示。
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final rawMin = math.min(0, minValue).toDouble();
    final rawMax = math.max(0, maxValue).toDouble();
    final span = (rawMax - rawMin).abs() < 1e-9 ? 1.0 : (rawMax - rawMin);
    final interval = span / 2;
    final yLabels = widget.yLabels.isNotEmpty
        ? widget.yLabels
        : reportAxisLabels(rawMax);

    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return Semantics(
      label: semantics,
      container: true,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: rawMin - span * 0.06,
          maxY: rawMax + span * 0.10,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: true,
            horizontalInterval: interval,
            verticalInterval: values.length > 1
                ? (values.length - 1) / 5
                : null,
            getDrawingHorizontalLine: (_) => FlLine(
              color: labelColor.withValues(alpha: 0.16),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: labelColor.withValues(alpha: 0.07),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  final index = ((value - rawMin) / interval).round();
                  if (index < 0 || index >= yLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      yLabels[index],
                      style: TextStyle(fontSize: 10, color: labelColor),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= widget.xLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      widget.xLabels[index],
                      style: TextStyle(fontSize: 10, color: labelColor),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchCallback: _handleTouch,
            getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(
                      color: widget.color.withValues(alpha: 0.38),
                      strokeWidth: 1,
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: widget.color,
                            strokeWidth: 2.3,
                            strokeColor: scheme.surface,
                          ),
                    ),
                  ),
                )
                .toList(),
            touchTooltipData: LineTouchTooltipData(
              tooltipBorder: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
              getTooltipColor: (_) => veriInk.withValues(alpha: 0.92),
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => tooltipItemOf(widget.tooltipOf(spot.spotIndex)),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.28,
              preventCurveOverShooting: true,
              color: widget.color,
              barWidth: 2.8,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.y > 0,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 2.2,
                      color: widget.color,
                      strokeWidth: 0,
                    ),
              ),
              shadow: widget.glow
                  ? Shadow(
                      color: widget.color.withValues(alpha: 0.20),
                      blurRadius: 5,
                    )
                  : const Shadow(),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    widget.color.withValues(alpha: 0.30),
                    widget.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
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
    if (!listEquals(oldWidget.values, widget.values) &&
        _selectedIndex != null &&
        _selectedIndex! >= widget.values.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final values = widget.values;
    final scheme = Theme.of(context).colorScheme;
    final labelColor =
        widget.labelColor ?? scheme.onSurface.withValues(alpha: 0.45);
    final semantics =
        widget.semanticsLabel ??
        AppLocalizations.of(context).chartBarSemantics(values.length);

    if (values.isEmpty) {
      return Semantics(label: semantics, child: const SizedBox.expand());
    }

    final maxValue = math.max(values.reduce(math.max), 1.0);
    final interval = maxValue / 2;
    final yLabels = widget.yLabels.isNotEmpty
        ? widget.yLabels
        : reportAxisLabels(maxValue);
    final gradientBottom = veriSemanticFor(brightness, veriBlue);

    return Semantics(
      label: semantics,
      container: true,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxValue * 1.14,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: labelColor.withValues(alpha: 0.16),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: labelColor.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  final index = (value / interval).round();
                  if (index < 0 || index >= yLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      yLabels[index],
                      style: TextStyle(fontSize: 10, color: labelColor),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= widget.xLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      widget.xLabels[index],
                      style: TextStyle(fontSize: 10, color: labelColor),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchCallback: (event, response) {
              final index = response?.spot?.touchedBarGroupIndex;
              if (index == null) {
                if (event is FlTapUpEvent && _selectedIndex != null) {
                  setState(() => _selectedIndex = null);
                }
                return;
              }
              if (event is FlTapUpEvent && index == _selectedIndex) {
                setState(() => _selectedIndex = null);
                return;
              }
              if (index != _selectedIndex) {
                setState(() => _selectedIndex = index);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipBorder: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
              getTooltipColor: (_) => veriInk.withValues(alpha: 0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  barTooltipItemOf(widget.tooltipOf(group.x)),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: values[i],
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        i == _selectedIndex
                            ? gradientBottom
                            : gradientBottom.withValues(alpha: 0.30),
                        i == _selectedIndex
                            ? veriRoyal
                            : veriRoyal.withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// 气泡正文：标题一行 + 各数值行，配色固定（深色底浅色字，任何背景都可读）。
List<TextSpan> _tooltipSpans(ChartTooltip tooltip) => <TextSpan>[
  TextSpan(
    text: '${tooltip.title}\n',
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.70),
    ),
  ),
  for (final line in tooltip.lines)
    TextSpan(
      text: '${line.text}\n',
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
];

TextStyle get _tooltipTextStyle => const TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w800,
  color: Colors.white,
);

String _tooltipHeadline(ChartTooltip tooltip) =>
    tooltip.lines.isEmpty ? tooltip.title : tooltip.lines.first.text;

/// 把站点自带的 [ChartTooltip] 转成折线图气泡内容，保持文案与配色不变。
LineTooltipItem tooltipItemOf(ChartTooltip tooltip) => LineTooltipItem(
  _tooltipHeadline(tooltip),
  _tooltipTextStyle,
  textAlign: TextAlign.left,
  children: _tooltipSpans(tooltip),
);

/// 柱状图版本的转换：fl_chart 对柱状与折线使用不同的气泡类型。
BarTooltipItem barTooltipItemOf(ChartTooltip tooltip) => BarTooltipItem(
  '',
  _tooltipTextStyle,
  textAlign: TextAlign.left,
  children: _tooltipSpans(tooltip),
);
