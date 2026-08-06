import '../../l10n/app_localizations.dart';
import 'ai_agent_step.dart';
import 'ai_query_tool.dart';

class AiToolStepPresentation {
  const AiToolStepPresentation({required this.title, required this.detail});
  final String title;
  final String detail;
}

AiToolStepPresentation presentAiAgentStep(
  AppLocalizations l10n,
  AiAgentStep step,
) {
  if (step.toolName == 'agentRetry') {
    return AiToolStepPresentation(
      title: l10n.aiAgentRetryTitle,
      detail: switch (step.summary) {
        'protocolFallback' => l10n.aiAgentRetryProtocol,
        'upstreamResource' => l10n.aiAgentRetryResource,
        _ => l10n.aiAgentRetryNetwork,
      },
    );
  }
  final title = switch (step.toolName) {
    'summary' => l10n.aiToolSummary,
    'categoryRanking' => l10n.aiToolCategoryRanking,
    'tagRanking' => l10n.aiToolTagRanking,
    'queryTransactions' => l10n.aiToolQueryTransactions,
    'largestTransactions' => l10n.aiToolLargestTransactions,
    _ => l10n.aiToolUnknown,
  };
  final details = <String>[
    if (_rangeLabel(l10n, step.arguments) case final String range) range,
    if (_typeLabel(l10n, step.arguments['type']) case final String type) type,
    if (step.arguments['keyword'] case final String keyword
        when keyword.trim().isNotEmpty)
      l10n.aiStepKeyword(keyword.trim()),
    if (step.arguments['limit'] case final num limit)
      l10n.aiStepLimit(limit.toInt()),
  ];
  return AiToolStepPresentation(title: title, detail: details.join(' · '));
}

String presentAiToolResultSummary(AppLocalizations l10n, AiToolResult result) {
  return switch (result.display) {
    AiTransactionsDisplay(:final entryIds) => l10n.aiStepTransactionsFound(
      entryIds.length,
    ),
    AiRankingDisplay(:final rows) => l10n.aiStepItemsFound(rows.length),
    AiStatDisplay() => l10n.aiStepDataReady,
    AiTrendDisplay(:final values) => l10n.aiStepItemsFound(values.length),
    AiTableDisplay(:final rows) => l10n.aiStepItemsFound(rows.length),
    null => l10n.aiStepDataReady,
  };
}

String? _rangeLabel(AppLocalizations l10n, Map<String, Object?> arguments) {
  final start = arguments['start'];
  final end = arguments['end'];
  if (start is String && end is String) return '$start – $end';
  return switch (arguments['range']) {
    'thisMonth' => l10n.thisMonth,
    'lastMonth' => l10n.aiRangeLastMonth,
    'thisYear' => l10n.aiRangeThisYear,
    'lastYear' => l10n.aiRangeLastYear,
    'last7Days' => l10n.aiRangeLast7Days,
    'last30Days' => l10n.aiRangeLast30Days,
    'last3Months' => l10n.aiRangeLast3Months,
    'last6Months' => l10n.aiRangeLast6Months,
    'last12Months' => l10n.aiRangeLast12Months,
    'all' => l10n.allLabel,
    _ => null,
  };
}

String? _typeLabel(AppLocalizations l10n, Object? type) => switch (type) {
  'expense' => l10n.aiTypeExpense,
  'income' => l10n.aiTypeIncome,
  'transfer' => l10n.aiTypeTransfer,
  _ => null,
};
