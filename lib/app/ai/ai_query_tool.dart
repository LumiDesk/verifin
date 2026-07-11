// AI 对话查询账目的「工具」协议与注册表。
//
// 设计目标：**新增一个分析能力 = 写一个 [AiQueryTool] 子类 + 在 [buildAiQueryTools] 注册一行**，
// 提示词、参数说明、结果回喂、UI 渲染全部自动带上，无需改动对话主循环。工具全部**只读、纯函数**
// （输入 [AiToolContext] 数据快照，不依赖 controller），便于单测。
//
// 工具清单、参数、维护约定见 docs/dev/ai-tools.md——新增 / 修复工具须同步更新该文档。
//
// 说明：[AiResultDisplay] 里的 `title` 目前用中文默认文案；国际化（zh/en）随聊天页 UI 的
// i18n 一并处理（见落地顺序第 5 步），此处先留中文默认。
import '../models.dart';
import '../ledger_math.dart';
import '../report_analysis.dart';
import 'ledger_query.dart';

/// 工具执行的只读数据快照。均为「当前活动账本」范围（分类 / 标签为全局），由上层从
/// controller 组装后传入，工具内不再触达 controller，保持纯粹可测。
class AiToolContext {
  const AiToolContext({
    required this.entries,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.balanceOf,
    required this.now,
  });

  /// 当前账本交易（时间倒序或任意序均可，工具自行排序）。
  final List<LedgerEntry> entries;

  /// 当前账本账户。
  final List<Account> accounts;

  /// 全局分类。
  final List<Category> categories;

  /// 全局标签。
  final List<Tag> tags;

  /// 账户当前余额查询（含初始余额与全部交易累积）。
  final double Function(Account account) balanceOf;

  /// 当前时间（相对时间窗如「本月」的基准）。
  final DateTime now;
}

/// 工具执行结果。
///
/// [summary] 是回喂给模型继续推理的**结构化文本**（应紧凑、含关键数字）；
/// [display] 是给聊天页渲染的规格，可为 null（纯文本类结果）。
class AiToolResult {
  const AiToolResult({required this.summary, this.display});

  final String summary;
  final AiResultDisplay? display;
}

/// 结果渲染规格，与具体 widget 解耦——聊天页按类型映射到图表 / 列表 / 卡片。
///
/// 可 [toJson]/[aiResultDisplayFromJson] 序列化，以便随聊天历史落库、重开时还原卡片
/// （交易列表只存 id，重开按当前数据实时解析）。
sealed class AiResultDisplay {
  const AiResultDisplay();

  Map<String, Object?> toJson();
}

/// 从 JSON 还原展示规格；无法识别返回 null。
AiResultDisplay? aiResultDisplayFromJson(Map<String, Object?> json) {
  final title = json['title']?.toString() ?? '';
  switch (json['kind']) {
    case 'stat':
      return AiStatDisplay(
        title: title,
        items: _jsonList(json['items'])
            .map(
              (e) => AiStatItem(
                label: e['label']?.toString() ?? '',
                value: _asDouble(e['value']),
                emphasize: e['emphasize'] == true,
              ),
            )
            .toList(),
      );
    case 'ranking':
      return AiRankingDisplay(
        title: title,
        rows: _jsonList(json['rows'])
            .map(
              (e) => AiRankingRow(
                label: e['label']?.toString() ?? '',
                amount: _asDouble(e['amount']),
                percent: _asDouble(e['percent']),
                count: _asDouble(e['count']).round(),
              ),
            )
            .toList(),
      );
    case 'trend':
      return AiTrendDisplay(
        title: title,
        values: (json['values'] as List? ?? const <Object?>[])
            .map(_asDouble)
            .toList(),
        labels: (json['labels'] as List? ?? const <Object?>[])
            .map((e) => e.toString())
            .toList(),
        isExpense: json['isExpense'] != false,
      );
    case 'transactions':
      return AiTransactionsDisplay(
        title: title,
        entryIds: (json['entryIds'] as List? ?? const <Object?>[])
            .map((e) => e.toString())
            .toList(),
      );
    case 'table':
      return AiTableDisplay(
        title: title,
        headers: (json['headers'] as List? ?? const <Object?>[])
            .map((e) => e.toString())
            .toList(),
        rows: (json['rows'] as List? ?? const <Object?>[])
            .whereType<List>()
            .map((row) => row.map((e) => e.toString()).toList())
            .toList(),
      );
    default:
      return null;
  }
}

