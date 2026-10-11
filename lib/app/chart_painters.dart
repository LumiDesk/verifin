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
          // 默认阈值是 10dp 且只比较横轴距离：点数少的图（7 天、12 个月）大部分
          // 区域都点不中，横向按住拖动也就时灵时不灵。这里让整片绘图区都命中
          // 最近的横轴位置，仍保留库默认的「按住查看、松手收起」。
          touchSpotThreshold: double.infinity,
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

/// 柱状图的一条序列。传入多条约 [InteractiveBarChart.series] 时，同一插槽内
/// 会并排绘制成一组柱子（双柱/分组柱）。
class VeriBarSeries {
  const VeriBarSeries({required this.values, required this.color});

  final List<double> values;
  final Color color;
}

/// 可交互柱状图：内部由 `fl_chart` 渲染，按住或横向滑动查看数据气泡。
///
/// 命中由适配层按插槽自己算，而不是用库自带的矩形命中：零值月份和柱子上方的
/// 空白在矩形命中里都点不中，横向按住拖动会时灵时不灵。按插槽取最近一根柱子后
/// 整片绘图区都能响应，横向拖动可连续查看，仍保留「按住查看、松手收起」。
class InteractiveBarChart extends StatefulWidget {
  const InteractiveBarChart({
    super.key,
    this.values = const <double>[],
    this.series,
    this.xLabels = const <String>[],
    this.yLabels = const <String>[],
    this.labelColor,
    required this.tooltipOf,
    this.semanticsLabel,
  }) : assert(
         (values.length == 0 ? 0 : 1) + (series == null ? 0 : 1) == 1,
         '单序列传 values，多序列传 series，二选一',
       );

  /// 单序列数据；与 [series] 二选一。
  final List<double> values;

  /// 多序列数据；同一插槽内并排绘制，按最短序列对齐。
  final List<VeriBarSeries>? series;

  final List<String> xLabels;
  final List<String> yLabels;
  final Color? labelColor;

  /// 按插槽索引生成气泡内容；分组柱的气泡一次展示该插槽的全部序列。
  final ChartTooltip Function(int index) tooltipOf;
  final String? semanticsLabel;

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart> {
  /// 当前按住查看的插槽；松手即收起，保持库默认的「按住看数据」手感。
  int? _pressedIndex;

  List<VeriBarSeries> _resolvedSeries(BuildContext context) {
    final series = widget.series;
    if (series != null) {
      return series;
    }
    return <VeriBarSeries>[
      VeriBarSeries(
        values: widget.values,
        color: Theme.of(context).colorScheme.primary,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant InteractiveBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values) ||
        !_sameSeries(oldWidget.series, widget.series)) {
      _pressedIndex = null;
    }
  }

  bool _sameSeries(List<VeriBarSeries>? a, List<VeriBarSeries>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null || a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].color != b[i].color || !listEquals(a[i].values, b[i].values)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final series = _resolvedSeries(context);
    final groupCount = series.isEmpty
        ? 0
        : series.map((item) => item.values.length).reduce(math.min);
    if (groupCount == 0) {
      return const SizedBox.shrink();
    }
    final allValues = <double>[
      for (final item in series) ...item.values.take(groupCount),
    ];
    final range = _yRange(allValues);
    final minY = math.min(0.0, range.min);
    final maxY = math.max(0.0, range.max);
    final muted =
        widget.labelColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);
    final reserved = _axisReservedSize(context, widget.yLabels);

    return Semantics(
      container: true,
      label:
          widget.semanticsLabel ??
          AppLocalizations.of(context).chartBarSemantics(groupCount),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = math.max(0.0, constraints.maxWidth - reserved);
          final slot = plotWidth / groupCount;
          // 一个插槽内先给整组柱子留出宽度，再平分给每条序列。
          final groupWidth = (slot * (series.length == 1 ? 0.68 : 0.56))
              .clamp(5.0, 56.0)
              .toDouble();
          final rodsSpace = series.length > 1 ? 2.0 : 0.0;
          final rodWidth =
              ((groupWidth - rodsSpace * (series.length - 1)) / series.length)
                  .clamp(2.5, 24.0)
                  .toDouble();
          final pressed = _pressedIndex;

          final chart = BarChart(
            BarChartData(
              minY: minY,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 4,
              barGroups: <BarChartGroupData>[
                for (var i = 0; i < groupCount; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: rodsSpace,
                    // 气泡挂在同组最高的一根柱子上，避免压在数据上；
                    // 内容由调用方一次给出整组的全部序列。
                    showingTooltipIndicators: pressed == i
                        ? <int>[_highestRodIndex(series, i)]
                        : const <int>[],
                    barRods: <BarChartRodData>[
                      for (final item in series)
                        BarChartRodData(
                          toY: item.values[i],
                          color: item.color,
                          width: rodWidth,
                          borderRadius: BorderRadius.circular(4),
                        ),
                    ],
                  ),
              ],
              titlesData: _titlesData(
                context: context,
                xLabels: widget.xLabels,
                xValueCount: groupCount,
                labelColor: muted,
              ),
              gridData: _noGridData,
              borderData: FlBorderData(show: false),
              // 气泡由适配层按插槽驱动，关闭库自带的矩形命中。
              barTouchData: BarTouchData(
                handleBuiltInTouches: false,
                touchTooltipData: _barTooltipData(widget.tooltipOf),
              ),
            ),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );

          void selectAt(double localX) {
            final index = ((localX - reserved) / slot).floor().clamp(
              0,
              groupCount - 1,
            );
            if (index != _pressedIndex) {
              setState(() => _pressedIndex = index);
            }
          }

          // 外层 GestureDetector 只用来拦截点击：图表放在可跳转卡片里时，
          // 点图表只应展示数据，不能触发卡片跳转（与折线图一致）。
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                // 按在纵轴刻度区不算选中；横向拖出绘图区则贴住首尾插槽。
                if (event.localPosition.dx < reserved) {
                  _clearSelection();
                  return;
                }
                selectAt(event.localPosition.dx);
              },
              onPointerMove: (event) => selectAt(event.localPosition.dx),
              onPointerUp: (_) => _clearSelection(),
              onPointerCancel: (_) => _clearSelection(),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: reserved,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: _ChartGridLines(
                      labelCount: widget.yLabels.isEmpty
                          ? 3
                          : widget.yLabels.length,
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
                      child: _YAxisLabels(labels: widget.yLabels, color: muted),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _highestRodIndex(List<VeriBarSeries> series, int groupIndex) {
    var best = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i].values[groupIndex] > series[best].values[groupIndex]) {
        best = i;
      }
    }
    return best;
  }

  void _clearSelection() {
    if (_pressedIndex != null) {
      setState(() => _pressedIndex = null);
    }
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
