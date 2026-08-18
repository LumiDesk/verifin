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
/// 代码使用不可歧义的 `CNY 12.34` 形式；符号使用紧凑的 `¥12.34` 形式。
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
    MoneyCodeDisplay.symbol => '${currency.symbol}$number',
  };
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

/// Formats a rate with up to ten decimal places without amount rounding.
String formatRateValue(num value) {
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
  });

  final Map<String, double> amountsByAccountId;
  final Set<String> missingCurrencyCodes;
  final Set<String> affectedAccountIds;

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
    } else if (result is MissingCurrencyRate) {
      missingCodes.addAll(result.currencyCodes);
      affectedIds.add(account.id);
    }
  }
  return ConvertedAccountBalances(
    amountsByAccountId: Map<String, double>.unmodifiable(amounts),
    missingCurrencyCodes: Set<String>.unmodifiable(missingCodes),
    affectedAccountIds: Set<String>.unmodifiable(affectedIds),
  );
}
