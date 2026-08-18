import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/amount_format.dart' as amount_format;
import 'package:verifin/app/currency_catalog.dart';
import 'package:verifin/app/currency_math.dart';
import 'package:verifin/app/models.dart';

void main() {
  group('CurrencyCatalog', () {
    test('包含去重且按代码排序的 155 种法定货币', () {
      expect(CurrencyCatalog.all, hasLength(155));
      final codes = CurrencyCatalog.all.map((item) => item.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, orderedEquals(<String>[...codes]..sort()));
      expect(
        CurrencyCatalog.all.map((item) => item.numericCode).toSet(),
        hasLength(CurrencyCatalog.all.length),
      );
      expect(
        CurrencyCatalog.all.every(
          (item) => item.minorUnit >= 0 && item.minorUnit <= 3,
        ),
        isTrue,
      );
    });

    test('包含常用货币，排除非流通资金、贵金属与测试代码', () {
      expect(CurrencyCatalog.require('cny').minorUnit, 2);
      expect(CurrencyCatalog.require('JPY').minorUnit, 0);
      expect(CurrencyCatalog.require('KWD').minorUnit, 3);
      for (final code in <String>[
        'XAU',
        'XAG',
        'XDR',
        'XTS',
        'XXX',
        'CLF',
        'USN',
      ]) {
        expect(CurrencyCatalog.isSupported(code), isFalse, reason: code);
      }
    });

    test('搜索覆盖代码、数字码和中英文名，常用货币优先', () {
      expect(CurrencyCatalog.search('人民币').single.code, 'CNY');
      expect(CurrencyCatalog.search('392').single.code, 'JPY');
      expect(CurrencyCatalog.search('Kuwaiti').single.code, 'KWD');
      expect(
        CurrencyCatalog.search('').take(4).map((item) => item.code),
        <String>['CNY', 'USD', 'EUR', 'JPY'],
      );
      expect(CurrencyCatalog.require('CNY').nameForLocale('zh_Hans'), '人民币');
      expect(
        CurrencyCatalog.require('CNY').nameForLocale('en_US'),
        'Chinese Yuan',
      );
    });
  });

  group('货币金额', () {
    tearDown(() {
      amount_format.currencyFractionStyle = CurrencyFractionStyle.compact;
      amount_format.moneyUnitStyle = MoneyUnitStyle.symbol;
      amount_format.hideUnitInSingleCurrency = true;
      amount_format.activeBookUsesMultipleCurrencies = false;
    });

    test('按各自 minor unit 规整', () {
      expect(normalizeCurrencyAmount(12.345, 'CNY'), 12.35);
      expect(normalizeCurrencyAmount(12.5, 'JPY'), 13);
      expect(normalizeCurrencyAmount(12.3456, 'KWD'), 12.346);
      expect(normalizeCurrencyAmount(-0.001, 'CNY'), 0);
      expect(
        () => normalizeCurrencyAmount(double.nan, 'CNY'),
        throwsArgumentError,
      );
    });

    test('紧凑与标准小数位遵循货币定义', () {
      expect(formatCurrencyNumber(12, 'CNY'), '12');
      expect(formatCurrencyNumber(12.5, 'CNY'), '12.5');
      expect(formatCurrencyNumber(12, 'JPY'), '12');
      expect(formatCurrencyNumber(12.3, 'KWD'), '12.3');
      expect(
        formatCurrencyNumber(12, 'CNY', style: CurrencyFractionStyle.standard),
        '12.00',
      );
      expect(
        formatCurrencyNumber(
          12.3,
          'KWD',
          style: CurrencyFractionStyle.standard,
        ),
        '12.300',
      );
      expect(formatCurrencyNumber(-0.001, 'CNY'), '0');
    });

    test('全局偏好和旧两位小数入口保持兼容', () {
      amount_format.amountForceTwoDecimals = true;
      expect(
        amount_format.currencyFractionStyle,
        CurrencyFractionStyle.standard,
      );
      expect(formatCurrencyNumber(12, 'JPY'), '12');
      expect(formatCurrencyNumber(12, 'KWD'), '12.000');

      amount_format.amountForceTwoDecimals = false;
      expect(
        amount_format.currencyFractionStyle,
        CurrencyFractionStyle.compact,
      );
    });

    test('货币代码与符号显示无歧义', () {
      expect(formatMoney(12.3, 'CNY'), 'CNY 12.3');
      expect(
        formatMoney(12.3, 'CNY', display: MoneyCodeDisplay.symbol),
        '12.3 ¥',
      );
      expect(formatMoney(12.3, 'CNY', display: MoneyCodeDisplay.none), '12.3');
    });

    test('用户金额按设置切换样式并在单币种账本隐藏重复单位', () {
      expect(formatUserMoney(100, 'CNY'), '100');
      expect(formatUserMoney(100, 'CNY', forceUnit: true), '100 ¥');
      expect(displayCurrencyUnit('CNY'), '¥');

      amount_format.activeBookUsesMultipleCurrencies = true;
      expect(formatUserMoney(100, 'CNY'), '100 ¥');
      expect(formatSignedUserMoney(-10, 'USD'), r'-10 $');

      amount_format.moneyUnitStyle = MoneyUnitStyle.code;
      expect(formatUserMoney(100, 'CNY'), 'CNY 100');
      expect(displayCurrencyUnit('CNY'), 'CNY');

      amount_format.activeBookUsesMultipleCurrencies = false;
      amount_format.hideUnitInSingleCurrency = false;
      expect(formatUserMoney(100, 'CNY'), 'CNY 100');
    });

    test('界面汇率限制冗长小数，导出格式保留高精度', () {
      expect(formatRateValue(0.138888889), '0.1389');
      expect(formatRateValue(7.123456789), '7.1235');
      expect(formatRateValue(0.0000123456789), '0.00001235');
      expect(formatRateValueExact(0.138888889), '0.138888889');
    });
  });

  group('ExchangeRate', () {
    final createdAt = DateTime.utc(2026, 8, 18, 8);

    ExchangeRate rate(
      String id,
      String code,
      DateTime effectiveDate,
      double value, {
      String bookId = 'book',
    }) {
      return ExchangeRate(
        id: id,
        bookId: bookId,
        baseCurrencyCode: 'CNY',
        currencyCode: code,
        effectiveDate: effectiveDate,
        rateToBase: value,
        source: ExchangeRateSource.manual,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    }

    test('JSON 往返只保留生效日，不混入时刻', () {
      final source = rate('r1', 'USD', DateTime(2026, 8, 17, 23, 59), 7.15);
      final json = source.toJson();
      expect(json['effectiveDate'], '2026-08-17');
      final restored = ExchangeRate.fromJson(json);
      expect(restored.id, source.id);
      expect(restored.bookId, source.bookId);
      expect(restored.baseCurrencyCode, 'CNY');
      expect(restored.currencyCode, 'USD');
      expect(restored.effectiveDate, DateTime(2026, 8, 17));
      expect(restored.rateToBase, 7.15);
      expect(restored.source, ExchangeRateSource.manual);
      expect(restored.createdAt, createdAt);
    });

    test('使用当日或最近历史汇率，绝不使用未来或其他账本汇率', () {
      final rates = <ExchangeRate>[
        rate('old', 'USD', DateTime(2026, 8, 1), 7.1),
        rate('exact', 'USD', DateTime(2026, 8, 10), 7.2),
        rate('future', 'USD', DateTime(2026, 8, 20), 7.3),
        rate('other', 'USD', DateTime(2026, 8, 11), 9, bookId: 'other'),
        rate('invalid', 'USD', DateTime(2026, 8, 12), 0),
      ];
      expect(
        rateToBaseAt(
          bookId: 'book',
          baseCurrencyCode: 'CNY',
          currencyCode: 'USD',
          date: DateTime(2026, 8, 10, 23),
          rates: rates,
        ),
        7.2,
      );
      expect(
        rateToBaseAt(
          bookId: 'book',
          baseCurrencyCode: 'CNY',
          currencyCode: 'USD',
          date: DateTime(2026, 8, 19),
          rates: rates,
        ),
        7.2,
      );
      expect(
        rateToBaseAt(
          bookId: 'book',
          baseCurrencyCode: 'CNY',
          currencyCode: 'USD',
          date: DateTime(2026, 7, 31),
          rates: rates,
        ),
        isNull,
      );
      expect(
        rateToBaseAt(
          bookId: 'book',
          baseCurrencyCode: 'CNY',
          currencyCode: 'CNY',
          date: DateTime(1900),
          rates: const <ExchangeRate>[],
        ),
        1,
      );
    });

    test('通过本位币交叉换算并按目标货币规整', () {
      final rates = <ExchangeRate>[
        rate('usd', 'USD', DateTime(2026, 8, 1), 7.2),
        rate('jpy', 'JPY', DateTime(2026, 8, 1), 0.048),
      ];
      final result = convertCurrencyAmount(
        amount: 10,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'JPY',
        baseCurrencyCode: 'CNY',
        bookId: 'book',
        date: DateTime(2026, 8, 10),
        rates: rates,
      );
      expect(result, isA<ConvertedCurrencyAmount>());
      final converted = result as ConvertedCurrencyAmount;
      expect(converted.amount, 1500);
      expect(converted.sourceRateToBase, 7.2);
      expect(converted.targetRateToBase, 0.048);
      expect(converted.sourceRateDate, DateTime(2026, 8, 1));
    });

    test('缺少任一交叉汇率时返回明确币种集合', () {
      final result = convertCurrencyAmount(
        amount: 10,
        sourceCurrencyCode: 'USD',
        targetCurrencyCode: 'JPY',
        baseCurrencyCode: 'CNY',
        bookId: 'book',
        date: DateTime(2026, 8, 10),
        rates: const <ExchangeRate>[],
      );
      expect(result, isA<MissingCurrencyRate>());
      expect((result as MissingCurrencyRate).currencyCodes, <String>{
        'USD',
        'JPY',
      });
    });

    test('陈旧判断按日历日而不是绝对时长', () {
      final source = rate('r', 'USD', DateTime(2026, 3, 1, 23), 7.2);
      expect(isExchangeRateStale(source, DateTime(2026, 3, 31, 1)), isFalse);
      expect(isExchangeRateStale(source, DateTime(2026, 4, 1, 1)), isTrue);
      expect(
        () => isExchangeRateStale(source, DateTime(2026), thresholdDays: -1),
        throwsArgumentError,
      );
    });
  });
}
