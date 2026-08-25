// 通用交易筛选纯函数。
//
// AI 对话查询里的 `queryTransactions` / `extremes` 等工具都建立在此之上：把「金额区间 /
// 分类 / 账户 / 标签 / 类型 / 时间 / 关键词 + 排序 + Top N」这套筛选逻辑集中成一个可单测的
// 纯函数，工具层只负责把模型给的参数解析成 [LedgerQuery]。无副作用、不依赖 controller。
//
// 金额一律按 [LedgerEntry.netAmount]（支出已扣已到账退款）比较与排序，与统计口径一致。
import '../models.dart';
import '../ledger_math.dart';

/// 排序字段。
enum LedgerSortField {
  /// 按发生时间 [LedgerEntry.occurredAt]。
  date,

  /// 按净额 [LedgerEntry.netAmount]。
  amount,
}

/// 一次交易筛选的条件。所有集合类条件「为空即不限制」，多个条件之间是「与」关系。
class LedgerQuery {
  const LedgerQuery({
    this.types = const <EntryType>{},
    this.window,
    this.minAmount,
    this.maxAmount,
    this.categoryIds = const <String>{},
    this.accountIds = const <String>{},
    this.tagIds = const <String>{},
    this.keyword = '',
    this.sortBy = LedgerSortField.date,
    this.descending = true,
    this.limit,
  });

  /// 交易类型集合；为空表示不限类型。
  final Set<EntryType> types;

  /// 时间窗（闭区间，按自然日）；为 null 表示不限时间。
  final DateWindow? window;

  /// 净额下限（含）；按 [LedgerEntry.netAmount] 比较。
  final double? minAmount;

  /// 净额上限（含）。
  final double? maxAmount;

  /// 分类 id 集合（按交易自身 [LedgerEntry.categoryId] 精确匹配；如需含子分类，
  /// 由调用方先展开后传入）；为空不限。
  final Set<String> categoryIds;

  /// 账户 id 集合（匹配 [LedgerEntry.accountId] 或转账的 [LedgerEntry.toAccountId]）；为空不限。
  final Set<String> accountIds;

  /// 标签 id 集合（交易命中其中任一标签即算匹配）；为空不限。
  final Set<String> tagIds;

  /// 备注关键词（大小写不敏感的子串匹配）；为空不限。
  final String keyword;

  /// 排序字段。
  final LedgerSortField sortBy;

  /// 是否降序（默认 true：最新 / 最大在前）。
  final bool descending;

  /// 结果数量上限（Top N）；为 null 不限。
  final int? limit;
}

/// 按 [query] 筛选并排序交易，返回新列表（不改动入参）。
List<LedgerEntry> queryLedgerEntries(
  Iterable<LedgerEntry> entries,
  LedgerQuery query, {
  double? Function(LedgerEntry entry)? amountOf,
}) {
  final keyword = query.keyword.trim().toLowerCase();
  final result = <LedgerEntry>[];
  for (final entry in entries) {
    if (query.types.isNotEmpty && !query.types.contains(entry.type)) {
      continue;
    }
    if (query.window != null &&
        entriesInWindow(<LedgerEntry>[entry], query.window!).isEmpty) {
      continue;
    }
    final value = amountOf == null ? entry.netAmount : amountOf(entry);
    if (value == null && (query.minAmount != null || query.maxAmount != null)) {
      continue;
    }
    if (query.minAmount != null && value! < query.minAmount!) {
      continue;
    }
    if (query.maxAmount != null && value! > query.maxAmount!) {
      continue;
    }
    if (query.categoryIds.isNotEmpty &&
        !query.categoryIds.contains(entry.categoryId)) {
      continue;
    }
    if (query.accountIds.isNotEmpty &&
        !query.accountIds.contains(entry.accountId) &&
        !(entry.toAccountId != null &&
            query.accountIds.contains(entry.toAccountId))) {
      continue;
    }
    if (query.tagIds.isNotEmpty &&
        !entry.tagIds.any((id) => query.tagIds.contains(id))) {
      continue;
    }
    if (keyword.isNotEmpty && !entry.note.toLowerCase().contains(keyword)) {
      continue;
    }
    result.add(entry);
  }

  result.sort((a, b) {
    final int cmp;
    switch (query.sortBy) {
      case LedgerSortField.date:
        cmp = a.occurredAt.compareTo(b.occurredAt);
      case LedgerSortField.amount:
        final aValue = amountOf == null ? a.netAmount : amountOf(a);
        final bValue = amountOf == null ? b.netAmount : amountOf(b);
        if (aValue == null && bValue != null) return 1;
        if (aValue != null && bValue == null) return -1;
        cmp = aValue == null || bValue == null ? 0 : aValue.compareTo(bValue);
    }
    return query.descending ? -cmp : cmp;
  });

  if (query.limit != null && result.length > query.limit!) {
    return result.sublist(0, query.limit!);
  }
  return result;
}
