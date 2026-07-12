part of 'platform_bridge.dart';

Future<void> Function()? _quickEntryHandler;
Future<void> Function()? _sharedCaptureHandler;

/// 快速记账磁贴与分享/外部采集（`ShareReceiverActivity` 转发）的消费入口。
class AppCaptureBridge {
  AppCaptureBridge._();

  static void setQuickEntryHandler(Future<void> Function() handler) {
    _quickEntryHandler = handler;
    _ensureInboundDispatcher();
  }

  static void clearQuickEntryHandler() {
    _quickEntryHandler = null;
    _ensureInboundDispatcher();
  }

  /// 注册分享/外部采集到达时的回调（应用已在运行、原生 onNewIntent 通知）。
  static void setSharedCaptureHandler(Future<void> Function() handler) {
    _sharedCaptureHandler = handler;
    _ensureInboundDispatcher();
  }

  static void clearSharedCaptureHandler() {
    _sharedCaptureHandler = null;
    _ensureInboundDispatcher();
  }

  /// 冷启动时取走「来自磁贴的快速记账」意图（无则 false）。取走即清。
  static Future<bool> consumeInitialQuickEntryIntent() async {
    try {
      return await _channel.invokeMethod<bool>('consumeQuickEntryIntent') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 取走待识别的分享图片字节（无则 null）。取走即清，重复调用返回 null。
  static Future<Uint8List?> consumeCaptureImage() async {
    try {
      return await _channel.invokeMethod<Uint8List>('consumeCaptureImage');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 取走待解析的外部采集文本（分享文本 / 自动化意图，无则 null）。取走即清。
  static Future<String?> consumeCaptureText() async {
    try {
      return await _channel.invokeMethod<String>('consumeCaptureText');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
