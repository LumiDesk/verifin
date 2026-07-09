part of 'budget_pages.dart';

class _BudgetTrendCard extends StatefulWidget {
  const _BudgetTrendCard({required this.months});

  final List<BudgetMonthSnapshot> months;

  @override
  State<_BudgetTrendCard> createState() => _BudgetTrendCardState();
}

class _BudgetTrendCardState extends State<_BudgetTrendCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _BudgetTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months.length != widget.months.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final maxValue = months.fold<double>(
      0,
      (max, item) => math.max(max, math.max(item.expense, item.budget)),
    );
    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).last6MonthsTrend,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ChartLegendDot(
                    color: veriRoyal,
                    label: AppLocalizations.of(context).budgetLegend,
                  ),
                  const SizedBox(width: 8),
                  _ChartLegendDot(
                    color: veriExpense,
                    label: AppLocalizations.of(context).entryTypeExpense,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                Rect chartRect() =>
                    trendChartRect(size, hasXLabels: true, hasYLabels: true);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final index = chartSlotIndex(
                      details.localPosition,
                      chartRect(),
                      months.length,
                    );
                    setState(() {
                      _selectedIndex = index == _selectedIndex ? null : index;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    final index = chartSlotIndex(
                      details.localPosition,
                      chartRect(),
                      months.length,
                    );
                    if (index != null && index != _selectedIndex) {
                      setState(() => _selectedIndex = index);
                    }
                  },
                  child: CustomPaint(
                    painter: _BudgetTrendPainter(
                      months: months,
                      monthLabelOf: (month) =>
                          AppLocalizations.of(context).monthNumber(month),
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.50),
                      yLabels: reportAxisLabels(maxValue),
                      selectedIndex: _selectedIndex,
                      tooltip: _selectedIndex == null
                          ? null
                          : _tooltipFor(months[_selectedIndex!]),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ChartTooltip _tooltipFor(BudgetMonthSnapshot snapshot) {
    return ChartTooltip(
      title: AppLocalizations.of(context).yearMonth(snapshot.month),
      lines: <ChartTooltipLine>[
        ChartTooltipLine(
          text: AppLocalizations.of(
            context,
          ).budgetTotalLabel(formatAmount(snapshot.budget)),
          color: veriRoyal,
        ),
        ChartTooltipLine(
          text: AppLocalizations.of(
            context,
          ).expenseAmountLabel(formatExpenseAmount(snapshot.expense)),
          color: veriExpense,
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BudgetTrendPainter extends CustomPainter {
  const _BudgetTrendPainter({
    required this.months,
    required this.monthLabelOf,
    required this.labelColor,
    required this.yLabels,
    this.selectedIndex,
    this.tooltip,
  });

  final List<BudgetMonthSnapshot> months;

  /// 月份坐标标签（由调用方按当前语言解析）。
  final String Function(int month) monthLabelOf;
  final Color labelColor;
  final List<String> yLabels;
  final int? selectedIndex;
  final ChartTooltip? tooltip;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = trendChartRect(size, hasXLabels: true, hasYLabels: true);
    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i += 1) {
      final y = chartRect.bottom - chartRect.height * chartValueScale * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
    }

    final maxValue = math.max(
      months.fold<double>(
        0,
        (max, item) => math.max(max, math.max(item.expense, item.budget)),
      ),
      1,
    );
    final gap = chartRect.width / math.max(months.length, 1);
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          veriExpense.withValues(alpha: 0.82),
          veriExpense.withValues(alpha: 0.30),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    final linePaint = Paint()
      ..color = veriRoyal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = veriRoyal;
    final path = Path();

    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final barHeight =
          item.expense / maxValue * chartRect.height * chartValueScale;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - gap * 0.16,
          chartRect.bottom - barHeight,
          gap * 0.32,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, barPaint);

      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      if (i == 0) {
        path.moveTo(centerX, budgetY);
      } else {
        path.lineTo(centerX, budgetY);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      canvas.drawCircle(Offset(centerX, budgetY), 2.4, pointPaint);
    }

    _drawBudgetTrendLabels(canvas, chartRect);

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < months.length) {
      final item = months[selected];
      final centerX = chartRect.left + gap * selected + gap / 2;
      final budgetY =
          chartRect.bottom -
          item.budget / maxValue * chartRect.height * chartValueScale;
      final barTop =
          chartRect.bottom -
          item.expense / maxValue * chartRect.height * chartValueScale;
      canvas.drawLine(
        Offset(centerX, chartRect.top),
        Offset(centerX, chartRect.bottom),
        Paint()
          ..color = labelColor.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(centerX, budgetY), 5, pointPaint);
      canvas.drawCircle(
        Offset(centerX, budgetY),
        2.3,
        Paint()..color = Colors.white,
      );
      if (tooltip != null) {
        drawChartTooltip(
          canvas,
          size,
          Offset(centerX, math.min(budgetY, barTop)),
          tooltip!,
        );
      }
    }
  }

  void _drawBudgetTrendLabels(Canvas canvas, Rect chartRect) {
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i < yLabels.length; i += 1) {
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: chartRect.left - 4);
      final y =
          chartRect.bottom -
          chartRect.height * chartValueScale * i / (yLabels.length - 1);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    if (months.isEmpty) {
      return;
    }
    final gap = chartRect.width / months.length;
    for (var i = 0; i < months.length; i += 1) {
      final label = monthLabelOf(months[i].month.month);
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: gap);
      final x = chartRect.left + gap * i + gap / 2 - painter.width / 2;
      painter.paint(canvas, Offset(x, chartRect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetTrendPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.yLabels != yLabels ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.tooltip != tooltip;
  }
}
