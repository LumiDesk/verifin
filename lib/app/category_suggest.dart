import 'dart:math' as math;

import 'models.dart';

/// 记账自动识别：从用户**自己的历史交易**里推断当前这笔的「类型 + 分类 + 标签 +
/// 备注」，而不只是分类。纯函数、不依赖 BuildContext，便于单测。
///
/// 思路是「找最像的历史」：对每笔历史按与当前输入的相关度打分——
/// - 备注字符二元组相似度（用户填了备注时的主信号）；
/// - 金额接近度（越接近越相关，精确相同最强，是「我又输入 2.8」这类场景的关键）；
/// - 时段接近度（弱先验）。
///
/// 取相关度达标的历史集合，按相关度加权投票出主导类型与分类，并从相关度最高的那笔
/// （样本）带出标签与备注。无把握则各字段留空——宁可不猜。
class EntrySuggestion {
  const EntrySuggestion({this.type, this.categoryId, this.tagIds, this.note});

  /// 推断的交易类型；拿不准为 null。
  final EntryType? type;

  /// 推断的分类 id（已按 [type] 校验到对应清单）；拿不准为 null。
  final String? categoryId;

  /// 带出的标签 id 列表；无则为 null。
  final List<String>? tagIds;

  /// 带出的备注；无则为 null。
  final String? note;

  bool get isEmpty =>
      type == null &&
      categoryId == null &&
      (tagIds == null || tagIds!.isEmpty) &&
      (note == null || note!.isEmpty);

  static const EntrySuggestion empty = EntrySuggestion();
}

/// 备注相似度权重（主信号）。
const double _kNoteWeight = 3.0;

/// 金额接近度权重。
const double _kAmountWeight = 2.0;

/// 时段接近度权重（弱）。
const double _kHourWeight = 0.4;

/// 金额相对差在此带宽内才算「接近」（0.3 = ±30%）。
const double _kAmountBand = 0.3;

/// 一笔历史被视为「相关」的最低相关度。
const double _kRelevanceFloor = 0.6;

/// 判定「金额几乎精确相同」的接近度阈值（≥ 即视为精确复现）。
const double _kExactAffinity = 0.9;

/// 主导类型须占的相关度比重。
const double _kTypeShare = 0.6;

/// 主导分类须占（其类型内）的相关度比重。
const double _kCategoryShare = 0.5;

/// 只回看最近这么多笔历史，兼顾性能与近期习惯。
const int _kMaxHistory = 500;

class _Scored {
  const _Scored(this.entry, this.relevance, this.strong);
  final LedgerEntry entry;
  final double relevance;

  /// 是否为「强」支撑：金额几乎精确复现，或备注确有重合。松散的纯金额接近不算强，
  /// 单笔松散匹配不足以翻转类型。
  final bool strong;
}

