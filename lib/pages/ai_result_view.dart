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
    final values = rows.map((r) => r.amount).toList();
    final labels = rows.map((r) => r.label).toList();
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          SizedBox(
            height: 150,
            child: InteractiveBarChart(
              values: values,
              xLabels: labels,
              tooltipOf: (index) => ChartTooltip(
                title: labels[index],
                lines: <ChartTooltipLine>[
                  ChartTooltipLine(text: formatAmount(values[index])),
                  ChartTooltipLine(
                    text:
                        '${(rows[index].percent * 100).toStringAsFixed(1)}% · ${AppLocalizations.of(context).entriesCount(rows[index].count)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
            height: 150,
            child: InteractiveTrendChart(
              color: display.isExpense ? veriRoyal : veriMint,
              values: display.values,
              xLabels: display.labels,
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
    final headerStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);
    final cellStyle = Theme.of(context).textTheme.bodySmall;
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardTitle(context, display.title),
          Table(
            border: TableBorder.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
              width: 0.5,
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  for (final header in display.headers)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(header, style: headerStyle),
                    ),
                ],
              ),
              for (final row in display.rows)
                TableRow(
                  children: <Widget>[
                    for (var i = 0; i < display.headers.length; i += 1)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          i < row.length ? row[i] : '',
                          style: cellStyle,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
