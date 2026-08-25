import 'models/currency.dart';

/// 全局金额小数位显示偏好（设备本地，不进 JSON 备份、初始化保留）。
///
/// 金额格式化入口 [formatAmount]（及委托它的 `formatExpense/Income/Signed`）是无
/// BuildContext 的纯函数，且在桌面小组件、本地通知、`series_math` 等拿不到 context
/// 的地方也被调用，无法经组件树（`VeriFinScope`）注入偏好，故此处用顶层可变量承载。
///
/// 由 [VeriFinController] 单向同步：启动时从 KV 载入、用户在设置页切换时写入。除此之外
/// 不应有其他写入方，读取方只读不写。
///
/// [CurrencyFractionStyle.standard] 按货币 minor unit 显示固定小数位；
/// [CurrencyFractionStyle.compact]（默认）去掉多余的尾随零。
CurrencyFractionStyle currencyFractionStyle = CurrencyFractionStyle.compact;

/// 金额货币单位样式。默认使用更紧凑的后置符号，用户可在设置中改为 ISO 代码。
MoneyUnitStyle moneyUnitStyle = MoneyUnitStyle.symbol;

/// 单币种账本是否隐藏每一处金额旁重复出现的货币单位。
bool hideUnitInSingleCurrency = true;

/// 当前活动账本是否实际涉及多个币种，由 [VeriFinController] 随状态同步。
bool activeBookUsesMultipleCurrencies = false;

/// 当前活动账本本位币。无 context 的聚合格式化入口读取它，确保 JPY/KWD 等
/// 非两位币种不会继续按 CNY 精度展示。
String activeBaseCurrencyCode = defaultCurrencyCode;

/// 用户选择的单位样式，不考虑单币种隐藏规则。
MoneyCodeDisplay get preferredMoneyCodeDisplay => switch (moneyUnitStyle) {
  MoneyUnitStyle.symbol => MoneyCodeDisplay.symbol,
  MoneyUnitStyle.code => MoneyCodeDisplay.code,
};

/// 当前活动账本用于普通金额展示的样式。
MoneyCodeDisplay get activeMoneyCodeDisplay =>
    hideUnitInSingleCurrency && !activeBookUsesMultipleCurrencies
    ? MoneyCodeDisplay.none
    : preferredMoneyCodeDisplay;

/// 旧版“两位小数”偏好的兼容入口。
///
/// 迁移完成前保留该 getter/setter，避免旧设置、备份和调用点在同一阶段失效。多币种下
/// 它表达的是“按货币标准小数位显示”，不再承诺固定两位。
bool get amountForceTwoDecimals =>
    currencyFractionStyle == CurrencyFractionStyle.standard;

set amountForceTwoDecimals(bool value) {
  currencyFractionStyle = value
      ? CurrencyFractionStyle.standard
      : CurrencyFractionStyle.compact;
}
