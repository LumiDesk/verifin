import 'dart:convert';

import '../models.dart';
import 'ai_client.dart';
import 'ai_settings.dart';

/// 一个可选项（分类或账户），供 AI 从中挑选并回传 id。
class AiOption {
  const AiOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// 喂给 AI 的账本上下文：可选的分类/账户清单、今天日期、当前账本。
/// 由调用方（记账入口）从 controller 组装，保持解析逻辑纯净可测。
class AiEntryContext {
  const AiEntryContext({
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
    required this.today,
    required this.bookId,
  });

  final List<AiOption> expenseCategories;
  final List<AiOption> incomeCategories;
  final List<AiOption> accounts;
  final DateTime today;
  final String bookId;
}

/// 解析降级提示的类型（UI 侧本地化展示）。
enum AiDraftWarning { categoryUnmatched, accountUnmatched }

/// 解析失败的可预期原因（UI 侧本地化展示）。
enum AiEntryError { emptyResult, noAmount }

/// 解析阶段（非网络）失败时抛出，UI 按 [error] 本地化提示。
class AiEntryException implements Exception {
  AiEntryException(this.error);

  final AiEntryError error;

  @override
  String toString() => 'AiEntryException($error)';
}

/// AI 解析出的交易草稿，落账前交给用户在记账页确认/修改。
class AiEntryDraft {
  const AiEntryDraft({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.note,
    required this.occurredAt,
    this.warnings = const <AiDraftWarning>[],
  });

  final EntryType type;
  final double amount;
  final String categoryId;

  /// 空串表示「无账户」。
  final String accountId;
  final String? toAccountId;
  final String note;
  final DateTime occurredAt;

  /// 解析过程中的降级提示（如分类未识别已用默认），供 UI 本地化展示，不阻断落账。
  final List<AiDraftWarning> warnings;
}

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _timeKey(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 构造系统提示词：说明任务、可选清单与严格 JSON 输出格式。
/// 提示词本身非用户可见文案，用中文书写并要求保留用户输入的原语言。
String buildAiEntryPrompt(AiEntryContext context) {
  String optionsBlock(List<AiOption> options) {
    if (options.isEmpty) {
      return '（无）';
    }
    return options.map((o) => '- ${o.id} | ${o.label}').join('\n');
  }

  final accountsBlock = context.accounts.isEmpty
      ? '（无）'
      : context.accounts.map((o) => '- ${o.id} | ${o.label}').join('\n');

  return '''
你是一个记账助手。请把用户用自然语言描述的一笔账，解析成一个 JSON 对象。
现在是 ${_dateKey(context.today)} ${_timeKey(context.today)}（当前日期与时间，用于解析「今天」「昨天」「前天」「上午」「晚上八点」「半小时前」等相对日期或时间）。

只能从下面给定的清单里选择 categoryId 和 accountId，必须原样回传清单中的 id，不要自造 id。

支出分类（categoryId 从这里选）：
${optionsBlock(context.expenseCategories)}

收入分类（categoryId 从这里选）：
${optionsBlock(context.incomeCategories)}

账户（accountId / toAccountId 从这里选）：
$accountsBlock

判断规则：
- type：支出用 "expense"，收入用 "income"，账户间转账用 "transfer"。默认为 "expense"。
- amount：正数金额（不带货币符号）。无法识别金额时置为 0。
- categoryId：按 type 从对应清单里选最贴切的一项；转账可留空字符串。
- accountId：从账户清单选最贴切的；用户没提到账户就留空字符串 ""（表示无账户）。
- toAccountId：仅转账时填转入账户 id，否则为 null。
- note：一句话备注，保留用户输入的原始语言；没有额外信息就留空字符串。
- date：形如 "YYYY-MM-DD"，默认今天。
- time：形如 "HH:MM"（24 小时制）。仅当用户明确提到具体时间（如「晚上八点」记 "20:00"、「中午」记 "12:00"、「刚刚」用当前时间）时才填；用户没提时间就置为 null。

只输出一个 JSON 对象，不要任何解释、不要 Markdown 代码块。格式：
{"type":"expense","amount":32,"categoryId":"transport","accountId":"","toAccountId":null,"note":"打车","date":"${_dateKey(context.today)}","time":null}
''';
}

/// 从模型返回的文本里提取第一个 JSON 对象（容忍 ```json 代码块与多余文字）。
Map<String, Object?>? extractJsonObject(String content) {
  final start = content.indexOf('{');
  final end = content.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  final slice = content.substring(start, end + 1);
  try {
    final decoded = jsonDecode(slice);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// 安全取字符串字段：模型可能把本应是字符串的字段返回成数字/布尔/数组，直接
/// `as String?` 会抛 TypeError。非字符串一律回退空串（后续按「未识别」降级处理）。
String _parseString(Object? raw) => raw is String ? raw.trim() : '';

EntryType _parseType(Object? raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  switch (value) {
    case 'income':
    case '收入':
      return EntryType.income;
    case 'transfer':
    case '转账':
      return EntryType.transfer;
    default:
      return EntryType.expense;
  }
}

double _parseAmount(Object? raw) {
  if (raw is num) {
    return raw.toDouble().abs();
  }
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return (double.tryParse(cleaned) ?? 0).abs();
  }
  return 0;
}

DateTime _parseDate(Object? raw, DateTime fallback) {
  if (raw is String) {
    final match = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw.trim());
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y != null && m != null && d != null && m >= 1 && m <= 12) {
        return DateTime(y, m, d, fallback.hour, fallback.minute);
      }
    }
  }
  return fallback;
}

