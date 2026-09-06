part of 'platform_bridge.dart';

/// 桌面小组件：数据推送与一键固定。
class AppWidgetBridge {
  AppWidgetBridge._();

  /// 一次推送三个桌面小组件（今日支出 / 本月预算 / 资产总额）的数据到 Android
  /// （非 Android 平台静默忽略）。金额均由调用方按用户偏好格式化好。
  static Future<void> updateWidgetData({
    required String todayAmount,
    required String todayLabel,
    required String quickEntryLabel,
    required String budgetAmount,
    required String budgetLabel,
    required String netWorthAmount,
    required String netWorthLabel,
    required String todayDate,
    required String todayZeroAmount,
    required String todayStaleAmount,
    required String todayStaleLabel,
    required String budgetExpiry,
    required String budgetFullAmount,
    required String budgetFullLabel,
    required String budgetNextExpiry,
    required String budgetNextAmount,
    required String budgetNextLabel,
    required String budgetStaleLabel,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateWidgetData', {
        'todayAmount': todayAmount,
        'todayLabel': todayLabel,
        'quickEntryLabel': quickEntryLabel,
        'budgetAmount': budgetAmount,
        'budgetLabel': budgetLabel,
        'netWorthAmount': netWorthAmount,
        'netWorthLabel': netWorthLabel,
        // 跨天/跨期自愈用的锚点：原生按当前日期判断推送值是否过期，过期则展示
        // 归零/满额值，不必等应用打开重新推送。budgetExpiry 为预算周期截止日
        // （yyyy-MM-dd，含当天；自定义预算周期起始日后不再是自然月末）。
        'todayDate': todayDate,
        'todayZeroAmount': todayZeroAmount,
        'todayStaleAmount': todayStaleAmount,
        'todayStaleLabel': todayStaleLabel,
        'budgetExpiry': budgetExpiry,
        'budgetFullAmount': budgetFullAmount,
        'budgetFullLabel': budgetFullLabel,
        'budgetNextExpiry': budgetNextExpiry,
        'budgetNextAmount': budgetNextAmount,
        'budgetNextLabel': budgetNextLabel,
        'budgetStaleLabel': budgetStaleLabel,
      });
    } on MissingPluginException {
      // 非 Android 平台没有桌面小组件。
    } on PlatformException {
      // 小组件更新失败不影响主流程，忽略。
    }
  }

  /// 请求把指定小组件固定到桌面（`quick_entry`/`budget`/`net_worth`）。
  /// 返回是否成功发起系统添加弹窗；不支持的启动器/平台返回 false。
  static Future<bool> pinWidget(String widget) async {
    try {
      final ok = await _channel.invokeMethod<bool>('pinWidget', {
        'widget': widget,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
