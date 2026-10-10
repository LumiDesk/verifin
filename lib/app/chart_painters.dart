import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 图表气泡内容模型。适配层负责把外部图表库的触摸回调映射到这里。
class ChartTooltip {
  const ChartTooltip({required this.title, required this.lines});

  final String title;
  final List<ChartTooltipLine> lines;
}

class ChartTooltipLine {
  const ChartTooltipLine({required this.text, this.color});

  final String text;
  final Color? color;
}

/// 图表气泡统一深色底、浅色文字；这是设计规范明确要求的图表气泡样式。
const Color _chartTooltipBackground = Color(0xF21F2937);
const Color _chartTooltipText = Colors.white;

/// 组合图气泡的最大宽度；宽度本身按内容自适应，这里只作为上限与越界保护的基准。
const double _comboTooltipMaxWidth = 190;
const double _comboTooltipPadding = 10;

/// 组合图气泡文案样式；宽度预测量与渲染必须共用同一份样式。
const TextStyle _comboTooltipTitleStyle = TextStyle(
  color: _chartTooltipText,
  fontWeight: FontWeight.w800,
  fontSize: 12,
);
const TextStyle _comboTooltipLineStyle = TextStyle(
  // 与历史气泡一致的 86% 白；仅未指定系列色的行使用。
  color: Color(0xDBFFFFFF),
  fontWeight: FontWeight.w600,
  fontSize: 11,
);

/// 按数据计算 y 轴范围；全部相等时给一个安全的上下浮动，避免除零。
({double min, double max}) _yRange(List<double> values) {
  if (values.isEmpty) {
    return (min: 0, max: 1);
  }
  final rawMin = values.reduce(math.min);
  final rawMax = values.reduce(math.max);
  var minY = math.min(0.0, rawMin);
  var maxY = math.max(0.0, rawMax);
  if (minY == maxY) {
    maxY = 1;
  } else {
    final pad = (maxY - minY) * 0.08;
    maxY += pad;
    if (minY < 0) {
      minY -= pad;
    }
  }
  return (min: minY, max: maxY);
}

/// 网格线恒关闭：横向参考线由适配层自己绘制（见 [_ChartGridLines]）。
/// fl_chart 的刻度迭代会排除最小/最大值并按 baseline 取整，画出的线与
/// 纵轴标签并不在同一高度，所以由适配层统一控制两者。
const FlGridData _noGridData = FlGridData(show: false);

/// 纵轴标签行高与底部横轴标题占位；标签层、参考线层必须共用这两个常量。
const double _axisLabelHeight = 14;
const double _chartBottomTitlesSize = 22;

/// 第 i 个纵轴刻度（i = 0 为最小值）在图表控件内的顶部偏移。
/// 上下各留半个标签高度，避免文字被裁切。
List<double> _axisLabelTops(double height, int count) {
  final available = math.max(
    0.0,
    height - _axisLabelHeight - _chartBottomTitlesSize,
  );
  if (count <= 1) {
    return <double>[available / 2];
  }
  return <double>[
    for (var i = 0; i < count; i++) available * (count - 1 - i) / (count - 1),
  ];
}

/// 按实际纵轴文字宽度自适应预留：标签右对齐于预留区，预留宽度=文字宽度+间距，
/// 因此最宽的标签左缘正好落在卡片内容左缘。
double _axisReservedSize(BuildContext context, List<String> yLabels) {
  if (yLabels.isEmpty) {
    return 0;
  }
  final style =
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ) ??
      const TextStyle(fontWeight: FontWeight.w600, fontSize: 10);
  final textScaler = MediaQuery.textScalerOf(context);
  var maxWidth = 0.0;
  for (final label in yLabels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    maxWidth = math.max(maxWidth, painter.width);
  }
  return (maxWidth + 8).clamp(24.0, 120.0).toDouble();
}

