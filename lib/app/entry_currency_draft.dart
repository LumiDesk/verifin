import 'currency_math.dart';

/// 原币金额变化时按当前草稿的实际结算比例缩放依赖金额。用于手工、导入、旧数据与
/// 固定金额周期规则；汇率表驱动的草稿仍应重新查询对应日期汇率。
double? scaleDependentCurrencyAmount({
  required double? dependentAmount,
  required double previousOriginalAmount,
  required double nextOriginalAmount,
  required String targetCurrencyCode,
}) {
  if (dependentAmount == null ||
      !dependentAmount.isFinite ||
      previousOriginalAmount <= 0 ||
      !nextOriginalAmount.isFinite ||
      nextOriginalAmount <= 0) {
    return dependentAmount;
  }
  return normalizeCurrencyAmount(
    dependentAmount * nextOriginalAmount / previousOriginalAmount,
    targetCurrencyCode,
  );
}
