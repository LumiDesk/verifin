import '../../models.dart';

/// 单行导入错误（`line` 为源文件行号，从 1 计、含表头；二进制来源可用记录序号）。
class ImportRowError {
  const ImportRowError({required this.line, required this.message});

  final int line;
  final String message;
}

/// 各来源解析后的**强类型**中间记录。格式解码 / 字段映射由各平台 parser 负责，到这里
/// 日期、金额、类型都已是 Veri Fin 领域值（不再是「字符串位置行」），交由
/// [buildImportPlanFromRecords] 统一按名建账户/分类/标签、构造 [LedgerEntry]。
///
/// 取代旧的 `_canonicalHeader` 字符串行中间层：二进制来源（微信 Excel 序列号、Tally
/// epoch 毫秒、金额 double）可直接构造强类型记录，不必「类型→字符串→类型」往返
/// （那正是历史 bug 温床，如一木退款被二次相减的 issue #10）。
class RawImportRecord {
  const RawImportRecord({
    required this.date,
    required this.type,
    required this.amount,
    this.currencyCode,
    this.accountCurrencyCode,
    this.toAccountCurrencyCode,
    this.accountAmount,
    this.toAccountAmount,
    this.baseAmount,
    this.rateToBase,
    this.rateSource,
    this.rateDate,
    this.category = '',
    this.subCategory = '',
    this.account = '',
    this.toAccount = '',
    this.note = '',
    this.fee = 0,
    this.refunded = 0,
    this.tags = const <String>[],
    this.sourceLine,
  });

  final DateTime date;
  final EntryType type;

  /// 恒 > 0：方向由 [type] 表达，各 parser 已取绝对值。
  final double amount;

  /// 原币 ISO 4217 代码；null 表示来源没有币种字段，由导入时回退当前账本本位币。
  final String? currencyCode;

  /// 来源/转入账户的 ISO 4217 代码；来源文件未提供时由账户匹配或原币推断。
  final String? accountCurrencyCode;
  final String? toAccountCurrencyCode;

  /// 来源账户真实扣款、转入账户真实到账和冻结本位币金额。来源未提供时为 null，
  /// plan builder 只在币种相同时安全回退 [amount]，不会猜 1:1。
  final double? accountAmount;
  final double? toAccountAmount;
  final double? baseAmount;

  /// `1 原币 = X 本位币`；仅作为来源提供的换算依据。
  final double? rateToBase;
  final ExchangeRateSource? rateSource;
  final DateTime? rateDate;

  /// 一级分类名（'' = 无）。
  final String category;

  /// 二级分类名（'' = 无）；与 [category] 一起还原父子层级。
  final String subCategory;

  /// 账户名（'' = 无账户，只记金额不动余额）。
  final String account;

  /// 转入账户名（'' = 无；仅转账用）。
  final String toAccount;
  final String note;

  /// 转账手续费（>= 0；仅转账用）。
  final double fee;

  /// 支出退款额（>= 0；plan_builder 再钳到 [0, amount]、仅支出生效）。
  final double refunded;

  /// 标签名（未归一化；plan_builder 去重并解析成标签 id）。
  final List<String> tags;

  /// 源文件行号，供 CSV 模板逐行报错定位；二进制来源可为 null。
  final int? sourceLine;

  RawImportRecord withImportedRate(double rate) {
    return RawImportRecord(
      date: date,
      type: type,
      amount: amount,
      currencyCode: currencyCode,
      accountCurrencyCode: accountCurrencyCode,
      toAccountCurrencyCode: toAccountCurrencyCode,
      accountAmount: accountAmount,
      toAccountAmount: toAccountAmount,
      baseAmount: baseAmount,
      rateToBase: rate,
      rateSource: ExchangeRateSource.imported,
      rateDate: date,
      category: category,
      subCategory: subCategory,
      account: account,
      toAccount: toAccount,
      note: note,
      fee: fee,
      refunded: refunded,
      tags: tags,
      sourceLine: sourceLine,
    );
  }
}

/// 携带余额 / 类型的账户元数据（目前仅 Tally 备份提供）。plan_builder 用它把本次导入
/// 新建的账户回推初始余额（使显示余额对齐来源），并补建没有流水的账户。
class RawImportAccount {
  const RawImportAccount({
    required this.name,
    required this.signedBalance,
    required this.includeInAssets,
    required this.type,
    this.currencyCode,
  });

  final String name;

  /// 已按符号归一：资产/借出/理财记正，负债/分期记负（与 Veri Fin「余额正负=资产/负债」一致）。
  final double signedBalance;
  final bool includeInAssets;
  final AccountType type;

  /// null 表示来源无币种字段，导入时使用当前账本本位币。
  final String? currencyCode;
}

/// 单个来源 parser 的产物：强类型记录 + 逐行错误 + 可选账户元数据。各平台 parser
/// 都产出它，再统一喂给 [buildImportPlanFromRecords]。
class ParsedImport {
  const ParsedImport({
    this.records = const <RawImportRecord>[],
    this.errors = const <ImportRowError>[],
    this.accounts = const <RawImportAccount>[],
  });

  final List<RawImportRecord> records;
  final List<ImportRowError> errors;

  /// 携带余额/类型、需要独立落库的账户（即使无交易引用），目前仅 Tally 提供。
  final List<RawImportAccount> accounts;
}