FlTitlesData _titlesData({
  required BuildContext context,
  required List<String> xLabels,
  int? xValueCount,
  Color? labelColor,
  bool renderTitles = true,
}) {
  final muted =
      labelColor ??
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
  final style = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: muted,
    fontWeight: FontWeight.w600,
    fontSize: 10,
  );
  final resolvedXValueCount = xValueCount ?? xLabels.length;
  final xLabelPositions = <int, int>{};
  if (xLabels.isNotEmpty && resolvedXValueCount > 0) {
    for (var i = 0; i < xLabels.length; i++) {
      final position = xLabels.length == 1 || resolvedXValueCount == 1
          ? 0
          : ((i * (resolvedXValueCount - 1)) / (xLabels.length - 1)).round();
      xLabelPositions[position] = i;
    }
  }

  Widget title(String text) {
    if (!renderTitles || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  return FlTitlesData(
    show: true,
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    // 纵轴文字由外层 _YAxisLabels 统一绘制，避免 fl_chart 自动刻度重复/闪烁。
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: xLabels.isNotEmpty,
        reservedSize: 22,
        interval: 1,
        minIncluded: true,
        maxIncluded: true,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          final labelIndex = xLabelPositions[index];
          if (index < 0 || labelIndex == null) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(meta: meta, child: title(xLabels[labelIndex]));
        },
      ),
    ),
  );
}

