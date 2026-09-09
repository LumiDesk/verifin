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
import '../credit_card.dart';
import '../currency_math.dart';
import '../ledger_math.dart';
import '../report_analysis.dart';
import 'ai_tool_schema.dart';
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
    required this.baseCurrencyCode,
    required this.now,
    this.exchangeRates = const <ExchangeRate>[],
    this.bookId = '',
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

  /// 统计、筛选与工具回传金额使用的当前账本本位币。
  final String baseCurrencyCode;

  /// 当前账本本地汇率快照；只用于转账等非收支记录的只读本位币比较。
  final List<ExchangeRate> exchangeRates;

  /// 当前账本 id：汇率按账本隔离，折算账户余额时需要它定位汇率记录。
  final String bookId;

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
  const AiQueryTool();

  /// 工具名（模型用它指定调用，全局唯一，小驼峰）。
  String get name;

  /// 给模型看的说明：这个工具查什么、何时用。
  String get description;

  /// 参数定义的单一真源，同时生成原生 JSON Schema 与兼容协议提示词。
  AiToolSchema get schema;

  /// OpenAI-compatible `tools` 中的一项函数定义。
  Map<String, Object?> toNativeDefinition() => <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': name,
      'description': description,
      'parameters': schema.toJsonSchema(),
    },
  };

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
  const TrendTool(),
  const CompareTool(),
  const AccountsOverviewTool(),
  const NetWorthTool(),
  const CreditCardBillTool(),
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

/// 合法的相对时间窗预设（供强类型 schema 展示给模型）。
const String rangePresetsHelp =
    "range 预设：thisMonth/lastMonth/thisYear/lastYear/last7Days/last30Days/"
    "last3Months/last6Months/last12Months/all；或用 start+end（YYYY-MM-DD）指定。";

const List<Object> _rangePresets = <Object>[
  'thisMonth',
  'lastMonth',
  'thisYear',
  'lastYear',
  'last7Days',
  'last30Days',
  'last3Months',
  'last6Months',
  'last12Months',
  'all',
];

const Map<String, AiToolParameter> _rangeParameters = <String, AiToolParameter>{
  'range': AiToolParameter(
    type: AiToolParameterType.string,
    description: rangePresetsHelp,
    enumValues: _rangePresets,
  ),
  'start': AiToolParameter(
    type: AiToolParameterType.string,
    description: '自定义开始日期，格式 YYYY-MM-DD；需与 end 同时提供。',
  ),
  'end': AiToolParameter(
    type: AiToolParameterType.string,
    description: '自定义结束日期，格式 YYYY-MM-DD；需与 start 同时提供。',
  ),
};

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
      return DateWindow(start: addCalendarDays(dateOnly(now), -6), end: now);
    case 'last30Days':
      return DateWindow(start: addCalendarDays(dateOnly(now), -29), end: now);
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

String _baseMoney(AiToolContext context, num value) =>
    formatMoney(value, context.baseCurrencyCode);

// ─────────────────────────── 工具实现 ───────────────────────────

/// 收支汇总：某时间窗内的收入 / 支出 / 净额与笔数。
class SummaryTool extends AiQueryTool {
  const SummaryTool();

  @override
  String get name => 'summary';

  @override
  String get description => '统计某时间段内的总收入、总支出、净额与笔数。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{..._rangeParameters},
  );

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final window = _window(args, ctx.now, fallback: monthWindowFor(ctx.now));
    final summary = reportSummary(_inWindow(ctx.entries, window));
    final rangeLabel = _rangeLabel(window);
    return AiToolResult(
      summary:
          '$rangeLabel 收入 ${_baseMoney(ctx, summary.income)}（${summary.incomeCount} 笔），'
          '支出 ${_baseMoney(ctx, summary.expense)}（${summary.expenseCount} 笔），'
          '净额 ${_baseMoney(ctx, summary.net)}。',
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
class CategoryRankingTool extends AiQueryTool {
  const CategoryRankingTool();

  @override
  String get name => 'categoryRanking';

  @override
  String get description => '按分类统计某时间段某类型（支出/收入）的金额排行与占比。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'type': AiToolParameter(
        type: AiToolParameterType.string,
        description: '交易类型，默认 expense。',
        enumValues: <Object>['expense', 'income'],
      ),
      ..._rangeParameters,
      'limit': AiToolParameter(
        type: AiToolParameterType.integer,
        description: '取前 N 名，缺省取全部。',
        minimum: 1,
      ),
    },
  );

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
              '${s.category.label} ${_baseMoney(ctx, s.amount)}（${(s.percent * 100).toStringAsFixed(1)}%，${s.count}笔）',
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
class TagRankingTool extends AiQueryTool {
  const TagRankingTool();

  @override
  String get name => 'tagRanking';

