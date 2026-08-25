import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/entry_currency_draft.dart';

void main() {
  test('原币金额变化按既有结算比例缩放并遵循目标币种精度', () {
    expect(
      scaleDependentCurrencyAmount(
        dependentAmount: 72.35,
        previousOriginalAmount: 10,
        nextOriginalAmount: 20,
        targetCurrencyCode: 'CNY',
      ),
      144.7,
    );
    expect(
      scaleDependentCurrencyAmount(
        dependentAmount: 1.234,
        previousOriginalAmount: 2,
        nextOriginalAmount: 1,
        targetCurrencyCode: 'KWD',
      ),
      0.617,
    );
  });

  test('缺少依赖金额时保持 null，不猜 1:1', () {
    expect(
      scaleDependentCurrencyAmount(
        dependentAmount: null,
        previousOriginalAmount: 10,
        nextOriginalAmount: 20,
        targetCurrencyCode: 'USD',
      ),
      isNull,
    );
  });
}