/// 解析可选的 "HH:MM"（24 小时制）时间，返回 (时, 分)；无法识别返回 null。
(int, int)? _parseTime(Object? raw) {
  if (raw is String) {
    final match = RegExp(r'(\d{1,2})[:：](\d{2})').firstMatch(raw.trim());
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
  }
  return null;
}

/// 合并日期与可选时间：日期取 date 字段（缺省今天），时分取 time 字段；time 缺省时
/// 沿用 fallback（当前时刻）的时分——用户没提时间就默认此刻，提到就精确到分。
DateTime _resolveOccurredAt(
  Object? dateRaw,
  Object? timeRaw,
  DateTime fallback,
) {
  final date = _parseDate(dateRaw, fallback);
  final time = _parseTime(timeRaw);
  if (time == null) {
    return date;
  }
  return DateTime(date.year, date.month, date.day, time.$1, time.$2);
}

/// 把模型返回的文本解析成交易草稿，并把 id 校验到给定清单（未命中则降级 + 提示）。
/// 无法识别金额时抛 [AiException]（无金额无法记账）。
AiEntryDraft parseAiEntryDraft(String content, AiEntryContext context) {
  final json = extractJsonObject(content);
  if (json == null) {
    throw AiEntryException(AiEntryError.emptyResult);
  }

  final warnings = <AiDraftWarning>[];
  final type = _parseType(json['type']);
  final amount = _parseAmount(json['amount']);
  if (amount <= 0) {
    throw AiEntryException(AiEntryError.noAmount);
  }

  final categories = type == EntryType.income
      ? context.incomeCategories
      : context.expenseCategories;
  final categoryIds = categories.map((o) => o.id).toSet();
  var categoryId = _parseString(json['categoryId']);
  if (categoryId.isEmpty || !categoryIds.contains(categoryId)) {
    if (type == EntryType.transfer) {
      categoryId = '';
    } else if (categories.isNotEmpty) {
      final wasNonEmpty = categoryId.isNotEmpty;
      categoryId = categories.first.id;
      if (wasNonEmpty) {
        warnings.add(AiDraftWarning.categoryUnmatched);
      }
    } else {
      categoryId = '';
    }
  }

  final accountIds = context.accounts.map((o) => o.id).toSet();
  var accountId = _parseString(json['accountId']);
  if (accountId.isNotEmpty && !accountIds.contains(accountId)) {
    warnings.add(AiDraftWarning.accountUnmatched);
    accountId = '';
  }

  String? toAccountId;
  if (type == EntryType.transfer) {
    final raw = _parseString(json['toAccountId']);
    toAccountId = (raw.isNotEmpty && accountIds.contains(raw)) ? raw : null;
  }

  final note = _parseString(json['note']);
  final occurredAt = _resolveOccurredAt(
    json['date'],
    json['time'],
    context.today,
  );

  return AiEntryDraft(
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    note: note,
    occurredAt: occurredAt,
    warnings: warnings,
  );
}

/// 发起一次 AI 记账解析：请求 → 解析 → 校验，返回草稿。网络/解析异常抛 [AiException]。
Future<AiEntryDraft> requestAiEntryDraft({
  required AiSettings settings,
  required String input,
  required AiEntryContext context,
}) async {
  final content = await aiChatComplete(
    settings: settings,
    systemPrompt: buildAiEntryPrompt(context),
    userPrompt: input.trim(),
  );
  return parseAiEntryDraft(content, context);
}