  @override
  String get description => '按标签统计某时间段某类型（支出/收入）的金额排行与占比（一笔计入其每个标签）。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'type': AiToolParameter(
        type: AiToolParameterType.string,
        description: '交易类型，默认 expense。',
        enumValues: <Object>['expense', 'income'],
      ),
      ..._rangeParameters,
      'limit': AiToolParameter(
        type: AiToolParameterType.integer,
        description: '取前 N 名，缺省取全部。',
        minimum: 1,
      ),
    },
  );

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
              '${s.tag.label} ${_baseMoney(ctx, s.amount)}（${(s.percent * 100).toStringAsFixed(1)}%，${s.count}笔）',
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
class QueryTransactionsTool extends AiQueryTool {
  const QueryTransactionsTool();

  @override
  String get name => 'queryTransactions';

  @override
  String get description => '按条件筛选具体交易并列出（可点击查看）。用于「最近某类花费」「含某关键词的交易」等。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'type': AiToolParameter(
        type: AiToolParameterType.string,
        description: '交易类型，缺省不限。',
        enumValues: <Object>['expense', 'income', 'transfer'],
      ),
      ..._rangeParameters,
      'minAmount': AiToolParameter(
        type: AiToolParameterType.number,
        description: '净额下限。',
      ),
      'maxAmount': AiToolParameter(
        type: AiToolParameterType.number,
        description: '净额上限。',
      ),
      'keyword': AiToolParameter(
        type: AiToolParameterType.string,
        description: '备注关键词，使用模糊匹配。',
      ),
      'sortBy': AiToolParameter(
        type: AiToolParameterType.string,
        description: '排序字段，默认 date。',
        enumValues: <Object>['date', 'amount'],
      ),
      'limit': AiToolParameter(
        type: AiToolParameterType.integer,
        description: '最多返回条数，默认 20。',
        minimum: 1,
        maximum: 100,
      ),
    },
  );

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
      amountOf: (entry) => comparableEntryAmountInBase(
        entry: entry,
        accounts: ctx.accounts,
        baseCurrencyCode: ctx.baseCurrencyCode,
        rates: ctx.exchangeRates,
      ),
    );
    String amountSummary(LedgerEntry entry) {
      if (entry.type != EntryType.transfer) {
        return _baseMoney(ctx, entry.netBaseAmount);
      }
      final from = ctx.accounts
          .where((account) => account.id == entry.accountId)
          .firstOrNull;
      final to = ctx.accounts
          .where((account) => account.id == entry.toAccountId)
          .firstOrNull;
      final fromCode = from?.currencyCode ?? entry.currencyCode;
      final fromAmount = entry.accountAmount ?? entry.amount;
      final fromText = formatMoney(fromAmount, fromCode);
      if (to == null || entry.toAccountAmount == null) {
        return fromText;
      }
      return '$fromText → ${formatMoney(entry.toAccountAmount!, to.currencyCode)}';
    }

    final detail = results
        .take(10)
        .map(
          (e) =>
              '${e.occurredAt.year}-${e.occurredAt.month}-${e.occurredAt.day} '
              '${_typeLabel(e.type)} ${amountSummary(e)}'
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
class LargestTransactionsTool extends AiQueryTool {
  const LargestTransactionsTool();

  @override
  String get name => 'largestTransactions';

  @override
  String get description => '找出某时间段某类型（支出/收入）金额最大（或最小）的若干笔单笔交易。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'type': AiToolParameter(
        type: AiToolParameterType.string,
        description: '交易类型，默认 expense。',
        enumValues: <Object>['expense', 'income'],
      ),
      ..._rangeParameters,
      'limit': AiToolParameter(
        type: AiToolParameterType.integer,
        description: '取前 N 笔，默认 5。',
        minimum: 1,
        maximum: 50,
      ),
      'ascending': AiToolParameter(
        type: AiToolParameterType.boolean,
        description: 'true 表示取最小的若干笔，默认 false（最大）。',
      ),
    },
  );

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
              '${_baseMoney(ctx, e.netBaseAmount)}'
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

/// 收支趋势：某时间窗内某类型的序列（短范围按天、长范围按月）。
class TrendTool extends AiQueryTool {
  const TrendTool();

  @override
  String get name => 'trend';

