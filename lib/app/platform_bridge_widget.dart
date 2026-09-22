part of 'platform_bridge.dart';

/// Inbound widget routes are kept in the app bridge. Widget data and scheduling
/// are provided by the maintained home_widget plugin instead of a second custom
/// MethodChannel protocol.
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

  static Future<Map<String, Object?>?> consumeInitialRoute() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
        'consumeWidgetRoute',
      );
    } on MissingPluginException {
      return null;
    }
  }
}
