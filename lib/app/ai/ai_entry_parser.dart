import 'dart:convert';

import '../category_tree.dart';
import '../currency_catalog.dart';
import '../models.dart';
import 'ai_client.dart';
import 'ai_settings.dart';

/// 一个可选项（分类或账户），供 AI 从中挑选并回传 id。
class AiOption {
  const AiOption({
    required this.id,
    required this.label,
    this.currencyCode,
    this.isUncategorized = false,
  });

  final String id;

  /// 分类用完整路径（如「餐饮 / 外卖」）；账户用名称。
  final String label;
  final String? currencyCode;

  /// 该分类是否为「未分类」兜底。AI 认不出分类时落到这里，而不是列表第一个分类。
  final bool isUncategorized;
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
    required this.baseCurrencyCode,
  });

  final List<AiOption> expenseCategories;
  final List<AiOption> incomeCategories;
  final List<AiOption> accounts;
  final DateTime today;
  final String bookId;
  final String baseCurrencyCode;
}

/// 解析降级提示的类型（UI 侧本地化展示）。
enum AiDraftWarning { categoryUnmatched, accountUnmatched, currencyUnmatched }

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
    required this.currencyCode,
    required this.categoryId,
    required this.accountId,
    required this.toAccountId,
    required this.note,
    required this.occurredAt,
    this.warnings = const <AiDraftWarning>[],
  });

  final EntryType type;
  final double amount;
  final String currencyCode;
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
      : context.accounts
            .map(
              (o) =>
                  '- ${o.id} | ${o.label} | ${o.currencyCode ?? context.baseCurrencyCode}',
            )
            .join('\n');

  // 示例用清单里的真实 id 与名称，避免模型照着假 id（如 "transport"）编造。
  final exampleCategory = context.expenseCategories.isNotEmpty
      ? context.expenseCategories.first
      : null;
  final example = jsonEncode(<String, Object?>{
    'type': 'expense',
    'amount': 32,
    'currencyCode': context.baseCurrencyCode,
    'categoryId': exampleCategory?.id ?? '',
    'category': exampleCategory?.label ?? '',
    'accountId': '',
    'toAccountId': null,
    'note': '午餐',
    'date': _dateKey(context.today),
    'time': null,
  });

  return '''
你是一个记账助手。请把用户用自然语言描述的一笔账，解析成一个 JSON 对象。
现在是 ${_dateKey(context.today)} ${_timeKey(context.today)}（当前日期与时间，用于解析「今天」「昨天」「前天」「上午」「晚上八点」「半小时前」等相对日期或时间）。

只能使用下面清单里给出的分类和账户，不要编造清单外的 id 或名称。

支出分类（每行是「id | 完整名称」）：
${optionsBlock(context.expenseCategories)}

收入分类（每行是「id | 完整名称」）：
${optionsBlock(context.incomeCategories)}

账户（accountId / toAccountId 从这里选）：
$accountsBlock

判断规则：
- type：支出用 "expense"，收入用 "income"，账户间转账用 "transfer"。默认为 "expense"。
- amount：正数金额（不带货币符号）。无法识别金额时置为 0。
- currencyCode：金额原币的 ISO 4217 三位代码。用户明确提到美元、日元、货币符号或代码时据此判断；否则使用所选账户币种，没有账户则使用账本本位币 ${context.baseCurrencyCode}。
- categoryId：清单里该分类前面的 id，必须原样复制（通常是随机字符串），不要把分类名当 id。无法确定 id 时留空字符串。
- category：该分类在清单里的完整名称（含父分类路径，如「餐饮 / 外卖」）。填了 categoryId 时可以留空；无法确定 id 时填名称，程序会按名称匹配。
- 清单里没有合适的分类时，categoryId 与 category 都留空字符串；不要用清单外的分类。
- accountId：从账户清单选最贴切的；用户没提到账户就留空字符串 ""（表示无账户）。
- toAccountId：仅转账时填转入账户 id，否则为 null。
- note：一句话备注，保留用户输入的原始语言；没有额外信息就留空字符串。
- date：形如 "YYYY-MM-DD"，默认今天。
- time：形如 "HH:MM"（24 小时制）。仅当用户明确提到具体时间（如「晚上八点」记 "20:00"、「中午」记 "12:00"、「刚刚」用当前时间）时才填；用户没提时间就置为 null。

只输出一个 JSON 对象，不要任何解释、不要 Markdown 代码块。格式：
$example
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
  final rawCategoryId = _parseString(json['categoryId']);
  final rawCategoryName = _parseString(json['category']);
  final matchedCategoryId = _resolveCategoryId(
    rawId: rawCategoryId,
    rawName: rawCategoryName,
    categories: categories,
  );
  String categoryId;
  if (type == EntryType.transfer) {
    // 转账的分类由记账页按本账本的「转账」分类补齐，AI 不挑。
    categoryId = '';
  } else if (matchedCategoryId != null) {
    categoryId = matchedCategoryId;
  } else {
    if (rawCategoryId.isNotEmpty || rawCategoryName.isNotEmpty) {
      warnings.add(AiDraftWarning.categoryUnmatched);
    }
    // 认不出就落到本类型的「未分类」；账本还没有兜底分类时返回空分类（记账页会提示确认），不回退到清单第一个分类。
    categoryId =
        categories.where((option) => option.isUncategorized).firstOrNull?.id ??
        '';
  }

  final accountIds = context.accounts.map((o) => o.id).toSet();
  var accountId = _parseString(json['accountId']);
  if (accountId.isNotEmpty && !accountIds.contains(accountId)) {
    warnings.add(AiDraftWarning.accountUnmatched);
    accountId = '';
  }

  final accountCurrencyCode = context.accounts
      .where((option) => option.id == accountId)
      .firstOrNull
      ?.currencyCode;
  final rawCurrencyCode = _parseString(json['currencyCode']).toUpperCase();
  var currencyCode = rawCurrencyCode.isEmpty
      ? accountCurrencyCode ?? context.baseCurrencyCode
      : rawCurrencyCode;
  if (CurrencyCatalog.find(currencyCode) == null) {
    warnings.add(AiDraftWarning.currencyUnmatched);
    currencyCode = accountCurrencyCode ?? context.baseCurrencyCode;
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
    currencyCode: currencyCode,
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    note: note,
    occurredAt: occurredAt,
    warnings: warnings,
  );
}

/// 把模型回传的分类解析到清单里的 id：先按 id 精确匹配，再按名称匹配。
///
/// 模型经常不照抄随机 id（而是回传「网购」这样的名称），只比对 id 会把明明存在的
/// 分类判成未识别。名称解析放在这里做，不额外发请求。
String? _resolveCategoryId({
  required String rawId,
  required String rawName,
  required List<AiOption> categories,
}) {
  if (rawId.isNotEmpty) {
    for (final option in categories) {
      if (option.id == rawId) {
        return option.id;
      }
    }
  }
  // categoryId 里也可能装着分类名（模型把名称填进了 id 字段），一并当名称尝试。
  for (final candidate in <String>[rawName, rawId]) {
    if (candidate.trim().isEmpty) {
      continue;
    }
    final matched = _matchCategoryByName(candidate, categories);
    if (matched != null) {
      return matched;
    }
  }
  return null;
}

/// 名称解析顺序：完整路径精确 → 叶子名精确 → 唯一包含匹配。
/// 命中多个候选（同名分类）时返回 null，交给「未分类」兜底，不猜。
String? _matchCategoryByName(String raw, List<AiOption> categories) {
  final target = _canonicalCategoryName(raw);
  if (target.isEmpty) {
    return null;
  }
  final exact = categories
      .where((option) => _canonicalCategoryName(option.label) == target)
      .toList(growable: false);
  if (exact.length == 1) {
    return exact.first.id;
  }
  if (exact.length > 1) {
    return null;
  }
  final leafExact = categories
      .where(
        (option) => _canonicalCategoryName(_leafLabel(option.label)) == target,
      )
      .toList(growable: false);
  if (leafExact.length == 1) {
    return leafExact.first.id;
  }
  if (leafExact.length > 1) {
    return null;
  }
  // 单字名称太容易误配（如「餐」），只对两个字符以上的名称做包含匹配。
  if (target.length < 2) {
    return null;
  }
  final contains = categories
      .where((option) {
        final label = _canonicalCategoryName(option.label);
        return label.contains(target) || target.contains(label);
      })
      .toList(growable: false);
  return contains.length == 1 ? contains.first.id : null;
}

/// 分类名的比较形态：每段做全半角/大小写归一，去掉首尾空白，再用 " / " 重新连接。
/// 这样「餐饮／咖啡」「餐饮 / 咖啡」「 餐饮 / 咖啡 」都能落到同一个键。
String _canonicalCategoryName(String label) {
  final parts = label
      .split(RegExp(r'\s*[/／]\s*'))
      .map(normalizedCategoryLabel)
      .where((part) => part.isNotEmpty);
  return parts.join(' / ');
}

/// 分类路径的最后一段（`pathLabel` 用 " / " 连接）。
String _leafLabel(String label) {
  final parts = label.split(RegExp(r'\s*[/／]\s*'));
  return (parts.isEmpty ? label : parts.last).trim();
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

/// 采集文本送 AI 前的长度上限：账单原文一般几百字，超长多半混入了整页
/// 无关内容，截断保护 Token 消耗（关键交易信息几乎总在前部）。
const int capturedTextMaxLength = 4000;

/// 采集文本（分享/自动化工具送入的账单原文）的前置过滤：连一个数字都没有的文本不可能
/// 含交易金额，直接短路不调 AI。
bool capturedTextLikelyTransaction(String text) {
  return RegExp(r'[0-9０-９]').hasMatch(text);
}

/// 构造「采集文本」解析的系统提示词：输入不是用户亲手打的一句话，而是账单截图
/// 的账单原文——可能换行、乱序、混着界面按钮和
/// 余额等无关数字，须挑出最主要的一笔交易。
String buildCapturedEntryPrompt(AiEntryContext context) {
  final base = buildAiEntryPrompt(context);
  return '''