List<Map<String, Object?>> _jsonList(Object? value) =>
    (value as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : (value is String ? double.tryParse(value) ?? 0 : 0);

/// 一组统计指标（如收支汇总）。
class AiStatDisplay extends AiResultDisplay {
  const AiStatDisplay({required this.title, required this.items});
  final String title;
  final List<AiStatItem> items;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'stat',
    'title': title,
    'items': items
        .map(
          (i) => <String, Object?>{
            'label': i.label,
            'value': i.value,
            'emphasize': i.emphasize,
          },
        )
        .toList(),
  };
}

class AiStatItem {
  const AiStatItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final double value;

  /// 是否强调（如净额）。
  final bool emphasize;
}

/// 排行 / 占比（分类、标签），渲染为柱状图 + 明细。
class AiRankingDisplay extends AiResultDisplay {
  const AiRankingDisplay({required this.title, required this.rows});
  final String title;
  final List<AiRankingRow> rows;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'ranking',
    'title': title,
    'rows': rows
        .map(
          (r) => <String, Object?>{
            'label': r.label,
            'amount': r.amount,
            'percent': r.percent,
            'count': r.count,
          },
        )
        .toList(),
  };
}

class AiRankingRow {
  const AiRankingRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.count,
  });
  final String label;
  final double amount;

  /// 占比 0..1。
  final double percent;
  final int count;
}

/// 时间序列，渲染为折线图。
class AiTrendDisplay extends AiResultDisplay {
  const AiTrendDisplay({
    required this.title,
    required this.values,
    required this.labels,
    this.isExpense = true,
  });
  final String title;
  final List<double> values;
  final List<String> labels;
  final bool isExpense;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'trend',
    'title': title,
    'values': values,
    'labels': labels,
    'isExpense': isExpense,
  };
}

/// 一组具体交易，渲染为**可点击**的交易列表（点击进详情页）。
class AiTransactionsDisplay extends AiResultDisplay {
  const AiTransactionsDisplay({required this.title, required this.entryIds});
  final String title;
  final List<String> entryIds;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'transactions',
    'title': title,
    'entryIds': entryIds,
  };
}

/// 通用表格（模型自定义多列数据时）。
class AiTableDisplay extends AiResultDisplay {
  const AiTableDisplay({
    required this.title,
    required this.headers,
    required this.rows,
  });
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'table',
    'title': title,
    'headers': headers,
    'rows': rows,
  };
}

/// 工具契约。实现类应无状态、纯函数式。
abstract class AiQueryTool {
  /// 工具名（模型用它指定调用，全局唯一，小驼峰）。
  String get name;

  /// 给模型看的说明：这个工具查什么、何时用。
  String get description;

  /// 给模型看的参数说明：`{参数名: 说明}`。序列化进提示词。
  Map<String, String> get argsSchema;

  /// 执行工具。[args] 为模型给的参数（已 JSON 解码）。实现须对缺省 / 非法参数**优雅降级**，
  /// 不抛异常。
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args);
}

/// 构建工具注册表。**新增工具在此登记一行。**
List<AiQueryTool> buildAiQueryTools() => <AiQueryTool>[
  const SummaryTool(),
  const CategoryRankingTool(),
  const TagRankingTool(),
  const QueryTransactionsTool(),
  const LargestTransactionsTool(),
];

// ─────────────────────────── 参数解析助手 ───────────────────────────