LineTooltipItem _lineTooltipItem(ChartTooltip tooltip) {
  final children = <TextSpan>[
    TextSpan(
      text: tooltip.title,
      style: const TextStyle(
        color: _chartTooltipText,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
    for (final line in tooltip.lines)
      TextSpan(
        text: '\n${line.text}',
        style: TextStyle(
          color: line.color ?? _chartTooltipText.withValues(alpha: 0.86),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
  ];
  return LineTooltipItem(
    '',
    const TextStyle(color: _chartTooltipText, fontSize: 12),
    children: children,
  );
}

BarTooltipItem _barTooltipItem(ChartTooltip tooltip) {
  return BarTooltipItem(
    '',
    const TextStyle(
      color: _chartTooltipText,
      fontWeight: FontWeight.w800,
      fontSize: 12,
    ),
    children: <TextSpan>[
      TextSpan(
        text: tooltip.title,
        style: const TextStyle(
          color: _chartTooltipText,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      for (final line in tooltip.lines)
        TextSpan(
          text: '\n${line.text}',
          style: TextStyle(
            color: line.color ?? _chartTooltipText.withValues(alpha: 0.86),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
    ],
  );
}

LineTouchTooltipData _lineTooltipData(
  ChartTooltip Function(int index) tooltipOf,
) {
  return LineTouchTooltipData(
    tooltipBorderRadius: BorderRadius.circular(10),
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    tooltipMargin: 10,
    maxContentWidth: 220,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipColor: (spot) => _chartTooltipBackground,
    getTooltipItems: (spots) => <LineTooltipItem?>[
      for (final spot in spots)
        spot.spotIndex >= 0
            ? _lineTooltipItem(tooltipOf(spot.spotIndex))
            : null,
    ],
  );
}

BarTouchTooltipData _barTooltipData(
  ChartTooltip Function(int index) tooltipOf,
) {
  return BarTouchTooltipData(
    tooltipBorderRadius: BorderRadius.circular(10),
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    tooltipMargin: 10,
    maxContentWidth: 220,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipColor: (group) => _chartTooltipBackground,
    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
        _barTooltipItem(tooltipOf(group.x)),
  );
}

/// 触摸指示：虚线竖线 + 小圆点。默认实现是半径 5dp 的大圆点，
/// 在只展示曲线的图表里过重，这里统一收敛成「高亮」而不是「节点」。
List<TouchedSpotIndicatorData> _touchedIndicators(
  BuildContext context,
  Color color,
  List<int> spotIndexes,
) {
  final surface = Theme.of(context).colorScheme.surface;
  return <TouchedSpotIndicatorData>[
    for (final _ in spotIndexes)
      TouchedSpotIndicatorData(
        FlLine(
          color: color.withValues(alpha: 0.32),
          strokeWidth: 1,
          dashArray: const <int>[4, 4],
        ),
        FlDotData(
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3.2,
            color: surface,
            strokeWidth: 2,
            strokeColor: color,
          ),
        ),
      ),
  ];
}

/// 纵轴标签层：由适配层按数据区间精确绘制，避免 fl_chart 自动刻度重复/闪烁。
class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({required this.labels, required this.color});

  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 10,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = labels.length;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        final tops = _axisLabelTops(constraints.maxHeight, count);
        return Stack(
          children: <Widget>[
            for (var i = 0; i < count; i++)
              Positioned(
                left: 0,
                right: 0,
                top: tops[i],
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 横向参考线层：只画中间刻度，位置与 [_YAxisLabels] 完全同源，
/// 因此标签与参考线严格对齐；最小/最大值刻度不重复画线。
class _ChartGridLines extends StatelessWidget {
  const _ChartGridLines({required this.labelCount, required this.color});

  final int labelCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (labelCount < 3) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tops = _axisLabelTops(constraints.maxHeight, labelCount);
        return Stack(
          children: <Widget>[
            for (var i = 1; i < labelCount - 1; i++)
              Positioned(
                left: 0,
                right: 0,
                top: tops[i] + _axisLabelHeight / 2 - 0.5,
                child: SizedBox(height: 1, child: ColoredBox(color: color)),
              ),
          ],
        );
      },
    );
  }
}

/// 可交互折线图：内部由 `fl_chart` 渲染，点击/拖动查看数据气泡。
class InteractiveTrendChart extends StatelessWidget {
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
  final ChartTooltip Function(int index) tooltipOf;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final range = _yRange(values);
    final muted =
        labelColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, values.length - 1).toDouble(),
        minY: range.min,
        maxY: range.max,
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            color: color,
            barWidth: 2.2,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: <Color>[
                  color.withValues(alpha: 0.24),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            shadow: glow
                ? Shadow(color: color.withValues(alpha: 0.35), blurRadius: 8)
                : const Shadow(color: Colors.transparent),
          ),
        ],
        titlesData: _titlesData(
          context: context,
          xLabels: xLabels,
          xValueCount: values.length,
          labelColor: muted,
        ),
        gridData: _noGridData,
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: _lineTooltipData(tooltipOf),
          getTouchedSpotIndicator: (barData, spotIndexes) =>
              _touchedIndicators(context, color, spotIndexes),
        ),
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    final reserved = _axisReservedSize(context, yLabels);
    return Semantics(
      container: true,
      label:
          semanticsLabel ??
          AppLocalizations.of(context).chartTrendSemantics(values.length),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: <Widget>[
            Positioned(
              left: reserved,
              top: 0,
              right: 0,
              bottom: 0,
              child: _ChartGridLines(
                // 有纵轴刻度时逐刻度画线；没有刻度（如净资产卡）时保留一条
                // 中线，维持原有的阅读参考。
                labelCount: yLabels.isEmpty ? 3 : yLabels.length,
                color: muted.withValues(alpha: 0.16),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: reserved),
              child: chart,
            ),
            if (reserved > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reserved,
                child: _YAxisLabels(labels: yLabels, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// 可交互柱状图：内部由 `fl_chart` 渲染，点击/拖动查看数据气泡。
class InteractiveBarChart extends StatelessWidget {
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
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final range = _yRange(values);
    final muted =
        labelColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
    final barWidth = (240 / math.max(values.length, 1))
        .clamp(5.0, 18.0)
        .toDouble();
    final chart = BarChart(
      BarChartData(
        minY: math.min(0.0, range.min),
        maxY: range.max,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 4,
        barGroups: <BarChartGroupData>[
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: values[i],
                  color: Theme.of(context).colorScheme.primary,
                  width: barWidth,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: _titlesData(
          context: context,
          xLabels: xLabels,
          xValueCount: values.length,
          labelColor: muted,
        ),
        gridData: _noGridData,
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: _barTooltipData(tooltipOf),
        ),
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    final reserved = _axisReservedSize(context, yLabels);
    return Semantics(
      container: true,
      label:
          semanticsLabel ??
          AppLocalizations.of(context).chartBarSemantics(values.length),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: <Widget>[
            Positioned(
              left: reserved,
              top: 0,
              right: 0,
              bottom: 0,
              child: _ChartGridLines(
                labelCount: yLabels.isEmpty ? 3 : yLabels.length,
                color: muted.withValues(alpha: 0.16),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: reserved),
              child: chart,
            ),
            if (reserved > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reserved,
                child: _YAxisLabels(labels: yLabels, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// 柱线组合图：柱状图与折线图共用坐标区；气泡由适配层绘制在图表最上层，避免被曲线遮挡。
class InteractiveComboChart extends StatefulWidget {
  const InteractiveComboChart({
    super.key,
    required this.barValues,
    required this.lineValues,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    required this.barColor,
    required this.lineColor,
    this.labelColor,
    required this.tooltipOf,
  });

  final List<double> barValues;
  final List<double> lineValues;
  final List<String> xLabels;
  final List<String> yLabels;
  final Color barColor;
  final Color lineColor;
  final Color? labelColor;
  final ChartTooltip Function(int index) tooltipOf;

  @override
  State<InteractiveComboChart> createState() => _InteractiveComboChartState();
}

class _InteractiveComboChartState extends State<InteractiveComboChart> {
  int? _selectedIndex;

  /// 按气泡实际文案测量宽度：与 [_ComboTooltipCard] 的 padding、字号、字重一致，
  /// 用于把气泡居中在选中槽位上，同时避免越出卡片右缘。
  double _tooltipWidth(BuildContext context, ChartTooltip tooltip) {
    final textScaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    var width = measure(tooltip.title, _comboTooltipTitleStyle);
    for (final line in tooltip.lines) {
      width = math.max(width, measure(line.text, _comboTooltipLineStyle));
    }
    return (width + _comboTooltipPadding * 2).clamp(0.0, _comboTooltipMaxWidth);
  }

  @override
  void didUpdateWidget(covariant InteractiveComboChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.barValues, widget.barValues) ||
        !listEquals(oldWidget.lineValues, widget.lineValues)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barValues = widget.barValues;
    final lineValues = widget.lineValues;
    if (barValues.isEmpty && lineValues.isEmpty) {
      return const SizedBox.shrink();
    }
    final allValues = <double>[...barValues, ...lineValues];
    final range = _yRange(allValues);
    final minY = math.min(0.0, range.min);
    final maxY = math.max(0.0, range.max);
    final muted =
        widget.labelColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
    final reserved = _axisReservedSize(context, widget.yLabels);
    final barWidth = (240 / math.max(barValues.length, 1))
        .clamp(6.0, 20.0)
        .toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final plotWidth = math.max(0.0, width - reserved);
        final count = math.max(barValues.length, 1);

        final barChart = BarChart(
          BarChartData(
            minY: minY,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            groupsSpace: 4,
            barGroups: <BarChartGroupData>[
              for (var i = 0; i < barValues.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: barValues[i],
                      color: widget.barColor,
                      width: barWidth,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
            titlesData: _titlesData(
              context: context,
              xLabels: widget.xLabels,
              xValueCount: barValues.length,
              labelColor: muted,
            ),
            gridData: _noGridData,
            borderData: FlBorderData(show: false),
            barTouchData: const BarTouchData(enabled: false),
          ),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );

        // 折线坐标直接使用「第 i 个槽位中心 = i + 0.5」的数据坐标，
        // 与 BarChartAlignment.spaceAround 的柱子中心像素位置一一对应，
        // 这样预算折线点会落在柱子正上方。
        final lineChart = LineChart(
          LineChartData(
            minX: 0,
            maxX: count.toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: <FlSpot>[
                  for (
                    var i = 0;
                    i < lineValues.length && i < barValues.length;
                    i++
                  )
                    FlSpot(i + 0.5, lineValues[i]),
                ],
                color: widget.lineColor,
                barWidth: 2.2,
                isCurved: true,
                curveSmoothness: 0.35,
                preventCurveOverShooting: true,
                isStrokeCapRound: true,
                isStrokeJoinRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: <Color>[
                      widget.lineColor.withValues(alpha: 0.24),
                      widget.lineColor.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            titlesData: _titlesData(
              context: context,
              xLabels: widget.xLabels,
              xValueCount: barValues.length,
              labelColor: muted,
              renderTitles: false,
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
          ),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );

        final selected = _selectedIndex;
        final slot = plotWidth / count;
        final tooltipWidth = selected == null
            ? 0.0
            : _tooltipWidth(context, widget.tooltipOf(selected));
        final left = selected == null
            ? 0.0
            : (reserved + slot * (selected + 0.5) - tooltipWidth / 2)
                  .clamp(0.0, math.max(0.0, width - tooltipWidth))
                  .toDouble();
        void selectAt(double localX) {
          if (localX < reserved || barValues.isEmpty) {
            return;
          }
          final index = ((localX - reserved) / slot).floor().clamp(
            0,
            barValues.length - 1,
          );
          setState(
            () => _selectedIndex = index == _selectedIndex ? null : index,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => selectAt(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              selectAt(details.localPosition.dx),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(left: reserved),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: _ChartGridLines(
                          labelCount: widget.yLabels.isEmpty
                              ? 3
                              : widget.yLabels.length,
                          color: muted.withValues(alpha: 0.16),
                        ),
                      ),
                      Positioned.fill(child: barChart),
                      Positioned.fill(child: IgnorePointer(child: lineChart)),
                    ],
                  ),
                ),
              ),
              if (reserved > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: reserved,
                  child: _YAxisLabels(labels: widget.yLabels, color: muted),
                ),
              if (selected != null)
                Positioned(
                  left: left,
                  top: 0,
                  child: IgnorePointer(
                    child: _ComboTooltipCard(
                      tooltip: widget.tooltipOf(selected),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ComboTooltipCard extends StatelessWidget {
  const _ComboTooltipCard({required this.tooltip});

  final ChartTooltip tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: _comboTooltipMaxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: _comboTooltipPadding,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _chartTooltipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(tooltip.title, style: _comboTooltipTitleStyle),
          for (final line in tooltip.lines)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                line.text,
                style: line.color == null
                    ? _comboTooltipLineStyle
                    : _comboTooltipLineStyle.copyWith(color: line.color),
              ),
            ),
        ],
      ),
    );
  }
}

/// 环形图数据段。
class VeriDonutSegment {
  const VeriDonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// 环形图：内部由 `fl_chart` 渲染，点击分段后通过 [onSelected] 回传索引。
class VeriDonutChart extends StatelessWidget {
  const VeriDonutChart({
    super.key,
    required this.segments,
    this.center,
    this.ringWidth = 22,
    this.trackColor,
    this.selectedIndex,
    this.onSelected,
    this.semanticsLabel,
  });

  final List<VeriDonutSegment> segments;
  final Widget? center;
  final double ringWidth;
  final Color? trackColor;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelected;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final chart = LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final centerSpaceRadius = math.max(0.0, size / 2 - ringWidth - 2);
        final pie = PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: centerSpaceRadius,
            startDegreeOffset: -90,
            sections: <PieChartSectionData>[
              for (var i = 0; i < segments.length; i++)
                PieChartSectionData(
                  value: math.max(0, segments[i].value),
                  color: selectedIndex == null || selectedIndex == i
                      ? segments[i].color
                      : segments[i].color.withValues(alpha: 0.30),
                  radius: selectedIndex == i ? ringWidth * 1.08 : ringWidth,
                  showTitle: false,
                  cornerRadius: ringWidth * 0.32,
                ),
            ],
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent) {
                  final rawIndex =
                      response?.touchedSection?.touchedSectionIndex;
                  final index =
                      rawIndex != null &&
                          rawIndex >= 0 &&
                          rawIndex < segments.length
                      ? rawIndex
                      : null;
                  onSelected?.call(index == selectedIndex ? null : index);
                }
              },
            ),
          ),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(child: pie),
            if (center != null) Center(child: IgnorePointer(child: center)),
          ],
        );
      },
    );
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: chart,
      ),
    );
  }
}

/// 预算/额度进度环：轨底 + 进度弧，中心内容由调用方提供。
class VeriBudgetRing extends StatelessWidget {
  const VeriBudgetRing({
    super.key,
    required this.value,
    required this.trackColor,
    required this.progressColor,
    this.center,
    this.strokeWidth = 11,
  });

  final double value;
  final Color trackColor;
  final Color progressColor;
  final Widget? center;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final centerSpaceRadius = math.max(0.0, size / 2 - strokeWidth - 2);
        final track = PieChartData(
          centerSpaceRadius: centerSpaceRadius,
          sectionsSpace: 0,
          startDegreeOffset: -90,
          sections: <PieChartSectionData>[
            PieChartSectionData(
              value: 1,
              color: trackColor,
              radius: strokeWidth,
              showTitle: false,
            ),
          ],
          pieTouchData: PieTouchData(enabled: false),
        );
        final progressSections = <PieChartSectionData>[
          if (ratio > 0)
            PieChartSectionData(
              value: ratio,
              color: progressColor,
              radius: strokeWidth,
              showTitle: false,
              cornerRadius: strokeWidth * 0.5,
            ),
          if (ratio < 1)
            PieChartSectionData(
              value: 1 - ratio,
              color: Colors.transparent,
              radius: strokeWidth,
              showTitle: false,
            ),
        ];
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: PieChart(
                track,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              ),
            ),
            if (progressSections.isNotEmpty)
              Positioned.fill(
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: centerSpaceRadius,
                    sectionsSpace: 0,
                    startDegreeOffset: -90,
                    sections: progressSections,
                  ),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                ),
              ),
            if (center != null) Center(child: IgnorePointer(child: center)),
          ],
        );
      },
    );
  }
}
