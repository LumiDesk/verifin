part of 'platform_bridge.dart';

/// 桌面小组件：数据推送与一键固定。
class AppWidgetBridge {
  AppWidgetBridge._();

  static Future<void> Function(Map<String, Object?> args)? _routeHandler;

  static void setRouteHandler(
    Future<void> Function(Map<String, Object?> args) handler,
  ) {
    _routeHandler = handler;
    _ensureInboundDispatcher();
  }

  static void clearRouteHandler() {
    _routeHandler = null;
  }

  static Future<void> handleRoute(Map<String, Object?> args) async {
    await _routeHandler?.call(args);
  }

  /// Cold-start intents wait in Android until the consent/lock gates open.
  static Future<Map<String, Object?>?> consumeInitialRoute() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
        'consumeWidgetRoute',
      );
    } on MissingPluginException {
      // Widget tests and non-Android hosts have no pending Android intent.
      return null;
    }
  }

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
    String trendAmount = '0',
    String trendLabel = '',
    String trendPoints = '',
    String trendRangeLabel = '',
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
        'trendAmount': trendAmount,
        'trendLabel': trendLabel,
        'trendPoints': trendPoints,
        'trendRangeLabel': trendRangeLabel,
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

  /// Save the configuration for one Android appWidgetId. The id is supplied by
  /// the launcher; configurations are intentionally per instance.
  static Future<bool> updateWidgetConfig({
    required int widgetId,
    required String template,
    String? bookId,
    String? primaryMetric,
    String? secondaryMetric,
    String? chartMetric,
    int chartDays = 30,
    String action = 'app',
    bool hideAmounts = false,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('updateWidgetConfig', {
        'widgetId': widgetId,
        'template': template,
        'bookId': bookId,
        'primaryMetric': primaryMetric,
        'secondaryMetric': secondaryMetric,
        'chartMetric': chartMetric,
        'chartDays': chartDays,
        'action': action,
        'hideAmounts': hideAmounts,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> pinUserWidget(String definitionId) async {
    try {
      final ok = await _channel.invokeMethod<bool>('pinUserWidget', {
        'definitionId': definitionId,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Push saved user designs to the native widget process. Android keeps its
  /// own compact copy because a launcher may render a widget while Flutter is
  /// not running.
  static Future<void> syncUserWidgetDefinitions(
    List<Map<String, Object?>> definitions,
  ) async {
    try {
      await _channel.invokeMethod<void>('syncUserWidgetDefinitions', {
        'definitions': definitions,
      });
    } on MissingPluginException {
      // Non-Android hosts have no widget provider.
    } on PlatformException {
      // A stale native snapshot must not block normal ledger use.
    }
  }

  /// Push the current ledger book names for the native per-instance widget
  /// configuration screen. This is a device-local UI snapshot, not app data.
  static Future<void> syncWidgetBooks(List<Map<String, Object?>> books) async {
    try {
      await _channel.invokeMethod<void>('syncWidgetBooks', {'books': books});
    } on MissingPluginException {
      // Non-Android hosts have no native widget configuration screen.
    } on PlatformException {
      // A stale native snapshot is safe; the next app foreground refreshes it.
    }
  }

  static Future<void> syncWidgetSnapshots(
    Map<String, Map<String, Map<String, Object?>>> snapshots,
  ) async {
    try {
      await _channel.invokeMethod<void>('syncWidgetSnapshots', {
        'snapshots': snapshots,
      });
    } on MissingPluginException {
      // Non-Android hosts have no native widget renderer.
    } on PlatformException {
      // The next foreground refresh will replace a stale snapshot.
    }
  }
}