// ---------------------------------------------------------------------------
// 字符串字段 → 强类型 的解析原语（字符串来源：CSV 模板 / 支付宝 / 薄荷复用）
// ---------------------------------------------------------------------------

/// 收支类型：中英与「支/收/转」简写；无法识别返回 null。
EntryType? parseImportType(String raw) {
  final value = raw.trim().toLowerCase();
  switch (value) {
    case '支出':
    case 'expense':
    case '支':
      return EntryType.expense;
    case '收入':
    case 'income':
    case '收':
      return EntryType.income;
    case '转账':
    case 'transfer':
    case '转':
      return EntryType.transfer;
  }
  return null;
}

/// 金额：去币种符号/千分位/空白，取绝对值（方向由类型定）。0、空或非数字返回 null。
double? parseImportAmount(String raw) {
  final value = parseImportAmountAllowZero(raw);
  if (value == null || value == 0) return null;
  return value;
}

/// 与 [parseImportAmount] 相同，但允许 0；供转账 `baseAmount = 0` 等可选字段使用。
double? parseImportAmountAllowZero(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[¥$,\s]'), '')
      .replaceAll('，', '');
  if (cleaned.isEmpty) {
    return null;
  }
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  return value.abs();
}

/// 手续费/退款额：可空/可为 0，非法或负数按 0 处理（不像金额那样使整行失败）。
double parseImportFee(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[¥$,\s]'), '')
      .replaceAll('，', '');
  if (cleaned.isEmpty) {
    return 0;
  }
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite || value < 0) {
    return 0;
  }
  return value;
}

/// 日期："YYYY-MM-DD" 或 "YYYY-MM-DD HH:MM(:SS)"（容忍 / 与 . 分隔）。无效返回 null。
DateTime? parseImportDate(String raw) {
  final value = raw.trim().replaceAll('/', '-').replaceAll('.', '-');
  if (value.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;
  final second = int.tryParse(match.group(6) ?? '') ?? 0;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final result = DateTime(year, month, day, hour, minute, second);
  // DateTime 会把越界的日静默归一化（如 2-30 → 3-2）。回读校验，宁可判为无效日期
  // 让该行报错，也不要静默记成错误的日期。
  if (result.year != year || result.month != month || result.day != day) {
    return null;
  }
  return result;
}

/// 拆多标签串（如一木「客户, 代购」）：按逗号（半/全角）分割、去空去首尾空白。
/// 归一化去重与建标签在 plan_builder 里做，这里只负责拆分。
List<String> splitTagLabels(String raw) {
  if (raw.trim().isEmpty) {
    return const <String>[];
  }
  return raw
      .split(RegExp(r'[,，]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

/// 从**字符串字段**构建一条记录；date/type/amount 任一无法解析则返回 null 并经
/// [onError] 上报（供逐行错误收集）。字符串来源（CSV 模板 / 支付宝 / 薄荷）共用；
/// 二进制来源（微信序列号、Tally epoch）直接 `RawImportRecord(...)` 构造、不走这里，
/// 以免重新引入字符串往返。
RawImportRecord? buildRecordFromStrings({
  required String date,
  required String type,
  required String amount,
  String category = '',
  String subCategory = '',
  String account = '',
  String toAccount = '',
  String note = '',
  String fee = '',
  String refunded = '',
  String currencyCode = '',
  String accountCurrencyCode = '',
  String toAccountCurrencyCode = '',
  String accountAmount = '',
  String toAccountAmount = '',
  String baseAmount = '',
  String rateToBase = '',
  List<String> tags = const <String>[],
  int? sourceLine,
  void Function(String message)? onError,
}) {
  final parsedType = parseImportType(type);
  if (parsedType == null) {
    onError?.call('类型无法识别（应为 支出/收入/转账）');
    return null;
  }
  final parsedAmount = parseImportAmount(amount);
  if (parsedAmount == null) {
    onError?.call('金额无效（应为大于 0 的数字）');
    return null;
  }
  final parsedDate = parseImportDate(date);
  if (parsedDate == null) {
    onError?.call('日期格式无效（应为 2026-01-05）');
    return null;
  }
  return RawImportRecord(
    date: parsedDate,
    type: parsedType,
    amount: parsedAmount,
    currencyCode: currencyCode.trim().isEmpty
        ? null
        : currencyCode.trim().toUpperCase(),
    accountCurrencyCode: accountCurrencyCode.trim().isEmpty
        ? null
        : accountCurrencyCode.trim().toUpperCase(),
    toAccountCurrencyCode: toAccountCurrencyCode.trim().isEmpty
        ? null
        : toAccountCurrencyCode.trim().toUpperCase(),
    accountAmount: _parseOptionalImportAmount(accountAmount),
    toAccountAmount: _parseOptionalImportAmount(toAccountAmount),
    baseAmount: _parseOptionalImportAmount(baseAmount),
    rateToBase: _parseOptionalImportAmount(rateToBase),
    rateSource: rateToBase.trim().isEmpty ? null : ExchangeRateSource.imported,
    rateDate: rateToBase.trim().isEmpty ? null : parsedDate,
    category: category,
    subCategory: subCategory,
    account: account,
    toAccount: toAccount,
    note: note,
    fee: parseImportFee(fee),
    refunded: parseImportFee(refunded),
    tags: tags,
    sourceLine: sourceLine,
  );
}

double? _parseOptionalImportAmount(String raw) {
  if (raw.trim().isEmpty) return null;
  return parseImportAmountAllowZero(raw);
}