/// 从参数里取字符串。
String? _str(Map<String, Object?> args, String key) {
  final value = args[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

/// 从参数里取数字（容忍字符串数字）。
double? _num(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// 从参数里取整数。
int? _int(Map<String, Object?> args, String key) {
  final value = _num(args, key);
  return value?.round();
}

/// 解析交易类型，默认 [fallback]。
EntryType _type(
  Map<String, Object?> args, {
  EntryType fallback = EntryType.expense,
}) {
  switch (_str(args, 'type')) {
    case 'income':
      return EntryType.income;
    case 'transfer':
      return EntryType.transfer;
    case 'expense':
      return EntryType.expense;
    default:
      return fallback;
  }
}

/// 合法的相对时间窗预设（供 argsSchema 展示给模型）。
const String rangePresetsHelp =
    "range 预设：thisMonth/lastMonth/thisYear/lastYear/last7Days/last30Days/"
    "last3Months/last6Months/last12Months/all；或用 start+end（YYYY-MM-DD）指定。";

/// 解析时间窗：优先 start+end 显式区间，否则按 range 预设，缺省返回 [fallback]。
/// 返回 null 表示「不限时间」（range=all）。
DateWindow? _window(
  Map<String, Object?> args,
  DateTime now, {
  required DateWindow? fallback,
}) {
  final startStr = _str(args, 'start');
  final endStr = _str(args, 'end');
  if (startStr != null && endStr != null) {
    final start = DateTime.tryParse(startStr);
    final end = DateTime.tryParse(endStr);
    if (start != null && end != null) {
      return DateWindow(start: start, end: end);
    }
  }
  final preset = _str(args, 'range');
  switch (preset) {
    case 'all':
      return null;
    case 'thisMonth':
      return monthWindowFor(now);
    case 'lastMonth':
      return monthWindowFor(DateTime(now.year, now.month - 1, 15));
    case 'thisYear':
      return DateWindow(
        start: DateTime(now.year),
        end: DateTime(now.year, 12, 31),
      );
    case 'lastYear':
      return DateWindow(
        start: DateTime(now.year - 1),
        end: DateTime(now.year - 1, 12, 31),
      );
    case 'last7Days':
      return DateWindow(
        start: dateOnly(now).subtract(const Duration(days: 6)),
        end: now,
      );
    case 'last30Days':
      return DateWindow(
        start: dateOnly(now).subtract(const Duration(days: 29)),
        end: now,
      );
    case 'last3Months':
      return DateWindow(start: DateTime(now.year, now.month - 2), end: now);
    case 'last6Months':
      return DateWindow(start: DateTime(now.year, now.month - 5), end: now);
    case 'last12Months':
      return DateWindow(start: DateTime(now.year, now.month - 11), end: now);
    default:
      return fallback;
  }
}

/// 时间窗过滤（null 表示不限）。
List<LedgerEntry> _inWindow(List<LedgerEntry> entries, DateWindow? window) =>
    window == null ? entries : entriesInWindow(entries, window);

String _rangeLabel(DateWindow? window) => window?.label ?? '全部时间';

String _typeLabel(EntryType type) => switch (type) {
  EntryType.income => '收入',
  EntryType.expense => '支出',
  EntryType.transfer => '转账',
  EntryType.refund => '退款',
};

// ─────────────────────────── 工具实现 ───────────────────────────

/// 收支汇总：某时间窗内的收入 / 支出 / 净额与笔数。
class SummaryTool implements AiQueryTool {
  const SummaryTool();

  @override
  String get name => 'summary';

  @override
  String get description => '统计某时间段内的总收入、总支出、净额与笔数。';

  @override
  Map<String, String> get argsSchema => <String, String>{
    'range': rangePresetsHelp,
  };

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final window = _window(args, ctx.now, fallback: monthWindowFor(ctx.now));
    final summary = reportSummary(_inWindow(ctx.entries, window));
    final rangeLabel = _rangeLabel(window);
    return AiToolResult(
      summary:
          '$rangeLabel 收入 ${summary.income.toStringAsFixed(2)}（${summary.incomeCount} 笔），'
          '支出 ${summary.expense.toStringAsFixed(2)}（${summary.expenseCount} 笔），'
          '净额 ${summary.net.toStringAsFixed(2)}。',
      display: AiStatDisplay(
        title: '$rangeLabel · 收支汇总',
        items: <AiStatItem>[
          AiStatItem(label: '收入', value: summary.income),
          AiStatItem(label: '支出', value: summary.expense),
          AiStatItem(label: '净额', value: summary.net, emphasize: true),
        ],
      ),
    );
  }
}

/// 分类排行：某时间窗、某类型（支出 / 收入）按顶级分类聚合，降序。
class CategoryRankingTool implements AiQueryTool {
  const CategoryRankingTool();

  @override
  String get name => 'categoryRanking';

  @override
  String get description => '按分类统计某时间段某类型（支出/收入）的金额排行与占比。';

  @override
  Map<String, String> get argsSchema => <String, String>{
    'type': "expense 或 income，默认 expense",
    'range': rangePresetsHelp,
    'limit': "取前 N 名，缺省取全部",
  };

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final type = _type(args);
    final window = _window(args, ctx.now, fallback: monthWindowFor(ctx.now));
    final limit = _int(args, 'limit');
    var stats = reportCategoryStats(
      _inWindow(ctx.entries, window),
      ctx.categories,
      type,
    );
    if (limit != null && limit > 0 && stats.length > limit) {
      stats = stats.sublist(0, limit);
    }
    final rangeLabel = _rangeLabel(window);
    final typeLabel = _typeLabel(type);
    final detail = stats
        .map(
          (s) =>
              '${s.category.label} ${s.amount.toStringAsFixed(2)}（${(s.percent * 100).toStringAsFixed(1)}%，${s.count}笔）',
        )
        .join('；');
    final summaryText = stats.isEmpty
        ? '$rangeLabel 没有$typeLabel记录。'
        : '$rangeLabel $typeLabel分类排行：$detail';
    return AiToolResult(
      summary: summaryText,
      display: AiRankingDisplay(
        title: '$rangeLabel · $typeLabel分类排行',
        rows: stats
            .map(
              (s) => AiRankingRow(
                label: s.category.label,
                amount: s.amount,
                percent: s.percent,
                count: s.count,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 标签排行：某时间窗、某类型按标签聚合（一笔计入其每个标签），降序。
class TagRankingTool implements AiQueryTool {
  const TagRankingTool();

  @override
  String get name => 'tagRanking';

  @override
  String get description => '按标签统计某时间段某类型（支出/收入）的金额排行与占比（一笔计入其每个标签）。';

  @override
  Map<String, String> get argsSchema => <String, String>{
    'type': "expense 或 income，默认 expense",
    'range': rangePresetsHelp,
    'limit': "取前 N 名，缺省取全部",
  };

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final type = _type(args);
    final window = _window(args, ctx.now, fallback: monthWindowFor(ctx.now));
    final limit = _int(args, 'limit');
    var stats = reportTagStats(_inWindow(ctx.entries, window), ctx.tags, type);
    if (limit != null && limit > 0 && stats.length > limit) {
      stats = stats.sublist(0, limit);
    }
    final rangeLabel = _rangeLabel(window);
    final typeLabel = _typeLabel(type);
    final detail = stats
        .map(
          (s) =>
              '${s.tag.label} ${s.amount.toStringAsFixed(2)}（${(s.percent * 100).toStringAsFixed(1)}%，${s.count}笔）',
        )
        .join('；');
    final summaryText = stats.isEmpty
        ? '$rangeLabel 没有带标签的$typeLabel记录。'
        : '$rangeLabel $typeLabel标签排行：$detail';
    return AiToolResult(
      summary: summaryText,
      display: AiRankingDisplay(
        title: '$rangeLabel · $typeLabel标签排行',
        rows: stats
            .map(
              (s) => AiRankingRow(
                label: s.tag.label,
                amount: s.amount,
                percent: s.percent,
                count: s.count,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 交易筛选：按类型 / 时间 / 金额区间 / 关键词等条件查具体交易，返回可点击列表。
class QueryTransactionsTool implements AiQueryTool {
  const QueryTransactionsTool();

  @override
  String get name => 'queryTransactions';

  @override
  String get description => '按条件筛选具体交易并列出（可点击查看）。用于「最近某类花费」「含某关键词的交易」等。';

  @override
  Map<String, String> get argsSchema => <String, String>{
    'type': "expense/income/transfer，缺省不限",
    'range': rangePresetsHelp,
    'minAmount': "净额下限",
    'maxAmount': "净额上限",
    'keyword': "备注关键词（模糊匹配）",
    'sortBy': "date 或 amount，默认 date",
    'limit': "最多返回条数，默认 20",
  };

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final window = _window(args, ctx.now, fallback: null);
    final typeStr = _str(args, 'type');
    final types = <EntryType>{
      if (typeStr == 'expense') EntryType.expense,
      if (typeStr == 'income') EntryType.income,
      if (typeStr == 'transfer') EntryType.transfer,
    };
    final sortBy = _str(args, 'sortBy') == 'amount'
        ? LedgerSortField.amount
        : LedgerSortField.date;
    final limit = _int(args, 'limit') ?? 20;
    final results = queryLedgerEntries(
      ctx.entries,
      LedgerQuery(
        types: types,
        window: window,
        minAmount: _num(args, 'minAmount'),
        maxAmount: _num(args, 'maxAmount'),
        keyword: _str(args, 'keyword') ?? '',
        sortBy: sortBy,
        limit: limit.clamp(1, 100),
      ),
    );
    final detail = results
        .take(10)
        .map(
          (e) =>
              '${e.occurredAt.year}-${e.occurredAt.month}-${e.occurredAt.day} '
              '${_typeLabel(e.type)} ${e.netAmount.toStringAsFixed(2)}'
              '${e.note.isEmpty ? '' : '（${e.note}）'}',
        )
        .join('；');
    final more = results.length > 10 ? ' …' : '';
    final summaryText = results.isEmpty
        ? '没有符合条件的交易。'
        : '找到 ${results.length} 笔交易：$detail$more';
    return AiToolResult(
      summary: summaryText,
      display: AiTransactionsDisplay(
        title: '交易明细（${results.length} 笔）',
        entryIds: results.map((e) => e.id).toList(),
      ),
    );
  }
}

/// 极值：某时间窗某类型的最大 / 最小若干笔单笔交易。
class LargestTransactionsTool implements AiQueryTool {
  const LargestTransactionsTool();

  @override
  String get name => 'largestTransactions';

  @override
  String get description => '找出某时间段某类型（支出/收入）金额最大（或最小）的若干笔单笔交易。';

  @override
  Map<String, String> get argsSchema => <String, String>{
    'type': "expense 或 income，默认 expense",
    'range': rangePresetsHelp,
    'limit': "取前 N 笔，默认 5",
    'ascending': "true 则取最小的若干笔，默认 false（最大）",
  };

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final type = _type(args);
    final window = _window(args, ctx.now, fallback: null);
    final limit = (_int(args, 'limit') ?? 5).clamp(1, 50);
    final ascending = args['ascending'] == true;
    final results = queryLedgerEntries(
      ctx.entries,
      LedgerQuery(
        types: <EntryType>{type},
        window: window,
        sortBy: LedgerSortField.amount,
        descending: !ascending,
        limit: limit,
      ),
    );
    final rangeLabel = _rangeLabel(window);
    final typeLabel = _typeLabel(type);
    final extreme = ascending ? '最小' : '最大';
    final detail = results
        .map(
          (e) =>
              '${e.netAmount.toStringAsFixed(2)}'
              '${e.note.isEmpty ? '' : '（${e.note}）'}',
        )
        .join('；');
    final summaryText = results.isEmpty
        ? '$rangeLabel 没有$typeLabel记录。'
        : '$rangeLabel $extreme的 ${results.length} 笔$typeLabel：$detail';
    return AiToolResult(
      summary: summaryText,
      display: AiTransactionsDisplay(
        title: '$rangeLabel · $extreme$typeLabel Top ${results.length}',
        entryIds: results.map((e) => e.id).toList(),
      ),
    );
  }
}
