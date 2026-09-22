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

  static Future<Uint8List?> renderPreview({
    required String template,
    required int widthDp,
    required int heightDp,
    String bookId = '',
    String metric = '',
    bool sample = false,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('renderWidgetPreview', {
        'template': template,
        'widthDp': widthDp,
        'heightDp': heightDp,
        'bookId': bookId,
        'metric': metric,
        'sample': sample,
      });
    } on MissingPluginException {
      return null;
    }
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
