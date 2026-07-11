// AI 对话查询结果的渲染层：把工具产出的 [AiResultDisplay] 规格映射成图表 / 列表 /
// 统计卡 / 表格。与工具逻辑解耦——新增展示类型只需在 switch 里加一支。
import 'package:flutter/material.dart';

import '../app/ai/ai_query_tool.dart';
import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'transaction_detail_page.dart';

/// 把一条 [AiResultDisplay] 渲染成卡片。
class AiResultView extends StatelessWidget {
  const AiResultView({super.key, required this.display});

  final AiResultDisplay display;

  @override
  Widget build(BuildContext context) {
    return switch (display) {
      final AiStatDisplay d => _StatCard(d),
      final AiRankingDisplay d => _RankingCard(d),
      final AiTrendDisplay d => _TrendCard(d),
      final AiTransactionsDisplay d => _TransactionsCard(d),
      final AiTableDisplay d => _TableCard(d),
    };
  }
}

Widget _cardTitle(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

Widget _emptyHint(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
    ),
  );
}

/// 图表纵轴 3 档标签：max / max·½ / 0（紧凑格式）。
List<String> _yLabels(BuildContext context, Iterable<double> values) {
  final max = values.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
  if (max <= 0) {
    return const <String>[];
  }
  final l10n = AppLocalizations.of(context);
  return <String>[
    formatCompactAmount(l10n, max),
    formatCompactAmount(l10n, max / 2),
    '0',
  ];
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.display);
  final AiStatDisplay display;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          for (final item in display.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    formatAmount(item.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: item.emphasize
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: item.emphasize ? veriRoyal : null,
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

class _RankingCard extends StatelessWidget {
  const _RankingCard(this.display);
  final AiRankingDisplay display;

  @override
  Widget build(BuildContext context) {
    final rows = display.rows;
    if (rows.isEmpty) {
      return VeriCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(context, display.title),
            _emptyHint(context, AppLocalizations.of(context).aiChatNoData),
          ],
        ),
      );
    }
    // 柱状图只画前若干名，避免横轴标签拥挤；完整明细在下方列表。
    final chartRows = rows.take(7).toList();
    final values = chartRows.map((r) => r.amount).toList();
    final labels = chartRows.map((r) => r.label).toList();
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          SizedBox(
            height: 172,
            child: InteractiveBarChart(
              values: values,
              xLabels: labels,
              yLabels: _yLabels(context, values),
              tooltipOf: (index) => ChartTooltip(
                title: labels[index],
                lines: <ChartTooltipLine>[
                  ChartTooltipLine(text: formatAmount(values[index])),
                  ChartTooltipLine(
                    text:
                        '${(chartRows[index].percent * 100).toStringAsFixed(1)}% · ${AppLocalizations.of(context).entriesCount(chartRows[index].count)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${(row.percent * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatAmount(row.amount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
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

class _TrendCard extends StatelessWidget {
  const _TrendCard(this.display);
  final AiTrendDisplay display;

  @override
  Widget build(BuildContext context) {
    if (display.values.isEmpty) {
      return VeriCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(context, display.title),
            _emptyHint(context, AppLocalizations.of(context).aiChatNoData),
          ],
        ),
      );
    }
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          SizedBox(
            height: 172,
            child: InteractiveTrendChart(
              color: display.isExpense ? veriRoyal : veriMint,
              values: display.values,
              xLabels: display.labels,
              yLabels: _yLabels(context, display.values),
              tooltipOf: (index) => ChartTooltip(
                title: index < display.labels.length
                    ? display.labels[index]
                    : '',
                lines: <ChartTooltipLine>[
                  ChartTooltipLine(text: formatAmount(display.values[index])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard(this.display);
  final AiTransactionsDisplay display;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final byId = <String, LedgerEntry>{
      for (final entry in controller.entries) entry.id: entry,
    };
    final entries = display.entryIds
        .map((id) => byId[id])
        .whereType<LedgerEntry>()
        .toList();
    if (entries.isEmpty) {
      return VeriCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(context, display.title),
            _emptyHint(
              context,
              AppLocalizations.of(context).aiChatNoMatchingTx,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            display.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TransactionListCard(
          entries: entries,
          accounts: controller.accounts,
          categories: controller.categories,
          onEntryTap: (entry) => openEntryDetail(context, entry),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard(this.display);
  final AiTableDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark ? Colors.white10 : veriSurfaceAltLight;
    final divider = theme.colorScheme.onSurface.withValues(alpha: 0.07);
    final headerStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    );
    final cellStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      height: 1.4,
    );

    // 无竖线、仅头部底色 + 行间细分隔线的精致表格；首列左对齐、其余右对齐。
    TableRow rowFor(List<String> cells, {required bool header}) {
      return TableRow(
        children: <Widget>[
          for (var i = 0; i < display.headers.length; i += 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                i < cells.length ? cells[i] : '',
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: header ? headerStyle : cellStyle,
              ),
            ),
        ],
      );
    }

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          ClipRRect(
            borderRadius: BorderRadius.circular(veriRadiusMd),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: divider),
                borderRadius: BorderRadius.circular(veriRadiusMd),
              ),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: divider),
                ),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: const <int, TableColumnWidth>{
                  0: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: <TableRow>[
                  TableRow(
                    decoration: BoxDecoration(color: headerBg),
                    children: <Widget>[
                      for (var i = 0; i < display.headers.length; i += 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            display.headers[i],
                            textAlign: i == 0
                                ? TextAlign.left
                                : TextAlign.right,
                            style: headerStyle,
                          ),
                        ),
                    ],
                  ),
                  for (final row in display.rows) rowFor(row, header: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
      ),
    );
  }
}
