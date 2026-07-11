import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/category_tree.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import 'ai_chat_page.dart';
import 'budget_pages.dart';
import 'panel_settings_page.dart';
import 'report_analysis_page.dart';
import '../l10n/app_localizations.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final now = DateTime.now();
    final monthEntries = entries
        .where((entry) => isInMonth(entry, now))
        .toList(growable: false);
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final monthlyBudget = controller.monthlyBudget(now);
    final categoryBudgetSnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: now,
      monthEntries: monthEntries,
    );
    final expenseEntries = monthEntries
        .where((entry) => entry.type == EntryType.expense)
        .toList(growable: false);
    final categoryStats = _categoryStats(expenseEntries, controller.categories);
    final tagStats = _tagStats(expenseEntries, controller.tags, monthExpense);
    final trendWindow = cumulativeWeekWindowFor(DateTime.now());
    final trendValues = valuesForTypeInWindow(
      entries,
      trendWindow,
      EntryType.expense,
    );
    final trendExpense = trendValues.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final trendMax = trendValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final monthlyValues = monthlyExpenseValues(entries);
    final monthlyMax = monthlyValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final panelIds = controller.enabledPanelIds(PanelPageKind.reports);

    // 面板 id 对应的卡片,渲染顺序与开关由面板管理页配置。
    Widget panelFor(String id) {
      switch (id) {
        case 'budget_execution':
          return _BudgetExecutionCard(
            budget: monthlyBudget,
            expense: monthExpense,
            snapshots: categoryBudgetSnapshots,
          );
        case 'category_ring':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: AppLocalizations.of(context).panelCategoryRingLabel,
                  trailing:
                      '${formatExpenseAmount(monthExpense)} · ${AppLocalizations.of(context).monthNumber(DateTime.now().month)} · ${AppLocalizations.of(context).entryTypeExpense}',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    return _CategoryRingChart(
                      stats: categoryStats,
                      total: monthExpense,
                      ringSize: compact ? 126 : 156,
                    );
                  },
                ),
              ],
            ),
          );
        case 'category_rank':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: AppLocalizations.of(context).panelCategoryRankLabel,
                  trailing: AppLocalizations.of(context).entryTypeExpense,
                ),
                const SizedBox(height: 8),
                if (categoryStats.isEmpty)
                  EmptyState(
                    icon: Icons.donut_small_outlined,
                    title: AppLocalizations.of(context).noCategoryData,
                    description: AppLocalizations.of(context).noCategoryDesc,
                  )
                else
                  ...categoryStats
                      .take(6)
                      .map((stat) => _CategoryStatTile(stat: stat)),
              ],
            ),
          );
        case 'daily_trend':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: AppLocalizations.of(context).panelDailyTrendLabel,
                  trailing: formatExpenseAmount(trendExpense),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 138,
                  child: InteractiveTrendChart(
                    color: isZeroAmount(trendExpense)
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.42)
                        : veriExpense,
                    values: trendValues,
                    xLabels: labelsForWindow(trendWindow),
                    yLabels: reportAxisLabels(trendMax),
                    labelColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.50),
                    tooltipOf: (index) {
                      final day = trendWindow.days[index];
                      return ChartTooltip(
                        title: AppLocalizations.of(context).dateMonthDay(day),
                        lines: <ChartTooltipLine>[
                          ChartTooltipLine(
                            text: AppLocalizations.of(context)
                                .expenseAmountLabel(
                                  formatExpenseAmount(trendValues[index]),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        case 'monthly_structure':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: AppLocalizations.of(
                    context,
                  ).panelMonthlyStructureLabel,
                  trailing: AppLocalizations.of(context).thisYearLabel,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 146,
                  child: InteractiveBarChart(
                    values: monthlyValues,
                    xLabels: const <String>[
                      '1',
                      '2',
                      '3',
                      '4',
                      '5',
                      '6',
                      '7',
                      '8',
                      '9',
                      '10',
                      '11',
                      '12',
                    ],
                    yLabels: reportAxisLabels(monthlyMax),
                    labelColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.50),
                    tooltipOf: (index) => ChartTooltip(
                      title: AppLocalizations.of(
                        context,
                      ).monthNumber(index + 1),
                      lines: <ChartTooltipLine>[
                        ChartTooltipLine(
                          text: AppLocalizations.of(context).expenseAmountLabel(
                            formatExpenseAmount(monthlyValues[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        case 'tag_stats':
          return VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: AppLocalizations.of(context).panelTagStatsLabel,
                  trailing: AppLocalizations.of(context).budgetMonthExpense,
                ),
                const SizedBox(height: 8),
                if (tagStats.isEmpty)
                  EmptyState(
                    icon: Icons.label_outline,
                    title: AppLocalizations.of(context).noTagData,
                    description: AppLocalizations.of(context).noTagDesc,
                  )
                else
                  ...tagStats.take(8).map((stat) => _TagStatTile(stat: stat)),
              ],
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabReports,
            subtitle: AppLocalizations.of(context).reportsSubtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HeaderAction(
                  icon: Icons.smart_toy_outlined,
                  tooltip: AppLocalizations.of(context).aiChatTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AiChatPage()),
                  ),
                ),
                HeaderAction(
                  icon: Icons.insights_outlined,
                  tooltip: AppLocalizations.of(context).statAnalysisTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportAnalysisPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final id in panelIds) ...<Widget>[
            const SizedBox(height: 10),
            panelFor(id),
          ],
          const SizedBox(height: 8),
          const PanelSettingsEntry(kind: PanelPageKind.reports),
        ],
      ),
    );
  }
}

class _BudgetExecutionCard extends StatelessWidget {
  const _BudgetExecutionCard({
    required this.budget,
    required this.expense,
    required this.snapshots,
  });

  final double budget;
  final double expense;
  final List<CategoryBudgetSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : expense / budget;
    final remaining = budget - expense;
    final budgetedCount = snapshots
        .where((snapshot) => snapshot.hasBudget)
        .length;
    final overBudgetCount = snapshots
        .where((snapshot) => snapshot.overBudget)
        .length;
    final color = budget <= 0
        ? veriLine
        : remaining < 0
        ? veriExpense
        : ratio >= 0.85
        ? veriWarning
        : veriRoyal;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).panelBudgetExecutionLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                AppLocalizations.of(context).monthNumber(DateTime.now().month),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      budget <= 0
                          ? AppLocalizations.of(context).notSetBudget
                          : remaining < 0
                          ? AppLocalizations.of(context).overBudgetLabel
                          : AppLocalizations.of(context).remainingBudgetLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget <= 0
                          ? formatExpenseAmount(expense)
                          : remaining < 0
                          ? formatExpenseAmount(remaining.abs())
                          : formatAmount(remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Text(
                budget <= 0
                    ? AppLocalizations.of(context).expenseOnlyNote
                    : AppLocalizations.of(
                        context,
                      ).usedPercent((ratio * 100).toStringAsFixed(0)),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 0 : ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetExecutionMetric(
                  label: AppLocalizations.of(context).monthBudgetLabel,
                  value: formatAmount(budget),
                ),
              ),
              Expanded(
                child: _BudgetExecutionMetric(
                  label: AppLocalizations.of(context).budgetMonthExpense,
                  value: formatExpenseAmount(expense),
                ),
              ),
              Expanded(
                child: _BudgetExecutionMetric(
                  label: AppLocalizations.of(context).categoryBudgetTitle,
                  value: AppLocalizations.of(context).countItems(budgetedCount),
                  accent: overBudgetCount > 0
                      ? AppLocalizations.of(
                          context,
                        ).overCountLabel(overBudgetCount)
                      : AppLocalizations.of(context).normalLabel,
                  accentColor: overBudgetCount > 0 ? veriExpense : veriIncome,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetExecutionMetric extends StatelessWidget {
  const _BudgetExecutionMetric({
    required this.label,
    required this.value,
    this.accent,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? accent;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (accent != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            accent!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  accentColor ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.44),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryRingChart extends StatefulWidget {
  const _CategoryRingChart({
    required this.stats,
    required this.total,
    required this.ringSize,
  });

  final List<_CategoryStat> stats;
  final double total;
  final double ringSize;

  @override
  State<_CategoryRingChart> createState() => _CategoryRingChartState();
}

class _CategoryRingChartState extends State<_CategoryRingChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _CategoryRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats) {
      _selectedIndex = null;
    }
  }

  /// 点击环形图:命中环上的分段则选中/取消,命中中心或环外则清除选中。
  void _handleTap(Offset localPosition, List<_CategoryRingSegment> segments) {
    final ringSize = widget.ringSize;
    final center = Offset(ringSize / 2, ringSize / 2);
    final offset = localPosition - center;
    final radius = offset.distance;
    final strokeWidth = math.max(12.0, ringSize * 0.14);
    final outer = ringSize / 2 + 5;
    final inner = ringSize / 2 - strokeWidth - 5;
    int? hit;
    if (radius <= outer && radius >= inner) {
      var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
      if (angle < 0) {
        angle += math.pi * 2;
      }
      var start = 0.0;
      for (final item in segments.indexed) {
        final sweep = math.pi * 2 * item.$2.percent;
        if (angle >= start && angle < start + sweep) {
          hit = item.$1;
          break;
        }
        start += sweep;
      }
    }
    setState(() {
      _selectedIndex = hit == _selectedIndex ? null : hit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final segments = _categoryRingSegments(
      AppLocalizations.of(context),
      widget.stats,
    );
    final ringSize = widget.ringSize;
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.56);
    final selected = _selectedIndex != null && _selectedIndex! < segments.length
        ? segments[_selectedIndex!]
        : null;

    return SizedBox(
      width: double.infinity,
      height: ringSize + 26,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _CategoryCalloutPainter(
                segments: segments,
                ringSize: ringSize,
                textColor: mutedColor,
              ),
            ),
          ),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: segments.isEmpty
                  ? null
                  : (details) => _handleTap(details.localPosition, segments),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CustomPaint(
                    painter: _CategoryDonutPainter(
                      segments: segments,
                      trackColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.64),
                      selectedIndex: _selectedIndex,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  SizedBox(
                    width: ringSize * 0.56,
                    child: selected == null
                        ? Text(
                            formatExpenseAmount(widget.total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                selected.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: mutedColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                formatExpenseAmount(selected.amount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${(selected.percent * 100).toStringAsFixed(1)}%',
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: selected.color,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRingSegment {
  const _CategoryRingSegment({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String label;
  final double amount;
  final double percent;
  final Color color;
}

List<_CategoryRingSegment> _categoryRingSegments(
  AppLocalizations l10n,
  List<_CategoryStat> stats,
) {
  if (stats.isEmpty) {
    return const <_CategoryRingSegment>[];
  }
  const colors = <Color>[
    veriRoyal,
    veriBlue,
    veriCyan,
    veriMint,
    veriWarning,
    Color(0xFF8B95A7),
  ];
  final total = stats.fold<double>(0, (sum, stat) => sum + stat.amount);
  if (total <= 0) {
    return const <_CategoryRingSegment>[];
  }
  final visible = stats.take(5).toList();
  final hidden = stats.skip(5).toList();
  final segments = <_CategoryRingSegment>[
    for (final item in visible.indexed)
      _CategoryRingSegment(
        label: item.$2.category.label,
        amount: item.$2.amount,
        percent: item.$2.amount / total,
        color: colors[item.$1 % colors.length],
      ),
  ];
  final otherAmount = hidden.fold<double>(0, (sum, stat) => sum + stat.amount);
  if (otherAmount > 0) {
    segments.add(
      _CategoryRingSegment(
        label: l10n.othersLabel,
        amount: otherAmount,
        percent: otherAmount / total,
        color: colors.last,
      ),
    );
  }
  return segments;
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter({
    required this.segments,
    required this.trackColor,
    this.selectedIndex,
  });

  final List<_CategoryRingSegment> segments;
  final Color trackColor;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.max(12.0, size.shortestSide * 0.14);
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, trackPaint);
    if (segments.isEmpty) {
      return;
    }

    var start = -math.pi / 2;
    for (final item in segments.indexed) {
      final segment = item.$2;
      final sweep = math.pi * 2 * segment.percent;
      // 有选中分段时,其余分段弱化并略微收窄,突出当前分类。
      final isSelected = selectedIndex == null || selectedIndex == item.$1;
      final paint = Paint()
        ..color = isSelected
            ? segment.color
            : segment.color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedIndex == item.$1
            ? strokeWidth * 1.14
            : strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        arcRect,
        start,
        math.max(0.02, sweep - 0.018),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _CategoryCalloutPainter extends CustomPainter {
  const _CategoryCalloutPainter({
    required this.segments,
    required this.ringSize,
    required this.textColor,
  });

  final List<_CategoryRingSegment> segments;
  final double ringSize;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = ringSize / 2;
    var startAngle = -math.pi / 2;
    for (final item in segments.indexed) {
      final segment = item.$2;
      final sweep = math.pi * 2 * segment.percent;
      final angle = startAngle + sweep / 2;
      startAngle += sweep;
      if (item.$1 >= 6 || segment.percent < 0.035) {
        continue;
      }
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * radius;
      final elbow = center + direction * (radius + 12);
      final rightSide = direction.dx >= 0;
      final end = Offset(elbow.dx + (rightSide ? 32 : -32), elbow.dy);
      final paint = Paint()
        ..color = segment.color.withValues(alpha: 0.82)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, elbow, paint);
      canvas.drawLine(elbow, end, paint);
      canvas.drawCircle(start, 2.2, Paint()..color = segment.color);

      final label = '${segment.label} ${(segment.percent * 100).round()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
        textAlign: rightSide ? TextAlign.left : TextAlign.right,
      )..layout(maxWidth: 74);
      final textOffset = Offset(
        rightSide ? end.dx + 5 : end.dx - textPainter.width - 5,
        end.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryCalloutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.ringSize != ringSize ||
        oldDelegate.textColor != textColor;
  }
}

class _CategoryStat {
  const _CategoryStat({
    required this.category,
    required this.amount,
    required this.percent,
    required this.count,
  });

  final Category category;
  final double amount;
  final double percent;
  final int count;
}

class _CategoryStatTile extends StatelessWidget {
  const _CategoryStatTile({required this.stat});

  final _CategoryStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          CategoryIconBox(
            iconCode: stat.category.iconCode,
            color: veriExpense,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        stat.category.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '-${formatAmount(stat.amount)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: veriExpense,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: stat.percent.clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: veriExpense,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(stat.percent * 100).toStringAsFixed(1)}% · ${AppLocalizations.of(context).entriesCount(stat.count)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.46),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagStatTile extends StatelessWidget {
  const _TagStatTile({required this.stat});

  final _TagStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: Icons.label, color: veriRoyal, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        stat.tag.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '-${formatAmount(stat.amount)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: veriExpense,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: stat.percent.clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: veriRoyal,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalizations.of(context).tagShareOfExpense((stat.percent * 100).toStringAsFixed(1))} · ${AppLocalizations.of(context).entriesCount(stat.count)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.46),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类统计：多级分类按层级聚合，即每笔交易的金额归总到其**顶级祖先**分类，
/// 子分类的支出滚动计入所属顶级分类。
List<_CategoryStat> _categoryStats(
  List<LedgerEntry> entries,
  List<Category> categories,
) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    final rootId = rootIdOf(categories, entry.categoryId);
    // 退款/报销回款按净额计入分类统计。
    totals.update(
      rootId,
      (value) => value + entry.netAmount,
      ifAbsent: () => entry.netAmount,
    );
    counts.update(rootId, (value) => value + 1, ifAbsent: () => 1);
  }

  final total = totals.values.fold<double>(0, (sum, value) => sum + value);
  final stats =
      totals.entries
          .map(
            (entry) => _CategoryStat(
              category: categoryById(entry.key, categories),
              amount: entry.value,
              percent: total <= 0 ? 0 : entry.value / total,
              count: counts[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return stats;
}

class _TagStat {
  const _TagStat({
    required this.tag,
    required this.amount,
    required this.percent,
    required this.count,
  });

  final Tag tag;
  final double amount;

  /// 该标签支出占本月总支出的比例（多标签交易会分别计入各标签，故各项之和可能 >1）。
  final double percent;
  final int count;
}

/// 标签统计：每笔支出计入其携带的**每个**标签；[totalExpense] 为本月总支出，
/// 用作占比分母（表示该标签覆盖了本月多少支出）。
List<_TagStat> _tagStats(
  List<LedgerEntry> entries,
  List<Tag> tags,
  double totalExpense,
) {
  final labelById = <String, Tag>{for (final tag in tags) tag.id: tag};
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    for (final tagId in entry.tagIds) {
      if (!labelById.containsKey(tagId)) {
        continue;
      }
      totals.update(
        tagId,
        (value) => value + entry.netAmount,
        ifAbsent: () => entry.netAmount,
      );
      counts.update(tagId, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  final stats =
      totals.entries
          .map(
            (entry) => _TagStat(
              tag: labelById[entry.key]!,
              amount: entry.value,
              percent: totalExpense <= 0 ? 0 : entry.value / totalExpense,
              count: counts[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return stats;
}
