import 'dart:math' as math;

import 'amount_format.dart' as amount_format;
import 'calendar_days.dart';
import 'currency_catalog.dart';
import 'models.dart';

/// 将金额规整到 [currencyCode] 的 ISO 4217 minor unit，并消除 `-0`。
double normalizeCurrencyAmount(num value, String currencyCode) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', '金额必须是有限数值');
  }
  final minorUnit = CurrencyCatalog.require(currencyCode).minorUnit;
  final factor = math.pow(10, minorUnit).toDouble();
  final normalized = (value.toDouble() * factor).round() / factor;
  return normalized == 0 ? 0 : normalized;
}

/// [currencyCode] 下可视为零的容差，等于最小货币单位的一半。
double currencyAmountTolerance(String currencyCode) {
  final minorUnit = CurrencyCatalog.require(currencyCode).minorUnit;
  return 0.5 / math.pow(10, minorUnit);
}

bool isZeroCurrencyAmount(num value, String currencyCode) {
  return value.abs() < currencyAmountTolerance(currencyCode);
}

/// 仅格式化数值，不附加货币代码或符号。
String formatCurrencyNumber(
  num value,
  String currencyCode, {
  CurrencyFractionStyle? style,
}) {
  final currency = CurrencyCatalog.require(currencyCode);
  final normalized = normalizeCurrencyAmount(value, currency.code);
  final fixed = normalized.toStringAsFixed(currency.minorUnit);
  if ((style ?? amount_format.currencyFractionStyle) ==
      CurrencyFractionStyle.standard) {
    return fixed;
  }
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 格式化带货币标识的金额。
///
/// 代码使用不可歧义的 `CNY 12.34` 形式；符号使用紧凑的 `12.34 ¥` 形式。
String formatMoney(
  num value,
  String currencyCode, {
  MoneyCodeDisplay display = MoneyCodeDisplay.code,
  CurrencyFractionStyle? style,
}) {
  final currency = CurrencyCatalog.require(currencyCode);
  final number = formatCurrencyNumber(value, currency.code, style: style);
  return switch (display) {
    MoneyCodeDisplay.none => number,
    MoneyCodeDisplay.code => '${currency.code} $number',
    MoneyCodeDisplay.symbol => '$number ${_compactCurrencySymbol(currency)}',
  };
}

/// 用户界面的金额格式：遵循设置中的单位样式，并可在单币种账本隐藏重复单位。
///
/// [forceUnit] 用于同一控件同时展示两个币种的换算字段；即使账本此前还是单币种，
/// 草稿中的两端金额也必须保留单位，不能产生歧义。
String formatUserMoney(
  num value,
  String currencyCode, {
  bool forceUnit = false,
  CurrencyFractionStyle? style,
}) {
  return formatMoney(
    value,
    currencyCode,
    display: forceUnit
        ? amount_format.preferredMoneyCodeDisplay
        : amount_format.activeMoneyCodeDisplay,
    style: style,
  );
}

String formatSignedUserMoney(
  num value,
  String currencyCode, {
  bool forceUnit = false,
  CurrencyFractionStyle? style,
}) {
  return formatSignedMoney(
    value,
    currencyCode,
    display: forceUnit
        ? amount_format.preferredMoneyCodeDisplay
        : amount_format.activeMoneyCodeDisplay,
    style: style,
  );
}

/// 设置页预览和卡片“单位”提示使用的紧凑单位文本。
String displayCurrencyUnit(String currencyCode, {MoneyUnitStyle? unitStyle}) {
  final currency = CurrencyCatalog.require(currencyCode);
  return switch (unitStyle ?? amount_format.moneyUnitStyle) {
    MoneyUnitStyle.code => currency.code,
    MoneyUnitStyle.symbol => _compactCurrencySymbol(currency),
  };
}

String _compactCurrencySymbol(CurrencyDefinition currency) {
  // CLDR 的 CNY 常规符号是 `CN¥`，用于跨地区文本消歧很合适，但用户选择“符号”
  // 样式时期待的是紧凑的 `¥`；需要无歧义时可切回 ISO 代码样式。
  return currency.code == 'CNY' ? '¥' : currency.symbol;
}

String formatSignedMoney(
  num value,
  String currencyCode, {
  MoneyCodeDisplay display = MoneyCodeDisplay.code,
  CurrencyFractionStyle? style,
}) {
  if (!value.isFinite) return '—';
  if (isZeroCurrencyAmount(value, currencyCode)) {
    return formatMoney(0, currencyCode, display: display, style: style);
  }
  final prefix = value > 0 ? '+' : '-';
  return '$prefix${formatMoney(value.abs(), currencyCode, display: display, style: style)}';
}

/// 面向界面的可读汇率：常见数值最多 4 位小数，极小汇率逐步放宽到 8 位，
/// 避免 `0.138888889` 一类长串，同时不会把合法的小汇率轻易显示成 0。
String formatRateValue(num value) {
  if (!value.isFinite) return '—';
  final absolute = value.abs();
  if (absolute == 0) return '0';
  final fractionDigits = absolute >= 0.01
      ? 4
      : absolute >= 0.0001
      ? 6
      : 8;
  final fixed = value.toDouble().toStringAsFixed(fractionDigits);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 数据导出使用的高精度汇率文本；与界面可读格式分开，避免 CSV 往返损失精度。
String formatRateValueExact(num value) {
  if (!value.isFinite) return '—';
  final fixed = value.toDouble().toStringAsFixed(10);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 查找某一日可使用的最新汇率；绝不使用未来汇率。
ExchangeRate? exchangeRateAt({
  required String bookId,
  required String baseCurrencyCode,
  required String currencyCode,
  required DateTime date,
  required Iterable<ExchangeRate> rates,
}) {
  final normalizedBase = baseCurrencyCode.toUpperCase();
  final normalizedCurrency = currencyCode.toUpperCase();
  ExchangeRate? latest;
  for (final rate in rates) {
    if (rate.bookId != bookId ||
        rate.baseCurrencyCode.toUpperCase() != normalizedBase ||
        rate.currencyCode.toUpperCase() != normalizedCurrency ||
        !isValidExchangeRate(rate.rateToBase) ||
        calendarDaysBetween(rate.effectiveDate, date) < 0) {
      continue;
    }
    if (latest == null ||
        calendarDaysBetween(latest.effectiveDate, rate.effectiveDate) > 0) {
      latest = rate;
    }
  }
  return latest;
}

double? rateToBaseAt({
  required String bookId,
  required String baseCurrencyCode,
  required String currencyCode,
  required DateTime date,
  required Iterable<ExchangeRate> rates,
}) {
  if (baseCurrencyCode.toUpperCase() == currencyCode.toUpperCase()) return 1;
  return exchangeRateAt(
    bookId: bookId,
    baseCurrencyCode: baseCurrencyCode,
    currencyCode: currencyCode,
    date: date,
    rates: rates,
  )?.rateToBase;
}

bool isValidExchangeRate(num value) => value.isFinite && value > 0;

sealed class CurrencyConversionResult {
  const CurrencyConversionResult();
}

final class ConvertedCurrencyAmount extends CurrencyConversionResult {
  const ConvertedCurrencyAmount({
    required this.amount,
    required this.sourceRateToBase,
    required this.targetRateToBase,
    this.sourceRateDate,
    this.targetRateDate,
  });

  final double amount;
  final double sourceRateToBase;
  final double targetRateToBase;
  final DateTime? sourceRateDate;
  final DateTime? targetRateDate;
}

final class MissingCurrencyRate extends CurrencyConversionResult {
  const MissingCurrencyRate(this.currencyCodes);

  final Set<String> currencyCodes;
}

/// 经账本本位币进行交叉换算：`原币金额 × 原币汇率 ÷ 目标币汇率`。
CurrencyConversionResult convertCurrencyAmount({
  required num amount,
  required String sourceCurrencyCode,
  required String targetCurrencyCode,
  required String baseCurrencyCode,
  required String bookId,
  required DateTime date,
  required Iterable<ExchangeRate> rates,
}) {
  final source = sourceCurrencyCode.toUpperCase();
  final target = targetCurrencyCode.toUpperCase();
  final base = baseCurrencyCode.toUpperCase();
  CurrencyCatalog.require(source);
  CurrencyCatalog.require(target);
  CurrencyCatalog.require(base);
  if (!amount.isFinite) {
    throw ArgumentError.value(amount, 'amount', '金额必须是有限数值');
  }

  final sourceRate = source == base
      ? null
      : exchangeRateAt(
          bookId: bookId,
          baseCurrencyCode: base,
          currencyCode: source,
          date: date,
          rates: rates,
        );
  final targetRate = target == base
      ? null
      : exchangeRateAt(
          bookId: bookId,
          baseCurrencyCode: base,
          currencyCode: target,
          date: date,
          rates: rates,
        );
  final missing = <String>{
    if (source != base && sourceRate == null) source,
    if (target != base && targetRate == null) target,
  };
  if (missing.isNotEmpty) return MissingCurrencyRate(missing);

  final sourceRateValue = sourceRate?.rateToBase ?? 1;
  final targetRateValue = targetRate?.rateToBase ?? 1;
  return ConvertedCurrencyAmount(
    amount: normalizeCurrencyAmount(
      amount.toDouble() * sourceRateValue / targetRateValue,
      target,
    ),
    sourceRateToBase: sourceRateValue,
    targetRateToBase: targetRateValue,
    sourceRateDate: sourceRate?.effectiveDate,
    targetRateDate: targetRate?.effectiveDate,
  );
}

/// 交易列表/只读查询用于跨币种比较的本位币金额；不写回模型、不进入收支统计。
/// 收支使用保存时冻结的本位币金额，转账才按交易日汇率临时折算转出端实际金额。
double? comparableEntryAmountInBase({
  required LedgerEntry entry,
  required Iterable<Account> accounts,
  required String baseCurrencyCode,
  required Iterable<ExchangeRate> rates,
}) {
  switch (entry.type) {
    case EntryType.expense:
      return entry.netBaseAmount;
    case EntryType.income:
      return entry.baseAmount;
    case EntryType.refund:
      return entry.baseAmount;
    case EntryType.transfer:
      final sourceAccount = accounts
          .where((account) => account.id == entry.accountId)
          .firstOrNull;
      final sourceCode = sourceAccount?.currencyCode ?? entry.currencyCode;
      final sourceAmount = entry.accountAmount ?? entry.amount;
      final result = convertCurrencyAmount(
        amount: sourceAmount,
        sourceCurrencyCode: sourceCode,
        targetCurrencyCode: baseCurrencyCode,
        baseCurrencyCode: baseCurrencyCode,
        bookId: entry.bookId,
        date: entry.occurredAt,
        rates: rates,
      );
      return result is ConvertedCurrencyAmount ? result.amount : null;
  }
}

bool isExchangeRateStale(
  ExchangeRate rate,
  DateTime asOf, {
  int thresholdDays = 30,
}) {
  if (thresholdDays < 0) {
    throw ArgumentError.value(thresholdDays, 'thresholdDays', '不能小于零');
  }
  return calendarDaysBetween(rate.effectiveDate, asOf) > thresholdDays;
}

class ConvertedAccountBalances {
  const ConvertedAccountBalances({
    required this.amountsByAccountId,
    required this.missingCurrencyCodes,
    required this.affectedAccountIds,
    required this.rateDatesByAccountId,
    required this.staleAccountIds,
  });

  final Map<String, double> amountsByAccountId;
  final Set<String> missingCurrencyCodes;
  final Set<String> affectedAccountIds;
  final Map<String, DateTime> rateDatesByAccountId;
  final Set<String> staleAccountIds;

  bool get isComplete => missingCurrencyCodes.isEmpty;

  double? get completeTotal => isComplete
      ? amountsByAccountId.values.fold<double>(0, (sum, value) => sum + value)
      : null;
}

/// Converts account-native balances to one ledger base currency. If any rate
/// is missing, [completeTotal] is null; callers must not display a partial sum.
ConvertedAccountBalances convertAccountBalancesToBase({
  required Iterable<Account> accounts,
  required double Function(Account account) balanceOf,
  required String bookId,
  required String baseCurrencyCode,
  required DateTime date,
  required Iterable<ExchangeRate> rates,
}) {
  final amounts = <String, double>{};
  final missingCodes = <String>{};
  final affectedIds = <String>{};
  final rateDates = <String, DateTime>{};
  final staleAccountIds = <String>{};
  for (final account in accounts) {
    final balance = balanceOf(account);
    if (isZeroCurrencyAmount(balance, account.currencyCode)) {
      amounts[account.id] = 0;
      continue;
    }
    final result = convertCurrencyAmount(
      amount: balance,
      sourceCurrencyCode: account.currencyCode,
      targetCurrencyCode: baseCurrencyCode,
      baseCurrencyCode: baseCurrencyCode,
      bookId: bookId,
      date: date,
      rates: rates,
    );
    if (result is ConvertedCurrencyAmount) {
      amounts[account.id] = result.amount;
      final rateDate = result.sourceRateDate;
      if (rateDate != null) {
        rateDates[account.id] = rateDate;
        if (calendarDaysBetween(rateDate, date) > 30) {
          staleAccountIds.add(account.id);
        }
      }
    } else if (result is MissingCurrencyRate) {
      missingCodes.addAll(result.currencyCodes);
      affectedIds.add(account.id);
    }
  }
  return ConvertedAccountBalances(
    amountsByAccountId: Map<String, double>.unmodifiable(amounts),
    missingCurrencyCodes: Set<String>.unmodifiable(missingCodes),
    affectedAccountIds: Set<String>.unmodifiable(affectedIds),
    rateDatesByAccountId: Map<String, DateTime>.unmodifiable(rateDates),
    staleAccountIds: Set<String>.unmodifiable(staleAccountIds),
  );
}
