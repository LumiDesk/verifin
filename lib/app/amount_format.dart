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
