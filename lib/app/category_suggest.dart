import 'dart:math' as math;

import 'models.dart';

/// 记账自动分类：从用户**自己的历史交易**里推断当前这笔最可能的分类。
///
/// 纯函数、不依赖 BuildContext，便于单测。综合三种信号（权重从高到低）：
/// 1. 备注关键词相似度——与历史同类交易备注的字符二元组 Jaccard 相似度（用户「填了
///    备注就自动识别」的主信号）；
/// 2. 时段习惯——该分类的历史交易有多少落在当前小时附近（「平时这个点记什么」）；
/// 3. 金额习惯——该分类历史金额与当前金额的接近程度（「这个金额可能是什么」）。
///
/// 仅在最高分超过阈值、且明显领先次高分时才给出建议，否则返回 null（宁可不猜）。

/// 备注相似度权重（主信号，远高于习惯项）。
const double _kNoteWeight = 3.0;

/// 时段习惯权重。
const double _kHourWeight = 1.0;

/// 金额习惯权重。
const double _kAmountWeight = 1.0;

/// 频次先验权重（常用分类略微更可能）。
const double _kFreqWeight = 0.6;

/// 采纳建议的最低总分。
const double _kMinScore = 0.6;

/// 建议须领先次高分的最小差值，避免在势均力敌时乱猜。
const double _kMargin = 0.2;

/// 只回看最近这么多笔历史，兼顾性能与近期习惯。
const int _kMaxHistory = 500;

/// 从 [history]（应由调用方过滤为「同账本、同类型」）推断当前这笔的分类 id。
///
/// [candidateIds] 为当前类型下可选分类 id；[note]/[amount]/[hour] 为当前正在录入的
/// 备注、金额与小时（0–23）。无把握时返回 null。
String? suggestCategoryId({
  required List<LedgerEntry> history,
  required Set<String> candidateIds,
  required String note,
  required double amount,
  required int hour,
}) {
  if (candidateIds.isEmpty) {
    return null;
  }
  final noteTokens = _tokenize(note);

  // 按分类聚合历史信号。
  final counts = <String, int>{};
  final noteBest = <String, double>{}; // 与当前备注的最高相似度
  final hourHits = <String, int>{}; // 落在当前小时附近的笔数
  final amountHits = <String, int>{}; // 金额接近当前值的笔数

  var scanned = 0;
  for (final entry in history) {
    if (!candidateIds.contains(entry.categoryId)) {
      continue;
    }
    if (scanned >= _kMaxHistory) {
      break;
    }
    scanned++;
    final id = entry.categoryId;
    counts[id] = (counts[id] ?? 0) + 1;

    if (noteTokens.isNotEmpty) {
      final sim = _similarity(noteTokens, _tokenize(entry.note));
      if (sim > (noteBest[id] ?? 0)) {
        noteBest[id] = sim;
      }
    }
    if (_circularHourDistance(hour, entry.occurredAt.hour) <= 2) {
      hourHits[id] = (hourHits[id] ?? 0) + 1;
    }
    if (amount > 0 && entry.amount > 0) {
      final rel =
          (amount - entry.amount).abs() / math.max(amount, entry.amount);
      if (rel <= 0.3) {
        amountHits[id] = (amountHits[id] ?? 0) + 1;
      }
    }
  }

  if (counts.isEmpty) {
    return null;
  }
  final maxCount = counts.values.reduce(math.max);

  // 逐分类打分。
  String? bestId;
  var bestScore = 0.0;
  var secondScore = 0.0;
  counts.forEach((id, count) {
    final freq = maxCount == 0 ? 0.0 : count / maxCount;
    final hour = count == 0 ? 0.0 : (hourHits[id] ?? 0) / count;
    final amountAffinity = count == 0 ? 0.0 : (amountHits[id] ?? 0) / count;
    final score =
        _kNoteWeight * (noteBest[id] ?? 0) +
        _kHourWeight * hour +
        _kAmountWeight * amountAffinity +
        _kFreqWeight * freq;
    if (score > bestScore) {
      secondScore = bestScore;
      bestScore = score;
      bestId = id;
    } else if (score > secondScore) {
      secondScore = score;
    }
  });

  if (bestId == null ||
      bestScore < _kMinScore ||
      bestScore - secondScore < _kMargin) {
    return null;
  }
  return bestId;
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