$base

补充：本次用户输入不是亲手描述的一句话，而是一段自动采集的账单文本（分享或自动化工具送入的账单原文），可能包含换行、乱序、界面按钮文字等噪音。按下面规则从中解析出最主要的一笔交易：
- 金额只取「交易金额/付款金额/收款金额」本身；余额、优惠、积分、红包、手续费上限等其他数字一律忽略。
- 到账、收款、入账、退款、工资、报销 → "income"；付款、消费、支出、扣款 → "expense"；账户间转账、还款、提现 → "transfer"。
- 文本里出现的交易时间（日期与时分）优先于当前时间，填入 date 与 time。
- 对方名称/商户名/备注摘要放进 note，保留原语言。
- 如果整段文本根本不含任何一笔交易（如聊天记录、营销内容、纯界面文字），把 amount 置为 0。
''';
}

/// 发起一次「采集文本」记账解析：预过滤 → 截断 → 请求 → 解析 → 校验，返回草稿。
/// 文本无数字直接抛 [AiEntryException]（无金额），不浪费 AI 调用。
Future<AiEntryDraft> requestCapturedEntryDraft({
  required AiSettings settings,
  required String capturedText,
  required AiEntryContext context,
}) async {
  final trimmed = capturedText.trim();
  if (trimmed.isEmpty || !capturedTextLikelyTransaction(trimmed)) {
    throw AiEntryException(AiEntryError.noAmount);
  }
  final input = trimmed.length > capturedTextMaxLength
      ? trimmed.substring(0, capturedTextMaxLength)
      : trimmed;
  final content = await aiChatComplete(
    settings: settings,
    systemPrompt: buildCapturedEntryPrompt(context),
    userPrompt: input,
  );
  return parseAiEntryDraft(content, context);
}
