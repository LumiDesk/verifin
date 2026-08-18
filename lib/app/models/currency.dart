/// 多币种领域模型：静态货币定义、账本设置状态、转换来源与本地汇率。
library;

const String defaultCurrencyCode = 'CNY';

class CurrencyDefinition {
  const CurrencyDefinition({
    required this.code,
    required this.numericCode,
    required this.nameZh,
    required this.nameEn,
    required this.symbol,
    required this.minorUnit,
  });

  final String code;
  final String numericCode;
  final String nameZh;
  final String nameEn;
  final String symbol;
  final int minorUnit;

  String nameForLocale(String localeName) =>
      localeName.toLowerCase().startsWith('zh') ? nameZh : nameEn;
}

enum CurrencySetupStatus {
  legacyUnconfirmed,
  confirmed;

  static CurrencySetupStatus fromStorage(String? value) {
    return CurrencySetupStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CurrencySetupStatus.legacyUnconfirmed,
    );
  }
}

enum ConversionSource {
  identity,
  manual,
  rateTable,
  imported,
  legacy;

  static ConversionSource fromStorage(String? value) {
    return ConversionSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => ConversionSource.legacy,
    );
  }
}

enum RecurringRatePolicy {
  latestAvailable,
  fixedAmounts;

  static RecurringRatePolicy fromStorage(String? value) {
    return RecurringRatePolicy.values.firstWhere(
      (policy) => policy.name == value,
      orElse: () => RecurringRatePolicy.fixedAmounts,
    );
  }
}

enum ExchangeRateSource {
  manual,
  imported;

  static ExchangeRateSource fromStorage(String? value) {
    return ExchangeRateSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => ExchangeRateSource.manual,
    );
  }
}

enum CurrencyFractionStyle {
  compact,
  standard;

  static CurrencyFractionStyle fromStorage(String? value) {
    return CurrencyFractionStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => CurrencyFractionStyle.compact,
    );
  }
}

enum MoneyCodeDisplay { none, code, symbol }

class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.bookId,
    required this.baseCurrencyCode,
    required this.currencyCode,
    required this.effectiveDate,
    required this.rateToBase,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String baseCurrencyCode;
  final String currencyCode;
  final DateTime effectiveDate;
  final double rateToBase;
  final ExchangeRateSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExchangeRate copyWith({
    double? rateToBase,
    ExchangeRateSource? source,
    DateTime? effectiveDate,
    DateTime? updatedAt,
  }) {
    return ExchangeRate(
      id: id,
      bookId: bookId,
      baseCurrencyCode: baseCurrencyCode,
      currencyCode: currencyCode,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      rateToBase: rateToBase ?? this.rateToBase,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'bookId': bookId,
      'baseCurrencyCode': baseCurrencyCode,
      'currencyCode': currencyCode,
      'effectiveDate': currencyDateKey(effectiveDate),
      'rateToBase': rateToBase,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ExchangeRate fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return ExchangeRate(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? 'default',
      baseCurrencyCode:
          (json['baseCurrencyCode'] as String? ?? defaultCurrencyCode)
              .toUpperCase(),
      currencyCode: (json['currencyCode'] as String? ?? defaultCurrencyCode)
          .toUpperCase(),
      effectiveDate:
          parseCurrencyDateKey(json['effectiveDate']) ??
          DateTime(now.year, now.month, now.day),
      rateToBase: (json['rateToBase'] as num? ?? 0).toDouble(),
      source: ExchangeRateSource.fromStorage(json['source'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

String currencyDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? parseCurrencyDateKey(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}