  @override
  String get description => '某时间段内收入或支出的趋势序列，短范围按天、长范围按月。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'type': AiToolParameter(
        type: AiToolParameterType.string,
        description: '交易类型，默认 expense。',
        enumValues: <Object>['expense', 'income'],
      ),
      ..._rangeParameters,
    },
  );

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final window = _window(args, ctx.now, fallback: monthWindowFor(ctx.now));
    final type = _type(args);
    // 「全部时间」用最早一笔交易到今天的区间，而不是当年。
    final range = window != null
        ? ReportRange.custom(window.start, window.end)
        : ReportRange.custom(
            ctx.entries.isEmpty
                ? ctx.now
                : ctx.entries
                      .map((entry) => entry.occurredAt)
                      .reduce((a, b) => a.isBefore(b) ? a : b),
            ctx.now,
          );
    final trend = reportTrend(ctx.entries, range, type);
    final rangeLabel = _rangeLabel(window);
    final typeLabel = _typeLabel(type);
    final granularity = trend.granularity == ReportTrendGranularity.monthly
        ? '按月'
        : '按天';
    final total = trend.values.fold<double>(0, (sum, value) => sum + value);
    return AiToolResult(
      summary: trend.points.isEmpty
          ? '$rangeLabel 没有$typeLabel记录。'
          : '$rangeLabel $typeLabel趋势（$granularity，${trend.points.length} 个点，'
                '合计 ${_baseMoney(ctx, total)}）：'
                '${trend.points.map((p) => '${p.label}=${_baseMoney(ctx, p.value)}').join('，')}',
      display: trend.points.isEmpty
          ? null
          : AiTrendDisplay(
              title: '$rangeLabel · $typeLabel趋势',
              values: trend.values,
              labels: trend.points.map((point) => point.label).toList(),
              isExpense: type == EntryType.expense,
            ),
    );
  }
}

/// 环比 / 同比：指定月份与上月、去年同月的收支对比。
class CompareTool extends AiQueryTool {
  const CompareTool();

  @override
  String get name => 'compare';

  @override
  String get description => '指定月份与上月、去年同月的收入与支出环比 / 同比对比。';

  @override
  AiToolSchema get schema => const AiToolSchema(
    properties: <String, AiToolParameter>{
      'month': AiToolParameter(
        type: AiToolParameterType.string,
        description: '要对比的月份，格式 YYYY-MM；缺省为当前月。',
      ),
    },
  );

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final raw = _str(args, 'month');
    final parsed = raw == null ? null : DateTime.tryParse('$raw-01');
    final month = parsed ?? DateTime(ctx.now.year, ctx.now.month);
    final comparison = reportMonthlyComparison(ctx.entries, month);
    String delta(double current, double previous) {
      if (isZeroAmount(previous)) {
        return isZeroAmount(current) ? '持平' : '基期为 0，无法计算比例';
      }
      final percent = (current - previous) / previous * 100;
      return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%';
    }

    final current = comparison.current;
    final previous = comparison.previousMonth;
    final lastYear = comparison.sameMonthLastYear;
    final label = '${month.year} 年 ${month.month} 月';
    return AiToolResult(
      summary:
          '$label 支出 ${_baseMoney(ctx, current.expense)}'
          '（环比 ${delta(current.expense, previous.expense)}，'
          '同比 ${delta(current.expense, lastYear.expense)}）；'
          '收入 ${_baseMoney(ctx, current.income)}'
          '（环比 ${delta(current.income, previous.income)}，'
          '同比 ${delta(current.income, lastYear.income)}）。',
      display: AiStatDisplay(
        title: '$label · 环比与同比',
        items: <AiStatItem>[
          AiStatItem(label: '本月支出', value: current.expense),
          AiStatItem(label: '上月支出', value: previous.expense),
          AiStatItem(label: '去年同月支出', value: lastYear.expense),
          AiStatItem(label: '本月收入', value: current.income),
          AiStatItem(label: '上月收入', value: previous.income),
          AiStatItem(label: '去年同月收入', value: lastYear.income),
        ],
      ),
    );
  }
}

/// 账户一览：各账户名称、币种与余额；总资产缺汇率时明确说明。
class AccountsOverviewTool extends AiQueryTool {
  const AccountsOverviewTool();

  @override
  String get name => 'accountsOverview';

  @override
  String get description => '当前账本各账户的名称、币种与余额一览（不含隐藏账户）。';

  @override
  AiToolSchema get schema => const AiToolSchema();

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final accounts = ctx.accounts
        .where((account) => !account.hidden)
        .toList(growable: false);
    if (accounts.isEmpty) {
      return const AiToolResult(summary: '当前账本还没有账户。');
    }
    final total = convertAccountBalancesToBase(
      accounts: accounts.where((account) => account.includeInAssets),
      balanceOf: ctx.balanceOf,
      bookId: ctx.bookId,
      baseCurrencyCode: ctx.baseCurrencyCode,
      date: ctx.now,
      rates: ctx.exchangeRates,
    );
    final totalText = total.isComplete
        ? '计入资产的账户合计 ${_baseMoney(ctx, total.completeTotal ?? 0)}'
        : '合计因缺汇率无法给出（缺 ${total.missingCurrencyCodes.join('、')}）';
    return AiToolResult(
      summary:
          '共 ${accounts.length} 个账户：'
          '${accounts.map((account) => '${account.name} '
              '${formatCurrencyNumber(ctx.balanceOf(account), account.currencyCode)} '
              '${account.currencyCode}').join('；')}。$totalText。',
      display: AiTableDisplay(
        title: '账户余额',
        headers: const <String>['账户', '币种', '余额'],
        rows: accounts
            .map(
              (account) => <String>[
                account.name,
                account.currencyCode,
                formatCurrencyNumber(
                  ctx.balanceOf(account),
                  account.currencyCode,
                ),
              ],
            )
            .toList(),
      ),
    );
  }
}