/// 从 [history]（应由调用方过滤为当前账本、含各类型）推断当前这笔。
///
/// [expenseCategoryIds]/[incomeCategoryIds] 用于把推断出的分类校验到对应类型的清单；
/// [note]/[amount]/[hour] 为当前正在录入的备注、金额与小时（0–23）。
EntrySuggestion suggestEntry({
  required List<LedgerEntry> history,
  required Set<String> expenseCategoryIds,
  required Set<String> incomeCategoryIds,
  required String note,
  required double amount,
  required int hour,
  EntryType? forcedType,
}) {
  final noteTokens = _tokenize(note);

  // 只保留「金额或备注真的沾边」的历史，时段仅作微弱加权。
  // forcedType 非空时（用户已手动选定类型）只看该类型的历史，不再翻转类型。
  final relevant = <_Scored>[];
  var scanned = 0;
  for (final entry in history) {
    if (scanned >= _kMaxHistory) {
      break;
    }
    scanned++;
    if (forcedType != null && entry.type != forcedType) {
      continue;
    }
    final noteSim = noteTokens.isEmpty
        ? 0.0
        : _similarity(noteTokens, _tokenize(entry.note));
    final amountAffinity = _amountAffinity(amount, entry.amount);
    if (noteSim <= 0 && amountAffinity <= 0) {
      continue;
    }
    final hourAffinity =
        1 - _circularHourDistance(hour, entry.occurredAt.hour) / 12;
    final relevance =
        _kNoteWeight * noteSim +
        _kAmountWeight * amountAffinity +
        _kHourWeight * hourAffinity;
    if (relevance >= _kRelevanceFloor) {
      final strong = amountAffinity >= _kExactAffinity || noteSim > 0;
      relevant.add(_Scored(entry, relevance, strong));
    }
  }
  if (relevant.isEmpty) {
    return EntrySuggestion.empty;
  }

  // 加权投票选主导类型。
  final typeWeight = <EntryType, double>{};
  final typeCount = <EntryType, int>{};
  final typeStrong = <EntryType, bool>{};
  var total = 0.0;
  for (final scored in relevant) {
    final t = scored.entry.type;
    typeWeight[t] = (typeWeight[t] ?? 0) + scored.relevance;
    typeCount[t] = (typeCount[t] ?? 0) + 1;
    if (scored.strong) {
      typeStrong[t] = true;
    }
    total += scored.relevance;
  }
  final EntryType type;
  if (forcedType != null) {
    type = forcedType;
  } else {
    final dominant = typeWeight.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    // 需占比达标；单笔支撑时要求是「强」匹配（精确金额或备注重合）才敢定类型，
    // 避免仅凭松散金额接近就误翻类型。
    final enoughSupport =
        (typeCount[dominant.key] ?? 0) >= 2 ||
        (typeStrong[dominant.key] ?? false);
    if (dominant.value / total < _kTypeShare || !enoughSupport) {
      return EntrySuggestion.empty;
    }
    type = dominant.key;
  }

  // 主导类型内：加权选分类，并取相关度最高的样本带出标签/备注。
  final ofType = relevant.where((s) => s.entry.type == type).toList()
    ..sort((a, b) => b.relevance.compareTo(a.relevance));
  final candidateIds = switch (type) {
    EntryType.income => incomeCategoryIds,
    EntryType.expense => expenseCategoryIds,
    EntryType.transfer => const <String>{},
    // 退款条目不作记账自动识别的候选（其分类沿用原支出）。
    EntryType.refund => const <String>{},
  };

  final catWeight = <String, double>{};
  var typeTotal = 0.0;
  for (final scored in ofType) {
    typeTotal += scored.relevance;
    final id = scored.entry.categoryId;
    if (id.isNotEmpty && candidateIds.contains(id)) {
      catWeight[id] = (catWeight[id] ?? 0) + scored.relevance;
    }
  }
  String? categoryId;
  if (catWeight.isNotEmpty && typeTotal > 0) {
    final domCat = catWeight.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    if (domCat.value / typeTotal >= _kCategoryShare) {
      categoryId = domCat.key;
    }
  }

  final exemplar = ofType.first.entry;
  final exemplarNote = exemplar.note.trim();
  return EntrySuggestion(
    type: type,
    categoryId: categoryId,
    tagIds: exemplar.tagIds.isEmpty ? null : List<String>.of(exemplar.tagIds),
    note: exemplarNote.isEmpty ? null : exemplarNote,
  );
}

/// 金额接近度（0–1）：相对差在 [_kAmountBand] 内线性衰减，精确相同为 1，超出为 0。
double _amountAffinity(double a, double b) {
  if (a <= 0 || b <= 0) {
    return 0;
  }
  final rel = (a - b).abs() / math.max(a, b);
  if (rel >= _kAmountBand) {
    return 0;
  }
  return 1 - rel / _kAmountBand;
}

/// 归一化并切成字符二元组（token）集合；不足两字时退化为单字集合。
/// 中文无空格分词，字符二元组对「买菜/打车/咖啡」这类短备注已足够稳。
Set<String> _tokenize(String raw) {
  final cleaned = raw
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '');
  if (cleaned.isEmpty) {
    return <String>{};
  }
  final chars = cleaned.split('');
  if (chars.length < 2) {
    return <String>{cleaned};
  }
  final grams = <String>{};
  for (var i = 0; i < chars.length - 1; i++) {
    grams.add('${chars[i]}${chars[i + 1]}');
  }
  return grams;
}

/// 两个 token 集合的 Jaccard 相似度（0–1）。
double _similarity(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  var inter = 0;
  for (final t in a) {
    if (b.contains(t)) {
      inter++;
    }
  }
  final union = a.length + b.length - inter;
  return union == 0 ? 0 : inter / union;
}

/// 24 小时环上两个小时的最短距离（0–12）。
int _circularHourDistance(int a, int b) {
  final diff = (a - b).abs() % 24;
  return math.min(diff, 24 - diff);
}