/// 净资产：总资产 / 总负债 / 净资产（本位币口径）。
class NetWorthTool extends AiQueryTool {
  const NetWorthTool();

  @override
  String get name => 'netWorth';

  @override
  String get description => '总资产、总负债与净资产（本位币口径；缺汇率时不给部分和）。';

  @override
  AiToolSchema get schema => const AiToolSchema();

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final valued = ctx.accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .toList(growable: false);
    final converted = convertAccountBalancesToBase(
      accounts: valued,
      balanceOf: ctx.balanceOf,
      bookId: ctx.bookId,
      baseCurrencyCode: ctx.baseCurrencyCode,
      date: ctx.now,
      rates: ctx.exchangeRates,
    );
    if (!converted.isComplete) {
      return AiToolResult(
        summary:
            '有账户缺少汇率（${converted.missingCurrencyCodes.join('、')}），'
            '无法给出总资产与净资产；请先在「货币与汇率」补齐。',
      );
    }
    var assets = 0.0;
    var liabilities = 0.0;
    for (final account in valued) {
      final amount = converted.amountsByAccountId[account.id] ?? 0;
      if (amount > 0) {
        assets += amount;
      } else {
        liabilities += -amount;
      }
    }
    final net = assets - liabilities;
    return AiToolResult(
      summary:
          '总资产 ${_baseMoney(ctx, assets)}，'
          '总负债 ${_baseMoney(ctx, liabilities)}，'
          '净资产 ${_baseMoney(ctx, net)}。',
      display: AiStatDisplay(
        title: '净资产',
        items: <AiStatItem>[
          AiStatItem(label: '总资产', value: assets),
          AiStatItem(label: '总负债', value: liabilities),
          AiStatItem(label: '净资产', value: net, emphasize: true),
        ],
      ),
    );
  }
}

/// 信用卡 / 信用账户：当前欠款、可用额度与本期账单。
class CreditCardBillTool extends AiQueryTool {
  const CreditCardBillTool();

  @override
  String get name => 'creditCardBill';

  @override
  String get description => '信用类账户的当前欠款、可用额度、本期账单与还款日倒计时。';

  @override
  AiToolSchema get schema => const AiToolSchema();

  @override
  AiToolResult run(AiToolContext ctx, Map<String, Object?> args) {
    final cards = ctx.accounts
        .where((account) => account.type.supportsCredit && !account.hidden)
        .toList(growable: false);
    if (cards.isEmpty) {
      return const AiToolResult(summary: '当前账本没有信用类账户。');
    }
    final rows = <List<String>>[];
    final parts = <String>[];
    for (final card in cards) {
      final balance = ctx.balanceOf(card);
      final used = usedCredit(balance);
      final available = availableCredit(card.creditLimit, balance);
      final cycle = card.statementDay == null
          ? null
          : currentBillingCycle(card.statementDay!, ctx.now);
      final bill = cycle == null
          ? null
          : billingCycleExpense(ctx.entries, card.id, cycle);
      rows.add(<String>[
        card.name,
        formatCurrencyNumber(used, card.currencyCode),
        available == null
            ? '—'
            : formatCurrencyNumber(available, card.currencyCode),
        bill == null ? '—' : formatCurrencyNumber(bill, card.currencyCode),
      ]);
      parts.add(
        '${card.name} 当前欠款 ${formatCurrencyNumber(used, card.currencyCode)} ${card.currencyCode}'
        '${available == null ? '' : '，可用额度 ${formatCurrencyNumber(available, card.currencyCode)}'}'
        '${bill == null ? '' : '，本期账单 ${formatCurrencyNumber(bill, card.currencyCode)}'}'
        '${card.dueDay == null ? '' : '，${card.dueDay} 号还款（还有 ${daysUntilDue(card.dueDay!, ctx.now)} 天）'}',
      );
    }
    return AiToolResult(
      summary: parts.join('；'),
      display: AiTableDisplay(
        title: '信用卡 / 信用账户',
        headers: const <String>['账户', '当前欠款', '可用额度', '本期账单'],
        rows: rows,
      ),
    );
  }
}
